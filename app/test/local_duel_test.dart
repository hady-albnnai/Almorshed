// M5/F5.4 — اختبارات المبارزة المحلية (بلا سيرفر): آلة LocalDuelFlow
// بحكم مضيف حتمي + رابط TCP حقيقي على 127.0.0.1.
// النقلية الذاكرة تحاكي زوج رابطين متصلين، والتحدي الكامل يتحقق من
// الاتفاق التام بين الجهازين على الأسئلة والنتيجة.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';
import 'package:fizya_clash/core/duel/duel_flow.dart';
import 'package:fizya_clash/core/duel/local_duel_flow.dart';
import 'package:fizya_clash/core/duel/local_link.dart';

// ── حزمة 15 سؤالاً عبر 5 فصول ──
ContentPack pack() {
  const chapters = ['U1C1', 'U1C2', 'U2C1', 'U2C2', 'U3C1'];
  final unitOf = <String, String>{
    for (final c in chapters) c: c.substring(0, 2),
  };
  final byChapter = <String, List<Chapter>>{};
  for (final c in chapters) {
    byChapter.putIfAbsent(unitOf[c]!, () => <Chapter>[]).add(Chapter(
          id: c,
          title: 'فصل $c',
          page: chapters.indexOf(c) + 1,
          paragraphs: const [],
        ));
  }
  final units = <Unit>[
    for (final u in byChapter.keys)
      Unit(id: u, title: 'وحدة $u', chapters: byChapter[u]!),
  ];
  final questions = <Question>[
    for (var i = 0; i < 15; i++)
      Question(
        id: i + 1,
        unit: unitOf[chapters[i % 5]]!,
        chapter: chapters[i % 5],
        approved: true,
        stem: 'س${i + 1}',
        options: const ['أ', 'ب', 'ج', 'د'],
        correctIndex: i % 4,
        solutionSteps: const [],
        followThrough: const [],
      ),
  ];
  return ContentPack(
    packId: 'test-pack-1',
    year: 2027,
    edition: 1,
    units: units,
    questions: questions,
    cards: const [],
  );
}

Future<void> pump([int ms = 10]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

// ── نقلية ذاكرة: زوج رابطين متصلين ──
class MemoryLink implements LocalLink {
  MemoryLink({required this.sendTo, required this.recvFrom});

  final StreamController<Map<String, dynamic>> sendTo;
  final StreamController<Map<String, dynamic>> recvFrom;

  @override
  Stream<Map<String, dynamic>> get messages => recvFrom.stream;
  @override
  void send(Map<String, dynamic> m) => sendTo.add(m);
  @override
  Future<void> close() async {}
  @override
  bool get isClosed => false;
}

class MemoryTransport implements LocalDuelTransport {
  // sync:true — تسليم حتمي متزامن (المقابس الحقيقية غير متزامنة لكن الاختبار
  // يريد تحديداً قطعياً دون نوم).
  final a = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final b = StreamController<Map<String, dynamic>>.broadcast(sync: true);

  late final LocalLink hostLink = MemoryLink(sendTo: b, recvFrom: a);
  late final LocalLink guestLink = MemoryLink(sendTo: a, recvFrom: b);

  @override
  Future<LocalLink> awaitGuest({int port = 0}) async => hostLink;

  @override
  Future<LocalLink> joinHost({
    required String hostIp,
    int port = 0,
  }) async =>
      guestLink;

  @override
  Future<void> shutdown() async {}
}

LocalDuelFlow makeFlow({
  required LocalDuelTransport transport,
  required String deviceId,
  required String name,
  required ContentPack p,
  int questionSeconds = DuelConstants.questionSeconds,
}) =>
    LocalDuelFlow(
      transport: transport,
      deviceId: deviceId,
      myName: name,
      buildSession: (seed, scope) =>
          buildDuelSession(p, seed: seed, scope: scope),
      questionSeconds: questionSeconds,
    );

void main() {
  test('مبارزة محلية كاملة: المضيف يجيب صح والضيف خطأ ⇒ مضيف 2300', () async {
    final p = pack();
    final byId = <int, Question>{for (final q in p.questions) q.id: q};
    final t = MemoryTransport();
    final host = makeFlow(transport: t, deviceId: 'dev-host', name: 'المضيف', p: p);
    final guest =
        makeFlow(transport: t, deviceId: 'dev-guest', name: 'الضيف', p: p);

    final code = await host.host(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    expect(code.length, 6, reason: 'رمز محلي ٦ محارف');
    await pump(); // اكتمال استماع المضيف

    await guest.join(hostIp: 'x', port: 0, code: code);
    await pump();
    expect(guest.snapshot.phase, DuelPhase.lobby, reason: 'الضيف في اللوبي');
    expect(host.snapshot.opponentJoined, isTrue, reason: 'المضيف يرى الضيف');
    // نفس الأسئلة على الجهازين (البذرة نفسها)
    expect(guest.snapshot.questionIds, host.snapshot.questionIds,
        reason: 'تطابق الأسئلة');

    await host.start();
    expect(guest.snapshot.phase, DuelPhase.live, reason: 'الضيف انتقل للحي');
    expect(host.snapshot.phase, DuelPhase.live);

    for (var i = 0; i < 10; i++) {
      final qid = host.snapshot.questionIds[i];
      final order = host.snapshot.optionOrders[qid]!;
      final correct = order.indexOf(byId[qid]!.correctIndex);
      final wrong = (correct + 1) % 4;
      await host.submitAnswer(correct);
      await guest.submitAnswer(wrong);
    }
    await pump(50);

    expect(host.snapshot.phase, DuelPhase.finished, reason: 'المضيف أنهى');
    expect(guest.snapshot.phase, DuelPhase.finished, reason: 'الضيف أنهى');
    expect(host.snapshot.iWon, isTrue, reason: 'المضيف فاز');
    expect(guest.snapshot.iWon, isFalse);
    expect(host.snapshot.verdict!.hostScore, 2300,
        reason: 'نقاط المضيف 2×100+3×200+5×300');
    expect(host.snapshot.verdict!.guestScore, 0,
        reason: 'الضيف أخطأ في كل الأسئلة');
    expect(guest.snapshot.verdict!.hostScore, 2300,
        reason: 'الضيف يرى نقاط المضيف نفسها');
    expect(guest.snapshot.verdict!.guestScore, 0,
        reason: 'الضيف يرى نقاطه ٠');
    expect(guest.snapshot.verdict!.winnerDevice, 'dev-host',
        reason: 'الضيف يرى الفائز = المضيف');
    await host.dispose();
    await guest.dispose();
  });

  test('مبارزة محلية: الضيف يجيب صح والمضيف خطأ ⇒ الضيف يفوز', () async {
    final p = pack();
    final byId = <int, Question>{for (final q in p.questions) q.id: q};
    final t = MemoryTransport();
    final host = makeFlow(transport: t, deviceId: 'dev-host', name: 'المضيف', p: p);
    final guest =
        makeFlow(transport: t, deviceId: 'dev-guest', name: 'الضيف', p: p);

    final code = await host.host(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    await pump();
    await guest.join(hostIp: 'x', port: 0, code: code);
    await host.start();

    for (var i = 0; i < 10; i++) {
      final qid = host.snapshot.questionIds[i];
      final order = host.snapshot.optionOrders[qid]!;
      final correct = order.indexOf(byId[qid]!.correctIndex);
      final wrong = (correct + 1) % 4;
      await host.submitAnswer(wrong);
      await guest.submitAnswer(correct);
    }
    await pump(50);

    expect(host.snapshot.phase, DuelPhase.finished);
    expect(guest.snapshot.iWon, isTrue, reason: 'الضيف فاز');
    expect(host.snapshot.iWon, isFalse);
    expect(host.snapshot.verdict!.guestScore, 2300);
    await host.dispose();
    await guest.dispose();
  });

  test('رفض رمز خاطئ: المضيف يودّع الضيف', () async {
    final p = pack();
    final t = MemoryTransport();
    final host = makeFlow(transport: t, deviceId: 'dev-host', name: 'المضيف', p: p);
    final guest =
        makeFlow(transport: t, deviceId: 'dev-guest', name: 'الضيف', p: p);

    await host.host(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    await pump();
    await guest.join(hostIp: 'x', port: 0, code: 'ZZZZZZ');
    await pump(20);

    expect(host.snapshot.opponentJoined, isFalse, reason: 'رمز خاطئ لا يُقبل');
    expect(guest.snapshot.phase, DuelPhase.failed, reason: 'الضيف فشل');
    await host.dispose();
    await guest.dispose();
  });

  test('مهلة سؤال محلي: تقدم تلقائي بلا إجابة', () async {
    final p = pack();
    final t = MemoryTransport();
    final host = makeFlow(
      transport: t,
      deviceId: 'dev-host',
      name: 'المضيف',
      p: p,
      questionSeconds: 0, // تنتهي فوراً
    );
    final guest = makeFlow(
      transport: t,
      deviceId: 'dev-guest',
      name: 'الضيف',
      p: p,
      questionSeconds: 0,
    );

    final code = await host.host(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    await pump();
    await guest.join(hostIp: 'x', port: 0, code: code);
    await host.start();
    await pump(400);

    expect(host.snapshot.currentIndex, greaterThan(0),
        reason: 'تقدمت الأسئلة تلقائياً');
    expect(host.snapshot.myAnswers[0], isNull, reason: 'مهلة بلا إجابة');
    expect(host.snapshot.myStreak, 0, reason: 'السلسلة صفر');
    await host.dispose();
    await guest.dispose();
  });

  test('نقلية TCP: تبادل رسائل JSON على 127.0.0.1', () async {
    final t = TcpDuelTransport();
    final port = 41000 + Random().nextInt(9000);
    final hostFuture = t.awaitGuest(port: port);
    await pump(60); // يُربط المنفذ
    final guestLink = await t.joinHost(hostIp: '127.0.0.1', port: port);
    final hostLink = await hostFuture;

    final received = <Map<String, dynamic>>[];
    guestLink.messages.listen(received.add);
    hostLink.send(<String, dynamic>{'t': 'hello', 'x': 1});
    await pump(60);

    expect(received, hasLength(1), reason: 'وصلت الرسالة للضيف');
    expect(received.single['t'], 'hello');

    await hostLink.close();
    await guestLink.close();
    await t.shutdown();
  });
}
