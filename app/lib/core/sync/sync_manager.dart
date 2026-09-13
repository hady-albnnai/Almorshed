// ═════════════════════════════════════════════════════════════════════
// F4.5 — مُشغّل المزامنة الأمامي: غلاف آمن فوق SyncEngine مع حالات ظاهرة
// (ValueNotifier للرئيسية) وحاجز إعادة الدخول (لا جولتين متوازيتين).
// المشغلات: فتح الرئيسية / عودة التطبيق للمقدمة / العودة من درس أو تدريب.
// ═════════════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';

import 'sync_engine.dart';

/// حالة المزامنة الظاهرة بالرئيسية.
enum SyncPhase { idle, syncing, synced, offline, rejected }

class SyncManager {
  SyncManager({required Future<SyncEngine> Function() engineFactory})
      : _engineFactory = engineFactory;

  final Future<SyncEngine> Function() _engineFactory;
  SyncEngine? _engine;
  bool _busy = false;

  /// يستمع عليه الرئيسية ليرسم المؤشر الصغير.
  final ValueNotifier<SyncPhase> phase = ValueNotifier<SyncPhase>(SyncPhase.idle);

  /// جولة مزامنة — آمنة للاستدعاء المتكرر (الثانية أثناء جولة تُهمل).
  Future<void> runNow() async {
    if (_busy) return;
    _busy = true;
    phase.value = SyncPhase.syncing;
    try {
      _engine ??= await _engineFactory();
      final r = await _engine!.syncIfNeeded();
      phase.value = switch (r.outcome) {
        SyncOutcome.synced => SyncPhase.synced,
        SyncOutcome.rejected => SyncPhase.rejected,
        SyncOutcome.offline => SyncPhase.offline,
        SyncOutcome.idle => SyncPhase.idle,
      };
    } catch (_) {
      // أي أعطال غير متوقعة = دون اتصال بمنظور الواجهة (الرفض المنطقي
      // يأتي SyncResponse لا استثناءً — فيذهب rejected أعلاه)
      phase.value = SyncPhase.offline;
    } finally {
      _busy = false;
    }
  }

  /// للاختبارات: إطلاق الموارد (لا شيء يملكه فعلياً الآن).
  void dispose() => phase.dispose();
}
