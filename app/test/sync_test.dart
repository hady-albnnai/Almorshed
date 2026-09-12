import 'dart:typed_data';

import 'package:fizya_clash/core/sync/sync_engine.dart';
import 'package:fizya_clash/core/sync/sync_store.dart';
import 'package:fizya_clash/core/xp/xp_ledger.dart';
import 'package:fizya_clash/core/xp/xp_store.dart';
import 'package:fizya_clash/core/xp/xp_signer.dart';
import 'package:flutter_test/flutter_test.dart';

/// F4.5 — اختبارات محرك المزامنة: الرفع التدريجي بلا فجوات + الرفض لا
/// يقدّم الحالة + backoff أسي + مرساة زمن السيرفر L4.
void main() {
  // دفتر حتمي ببذرة معلومة — أحداثه مرجع الرفع
  Future<XpLedgerService> seededLedger(int n) async {
    final l = XpLedgerService(
      store: InMemoryXpEventStore(),
      vault: InMemoryXpKeyVault(
          Uint8List.fromList(List<int>.generate(32, (i) => i + 1))),
    );
    for (var i = 0; i < n; i++) {
      await l.append(
          typeId: 'cardReview',
          dateKey: '2026-09-12',
          tsMsOverride: 1790000000000 + i);
    }
    return l;
  }

  const pubkeyB64 = 'ZmFrZXB1YmtleQ=='; // أي نص — الزيف لا يفحصه

  group('الرفع التدريجي', () {
    test('أول مزامنة: كل الأحداث تُرفع ويُعتمد آخرها ومرساة الزمن تُثبَّت',
        () async {
      final l = await seededLedger(3);
      final stateStore = InMemorySyncStateStore();
      SyncRequest? captured;
      final api = FakeApi((r) => SyncResponse(
            accepted: true,
            syncedUpTo: r.events.last.seq,
            serverTimeMs: 1790000099999,
          ), onRequest: (r) => captured = r);
      final engine = SyncEngine(
          api: api,
          stateStore: stateStore,
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64,
          nowMs: () => 1790000000000);

      final r = await engine.syncIfNeeded();
      expect(r.outcome, SyncOutcome.synced);
      expect(r.syncedUpTo, 3);
      expect(captured!.events.map((e) => e.seq).toList(), [1, 2, 3]);
      expect(captured!.lastSyncedSeq, 0);
      final s = await stateStore.load();
      expect(s.lastSyncedSeq, 3);
      expect(s.lastServerWallMs, 1790000099999); // مرساة L4
      expect(s.failCount, 0);
    });

    test('بلا جديد: لا نداء شبكة إطلاقاً', () async {
      final l = await seededLedger(0);
      var calls = 0;
      final engine = SyncEngine(
          api: FakeApi((r) => const SyncResponse(accepted: true),
              onCall: () => calls++),
          stateStore: InMemorySyncStateStore(),
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64);
      final r = await engine.syncIfNeeded();
      expect(r.outcome, SyncOutcome.idle);
      expect(calls, 0);
    });

    test('بعد اعتماد 2: الدفعة التالية تحمل 3 حصراً وlastSyncedSeq=2',
        () async {
      final l = await seededLedger(2);
      final stateStore = InMemorySyncStateStore(
          const SyncState(lastSyncedSeq: 2));
      SyncRequest? captured;
      final api = FakeApi((r) {
        captured = r;
        return SyncResponse(accepted: true, syncedUpTo: 3, serverTimeMs: 1);
      }, onRequest: (r) => captured = r);
      await l.append(typeId: 'cardReview', dateKey: '2026-09-12');
      final engine = SyncEngine(
          api: api,
          stateStore: stateStore,
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64);
      await engine.syncIfNeeded();
      expect(captured!.events.map((e) => e.seq).toList(), [3]);
      expect(captured!.lastSyncedSeq, 2);
    });
  });

  group('الرفض والانقطاع — لا تقدّم بلا اعتماد', () {
    test('رفض منطقي: الحالة لا تتقدم والسبب يظهر وbackoff يُسلَّح', () async {
      final l = await seededLedger(3);
      final stateStore = InMemorySyncStateStore();
      const t0 = 1790000000000;
      final engine = SyncEngine(
          api: FakeApi((r) => const SyncResponse(
              accepted: false, reason: 'فجوة تسلسل', syncedUpTo: 1)),
          stateStore: stateStore,
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64,
          nowMs: () => t0);
      final r = await engine.syncIfNeeded();
      expect(r.outcome, SyncOutcome.rejected);
      expect(r.reason, contains('فجوة'));
      final s = await stateStore.load();
      expect(s.lastSyncedSeq, 0); // لم نتقدم
      expect(s.failCount, 1);
      expect(s.nextRetryMs, t0 + 60000); // دقيقة
      // داخل نافذة backoff: idle بلا شبكة
      final engine2 = SyncEngine(
          api: FakeApi((r) => const SyncResponse(accepted: true),
              onCall: () => throw 'لا نداء داخل backoff!'),
          stateStore: stateStore,
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64,
          nowMs: () => t0 + 30000);
      expect((await engine2.syncIfNeeded()).outcome, SyncOutcome.idle);
    });

    test('انقطاع شبكة: backoff أسي 1→2→4 دقائق بسقف ساعة', () async {
      final l = await seededLedger(1);
      final stateStore = InMemorySyncStateStore();
      var now = 1790000000000;
      final engine = SyncEngine(
          api: FakeApi((r) => throw Exception('شبكة ميتة')),
          stateStore: stateStore,
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64,
          nowMs: () => now);
      await engine.syncIfNeeded();
      var s = await stateStore.load();
      expect(s.nextRetryMs - now, 60000); // 1 دقيقة
      now = s.nextRetryMs; // انقضت النافذة
      await engine.syncIfNeeded();
      s = await stateStore.load();
      expect(s.nextRetryMs - now, 120000); // 2 دقيقة
      now = s.nextRetryMs;
      await engine.syncIfNeeded();
      s = await stateStore.load();
      expect(s.nextRetryMs - now, 240000); // 4 دقائق
      // السقف: بعد 7 إخفاقات لا يتجاوز 60 دقيقة
      for (var i = 0; i < 10; i++) {
        now = s.nextRetryMs;
        await engine.syncIfNeeded();
        s = await stateStore.load();
      }
      expect(s.nextRetryMs - now, 3600000);
    });

    test('النجاح بعد إخفاقات يصفر العداد ويعتمد', () async {
      final l = await seededLedger(2);
      final stateStore = InMemorySyncStateStore(
          const SyncState(failCount: 3, nextRetryMs: 1000));
      var fail = true;
      final engine = SyncEngine(
          api: FakeApi((r) => fail
              ? throw Exception('لا')
              : SyncResponse(accepted: true, syncedUpTo: 2, serverTimeMs: 5)),
          stateStore: stateStore,
          loadEvents: l.events,
          devicePubkeyB64: pubkeyB64,
          nowMs: () => 2000);
      await engine.syncIfNeeded(); // انقطاع (يليّ backoff)
      fail = false;
      // نتقدم الزمن خارج النافذة ثم ننجح
      final r = await SyncEngine(
        api: FakeApi((r) => SyncResponse(accepted: true, syncedUpTo: 2,
            serverTimeMs: 5000)),
        stateStore: stateStore,
        loadEvents: l.events,
        devicePubkeyB64: pubkeyB64,
        nowMs: () => 999999999,
      ).syncIfNeeded();
      expect(r.outcome, SyncOutcome.synced);
      final s = await stateStore.load();
      expect(s.failCount, 0);
      expect(s.nextRetryMs, 0);
      expect(s.lastServerWallMs, 5000);
    });
  });
}

/// API زيف — يفحص النداءات ويسمح برمي استثناء (انقطاع).
class FakeApi implements XpSyncApi {
  FakeApi(this.handler, {this.onCall, this.onRequest});

  final SyncResponse Function(SyncRequest r) handler;
  final void Function()? onCall;
  final void Function(SyncRequest r)? onRequest;

  @override
  Future<SyncResponse> verify(SyncRequest request) async {
    onCall?.call();
    onRequest?.call(request);
    return handler(request);
  }
}
