/// F4.5 — محرك المزامنة (الجانب العميل): يرفع أحداث الدفتر غير المزامنة
/// إلى `verify_xp_events` ويعتمد «آخر seq مقبول». المشغّل الأساسي **أمامي**
/// (فتح التطبيق/عودة الاتصال — docs/14 §١٥-أ: OEMs تقتل الخلفية)، والانتظار
/// أسي عند الفشل. النقاط لا تُعتمد محلياً من الرفع — الدفتر هو المصدر
/// والسيرفر هو مرجع الدوري (docs/12 §٤.۳).
library;

import '../../core/xp/xp_event.dart';
import 'sync_store.dart';

/// طلب الرفع كما يستقبله `verify_xp_events` (الحقلان العامة خارج الحدث).
class SyncRequest {
  const SyncRequest({
    required this.devicePubkeyB64,
    required this.lastSyncedSeq,
    required this.events,
  });

  final String devicePubkeyB64; // مفتاح الجهاز العام (base64)
  final int lastSyncedSeq; // آخر مقبول سابقاً — السيرفر يتحقق من الاستمرارية
  final List<XpEvent> events; // seq > lastSyncedSeq بالترتيب
}

/// رد السيرفر.
class SyncResponse {
  const SyncResponse({
    required this.accepted,
    this.syncedUpTo = 0,
    this.serverTimeMs = 0,
    this.reason = '',
  });

  final bool accepted;
  final int syncedUpTo; // آخر seq أودعه السيرفر
  final int serverTimeMs; // زمن السيرفر — مرساة L4
  final String reason; // عند الرفض (تشخيصاً)
}

/// واجهة النقل — التنفيذ الحقيقي (HTTP إلى Edge Function) مع F4.4/F4.5
/// بعد إنشاء المشروع؛ الاختبارات بالزيف.
abstract class XpSyncApi {
  Future<SyncResponse> verify(SyncRequest request);
}

/// نتيجة جولة مزامنة.
enum SyncOutcome { idle, synced, rejected, offline }

class SyncResult {
  const SyncResult(this.outcome, {this.syncedUpTo = -1, this.reason = ''});
  final SyncOutcome outcome;
  final int syncedUpTo;
  final String reason;
}

/// محرك المزامنة — بلا أي حالة خاصة: الحالة في SyncStateStore والأحداث
/// في دفتر XP (يقرأها عبر المُغذّية) — كله قابل للحقن والاختبار الحتمي.
class SyncEngine {
  SyncEngine({
    required this.api,
    required this.stateStore,
    required this.loadEvents,
    required this.devicePubkeyB64,
    int Function()? nowMs,
    Duration baseBackoff = const Duration(minutes: 1),
    int maxBackoffMinutes = 60,
  })  : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _baseBackoff = baseBackoff,
        _maxBackoffMinutes = maxBackoffMinutes;

  final XpSyncApi api;
  final SyncStateStore stateStore;

  /// مُغذّية الأحداث — من خدمة الدفتر (بعد تحميلها).
  final Future<List<XpEvent>> Function() loadEvents;
  final String devicePubkeyB64;

  final int Function() _nowMs;
  final Duration _baseBackoff;
  final int _maxBackoffMinutes;

  /// هل توجد محاولة مسموحة الآن؟ (respect للـbackoff).
  Future<bool> canSyncNow() async {
    final s = await stateStore.load();
    return _nowMs() >= s.nextRetryMs;
  }

  /// جولة مزامنة كاملة — تُستدعى من المشغلات الأمامية
  /// (فتح التطبيق/عودة الاتصال/بعد كل حدث XP لاحقاً).
  Future<SyncResult> syncIfNeeded() async {
    if (!await canSyncNow()) {
      return const SyncResult(SyncOutcome.idle, reason: 'backoff');
    }
    final state = await stateStore.load();
    final all = await loadEvents();
    final pending =
        all.where((e) => e.seq > state.lastSyncedSeq).toList(growable: false);
    if (pending.isEmpty) {
      return const SyncResult(SyncOutcome.idle, reason: 'لا جديد');
    }

    final SyncResponse resp;
    try {
      resp = await api.verify(SyncRequest(
        devicePubkeyB64: devicePubkeyB64,
        lastSyncedSeq: state.lastSyncedSeq,
        events: pending,
      ));
    } catch (_) {
      // دون اتصال/خطأ شبكة — انتظار أسي قبل المحاولة التالية
      final now = _nowMs();
      final minutes = _backoffMinutes(state.failCount + 1);
      await stateStore.save(state.copyWith(
        failCount: state.failCount + 1,
        nextRetryMs: now + minutes * 60000,
      ));
      return SyncResult(SyncOutcome.offline, reason: 'backoff $minutes د');
    }

    if (!resp.accepted) {
      // رفض منطقي من السيرفر (فجوة/توقيع/هاش) — لا نتقدم ولا نمسح شيئاً:
      // السلسلة محلية سليمة والسبب يُعرض للمستخدم/الطقم التشخيصي
      final now = _nowMs();
      await stateStore.save(state.copyWith(
        failCount: state.failCount + 1,
        nextRetryMs: now + _backoffMinutes(state.failCount + 1) * 60000,
      ));
      return SyncResult(SyncOutcome.rejected,
          syncedUpTo: resp.syncedUpTo, reason: resp.reason);
    }

    // قبول: نعتمد آخر seq ونسجل مرساة الزمن ونصفّر الإخفاقات
    await stateStore.save(state.copyWith(
      lastSyncedSeq: resp.syncedUpTo,
      lastServerWallMs: resp.serverTimeMs,
      failCount: 0,
      nextRetryMs: 0,
    ));
    return SyncResult(SyncOutcome.synced, syncedUpTo: resp.syncedUpTo);
  }

  /// انتظار أسي: ١، ٢، ٤... دقيقة بسقف ساعة (نفس روح backoff التفعيل).
  int _backoffMinutes(int failCount) {
    final minutes = _baseBackoff.inMinutes * (1 << (failCount - 1));
    return minutes > _maxBackoffMinutes ? _maxBackoffMinutes : minutes;
  }
}
