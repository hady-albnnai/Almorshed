/// F3.7 — دفتر XP: جدول الأنواع (docs/12 §٤.١ + قرار ٦٠) + السلسلة + التحقق.
/// Append-only بالبنية: لا توجد أي واجهة تعديل أو حذف أصلاً — والتحقق
/// يرفض ١٠٠٪ (تعديل payload، حذف حدث، توقيع مزيف — docs/12 §٨-4).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../core/xp/xp_event.dart';
import '../../core/xp/xp_signer.dart';
import 'xp_store.dart';

/// تعريف نوع حدث XP — النقاط من الجدول المرجعي حصراً.
///
/// **قرار ٦٠ (اقتصاد النقاط):** التدريب = نقاط تعلّم شخصية (بلا سقف،
/// بلا جوائز، لا تُحسب في الترتيب). التحديات وحدها = نقاط تنافسية
/// (`arena: true`) وهي ما تُحسب في لوحة الأسبوع.
/// قراءة الدرس = ٠ نقطة (علامة ✓ فقط) ولا تشعل السلسلة — «لا نقاط بلا
/// إجابة صحيحة».
class XpEventType {
  const XpEventType(
    this.id,
    this.points, {
    this.cappedPerDay = false,
    this.awardsStreak = true,
    this.requiresPoints = false,
    this.arena = false,
  });

  final String id;
  final int points;

  /// «مرة/يوم» — السلسلة اليومية وحدها بحكم تعريفها (لا تتكرر).
  final bool cappedPerDay;

  /// هل يشعل «سلسلة اليوم»؟ (قراءة الدرس لا تشعلها — ليست إجابة صحيحة).
  final bool awardsStreak;

  /// النقاط تُحسب وقت الحدث وتمر معه (تحدٍّ مؤقّت / نقاط يدوية) —
  /// بلا قيمة ⇒ رفض (يمنع تزوير النقاط من نوع ثابت).
  final bool requiresPoints;

  /// نقاط تنافسية — تُحسب في لوحة الأسبوع (قرار ٦٠: التحديات هي الفاصل).
  final bool arena;
}

// ── نقاط التعلّم — شخصية، بلا سقف، بلا جوائز (الغش فيها يضر صاحبها فقط) ──
const XpEventType xpBatchDone =
    XpEventType('batchDone', 15); // إتمام دفعة التدريب
const XpEventType xpMistakesFive =
    XpEventType('mistakesFive', 10); // ٥ أسئلة من أخطائي
/// درس مقروء في المنهاج — **٠ نقطة** (علامة ✓ فقط) ولا يشعل السلسلة
/// («لا نقاط بلا إجابة صحيحة» — قرار ٦٠). الحدث يبقى لأجل التقدّم والسلسلة
/// البصرية، لا لأجل النقاط.
const XpEventType xpLessonNew = XpEventType('lessonNew', 0,
    awardsStreak: false, arena: false);
const XpEventType xpStreakDay = XpEventType('streakDay', 10,
    cappedPerDay: true); // سلسلة اليوم — مرة/يوم بحكم تعريفها
const XpEventType xpCardReview =
    XpEventType('cardReview', 1); // بطاقة مراجعة
const XpEventType xpQueueDone =
    XpEventType('queueDone', 15); // إتمام طابور اليوم
const XpEventType xpLabChallenge =
    XpEventType('labChallenge', 10); // تحدي المختبر T=٢ث
const XpEventType xpManual = XpEventType('manual', 0,
    requiresPoints: true); // نقاط يدوية من الأستاذ — النقاط مع سبب

// ── النقاط التنافسية — التحديات وحدها (قرار ٦٠) ──
/// إجابة صحيحة داخل تحدي اليوم — النقاط تناقصية مع الزمن
/// (الدالة الحتمية في `core/xp/challenge_points.dart` — نفسها على السيرفر).
const XpEventType xpChallengeQ = XpEventType('challengeQ', 0,
    requiresPoints: true, arena: true);
/// إنهاء التحدي بمغادرة التطبيق — ٠ نقطة ويُقفل التحدي (لا نقاط بعده).
const XpEventType xpChallengeAbandon = XpEventType('challengeAbandon', 0,
    awardsStreak: false, arena: true);
const XpEventType xpDuelWin =
    XpEventType('duelWin', 45, arena: true); // الفوز وحده يُكافأ
const XpEventType xpDuelLoss =
    XpEventType('duelLoss', 0, arena: true); // الخسارة = صفر (قرار ٦٠)

final Map<String, XpEventType> xpEventTypes = <String, XpEventType>{
  for (final t in const [
    xpBatchDone,
    xpMistakesFive,
    xpLessonNew,
    xpStreakDay,
    xpCardReview,
    xpQueueDone,
    xpLabChallenge,
    xpManual,
    xpChallengeQ,
    xpChallengeAbandon,
    xpDuelWin,
    xpDuelLoss,
  ])
    t.id: t,
};

/// نتيجة التحقق الكامل للسلسلة.
class XpVerifyResult {
  const XpVerifyResult(this.ok, [this.reason = '']);
  final bool ok;
  final String reason; // سبب الرفض عند الفشل (تشخيصاً)
}

/// نتيجة الإلحاق.
class XpAppendResult {
  const XpAppendResult(this.ok, [this.reason = '', this.event]);
  final bool ok;
  final String reason;
  final XpEvent? event;
}

/// دفتر XP المحلي — Append-only موقّع بالجهاز.
class XpLedgerService {
  XpLedgerService({required XpEventStore store, required XpKeyVault vault})
      : _store = store,
        _vault = vault;

  final XpEventStore _store;
  final XpKeyVault _vault;

  XpSigner? _signer;
  List<XpEvent>? _events;

  Future<XpSigner> _ensureSigner() async =>
      _signer ??= await XpSigner.load(_vault);

  Future<List<XpEvent>> _ensureEvents() async =>
      _events ??= await _store.loadEvents();

  /// المفتاح العام للجهاز base64 — يُرسل مع التفعيل والمزامنة (F4.4:
  /// «الكود يرتبط بمفتاح الجهاز» docs/11 §٦ — نفس مفتاح توقيع XP حصراً).
  Future<String> publicKeyB64() async =>
      base64Encode((await _ensureSigner()).publicKey.bytes);

  /// الأحداث المحملة (بعد أول عملية) — للعرض والفحص.
  Future<List<XpEvent>> events() => _ensureEvents();

  /// هل أنجز هذا النوع اليوم المطلوب؟ (مهام اليوم — سقف مرة/يوم).
  Future<bool> dayDone(String typeId, String dateKey) async {
    final events = await _ensureEvents();
    return events.any((e) => e.type == typeId && e.payload['dateKey'] == dateKey);
  }

  /// مجموع نقاط اليوم المطلوب.
  Future<int> dayPoints(String dateKey) async {
    final events = await _ensureEvents();
    var sum = 0;
    for (final e in events) {
      if (e.payload['dateKey'] == dateKey) {
        sum += (e.payload['points'] as num?)?.toInt() ?? 0;
      }
    }
    return sum;
  }

  /// هل بدأ هذا التحدي من قبل؟ (منع تكرار تحدي اليوم محلياً قبل السيرفر —
  /// المعرّف حتمي من الجهاز + مفتاح اليوم، فالتكرار يُكتشف محلياً فوراً).
  Future<bool> challengeStarted(String challengeId) async {
    final events = await _ensureEvents();
    return events.any((e) =>
        (e.type == xpChallengeQ.id || e.type == xpChallengeAbandon.id) &&
        e.payload['challengeId'] == challengeId);
  }

  /// نقاط التحديات فقط (قرار ٦٠) — ما يُحسب في لوحة الأسبوع:
  /// `challengeQ` (+ التناقصي) و`duelWin`. الباقي نقاط تعلّم شخصية.
  Future<int> arenaTotalXp() async {
    final events = await _ensureEvents();
    var sum = 0;
    for (final e in events) {
      final t = xpEventTypes[e.type];
      if (t == null || !t.arena) continue;
      sum += (e.payload['points'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  /// إجمالي XP المعتمد (مجموع حمولات السلسلة).
  Future<int> totalXp() async {
    final events = await _ensureEvents();
    var sum = 0;
    for (final e in events) {
      sum += (e.payload['points'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  /// إلحاق حدث جديد — يفشل بأمان إن كسر سقف اليوم أو النوع مجهول.
  Future<XpAppendResult> append({
    required String typeId,
    required String dateKey,
    Map<String, dynamic>? extra,
    int? pointsOverride, // لنوع manual حصراً (والتوسعات الموقعة لاحقاً)
    int? tsMsOverride, // حتمية الاختبارات
  }) async {
    final type = xpEventTypes[typeId];
    if (type == null) {
      return XpAppendResult(false, 'نوع مجهول: $typeId');
    }
    if (type.requiresPoints && pointsOverride == null) {
      return XpAppendResult(
          false, 'النوع $typeId يتطلب نقاطاً محسوبة مع الحدث (pointsOverride)');
    }
    if (type.cappedPerDay && await dayDone(typeId, dateKey)) {
      return XpAppendResult(false, 'النوع $typeId أنجز اليوم $dateKey مسبقاً');
    }
    final signer = await _ensureSigner();
    final events = await _ensureEvents();
    final prev = events.isEmpty ? null : events.last;
    final points = pointsOverride ?? type.points;
    final payload = <String, dynamic>{
      'points': points,
      'dateKey': dateKey,
      if (extra != null) ...extra,
    };
    final event = XpEvent(
      seq: events.length + 1,
      type: typeId,
      tsMs: tsMsOverride ?? DateTime.now().millisecondsSinceEpoch,
      payload: payload,
      prevHash: prev?.hash ?? genesisPrevHash,
      hash: '', // يُحسب فوراً
      sigB64: '',
    );
    final hash = event.expectedHash();
    final signed = XpEvent(
      seq: event.seq,
      type: event.type,
      tsMs: event.tsMs,
      payload: event.payload,
      prevHash: event.prevHash,
      hash: hash,
      sigB64: signer.signHash(
          Uint8List.fromList(_hashBytes(hash))),
    );
    events.add(signed);
    await _store.saveEvents(events);
    return XpAppendResult(true, '', signed);
  }

  /// التحقق الكامل: تسلسل بلا فجوات + روابط السلسلة + إعادة حساب الهاش
  /// + توقيع كل حدث بمفتاح الجهاز (docs/12 §٤.۲).
  Future<XpVerifyResult> verifyAll() async {
    final signer = await _ensureSigner();
    final events = await _ensureEvents();
    var prevHash = genesisPrevHash;
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      if (e.seq != i + 1) {
        return XpVerifyResult(false,
            'فجوة تسلسل عند ${i + 1} (seq=${e.seq}) — حذف حدث؟');
      }
      if (e.prevHash != prevHash) {
        return XpVerifyResult(false, 'انكسار سلسلة عند ${e.seq}');
      }
      if (e.expectedHash() != e.hash) {
        return XpVerifyResult(false,
            'الهاش لا يطابق عند ${e.seq} — تعديل حمولة؟');
      }
      if (!signer.verifyHash(Uint8List.fromList(_hashBytes(e.hash)), e.sigB64)) {
        return XpVerifyResult(false, 'توقيع مزيف عند ${e.seq}');
      }
      prevHash = e.hash;
    }
    return const XpVerifyResult(true);
  }

  /// النقاط لا تُعتمد من سلسلة مكسورة — «نقاط بلا سلسلة موقعة = مرفوضة».
  Future<int> verifiedTotalXp() async {
    final v = await verifyAll();
    return v.ok ? totalXp() : 0;
  }
}

/// hex → بايتات (التوقيع على بايتات الهاش حصراً).
Uint8List _hashBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
