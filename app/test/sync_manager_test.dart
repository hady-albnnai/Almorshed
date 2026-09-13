// F4.5 — مُشغّل المزامنة: الحالات الظاهرة + حاجز إعادة الدخول (حتمي كامل).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/sync/sync_engine.dart';
import 'package:fizya_clash/core/sync/sync_manager.dart';
import 'package:fizya_clash/core/sync/sync_store.dart';
import 'package:fizya_clash/core/xp/xp_event.dart';

class _FakeApi implements XpSyncApi {
  _FakeApi(this.onCall);
  final Future<SyncResponse> Function(SyncRequest r) onCall;
  int calls = 0;

  @override
  Future<SyncResponse> verify(SyncRequest request) async {
    calls++;
    return onCall(request);
  }
}

XpEvent _ev(int seq) => XpEvent(
      seq: seq,
      type: 'batchDone',
      tsMs: 1790000000000 + seq,
      payload: <String, dynamic>{'points': 15, 'dateKey': '2026-09-13'},
      prevHash: 'GENESIS',
      hash: 'ab' * 32,
      sigB64: 'QUFBQQ==',
    );

SyncManager _manager(_FakeApi api,
    {SyncStateStore? store, List<XpEvent>? events}) {
  return SyncManager(engineFactory: () async => SyncEngine(
        api: api,
        stateStore: store ?? InMemorySyncStateStore(),
        loadEvents: () async => events ?? <XpEvent>[_ev(1), _ev(2)],
        devicePubkeyB64: 'QUJD',
      ));
}

void main() {
  test('الحالات: idle → syncing → synced مع أحداث معلّقة', () async {
    final api = _FakeApi((r) => const SyncResponse(
        accepted: true, syncedUpTo: 2, serverTimeMs: 5));
    final store = InMemorySyncStateStore();
    final m = _manager(api, store: store);
    expect(m.phase.value, SyncPhase.idle);
    await m.runNow();
    expect(m.phase.value, SyncPhase.synced);
    expect((await store.load()).lastSyncedSeq, 2);
  });

  test('إعادة الدخول: جولة أثناء جولة تُهمل — طلب شبكة واحد حصراً', () async {
    final gate = Completer<void>();
    final api = _FakeApi((r) async {
      await gate.future;
      return const SyncResponse(accepted: true, syncedUpTo: 2);
    });
    final m = _manager(api);
    final first = m.runNow();
    await Future<void>.delayed(Duration.zero);
    final second = m.runNow(); // يجب أن تُهمل فوراً
    await second;
    gate.complete();
    await first;
    expect(api.calls, 1);
    expect(m.phase.value, SyncPhase.synced);
  });

  test('انقطاع الشبكة ⇒ offline (ولا يقدّم الحالة)', () async {
    final api = _FakeApi((r) => throw Exception('socket'));
    final store = InMemorySyncStateStore();
    final m = _manager(api, store: store);
    await m.runNow();
    expect(m.phase.value, SyncPhase.offline);
    expect((await store.load()).lastSyncedSeq, 0);
  });

  test('رفض منطقي ⇒ rejected (لا انقطاع)', () async {
    final api = _FakeApi((r) =>
        const SyncResponse(accepted: false, reason: 'SEQ_GAP', syncedUpTo: 0));
    final m = _manager(api);
    await m.runNow();
    expect(m.phase.value, SyncPhase.rejected);
  });
}
