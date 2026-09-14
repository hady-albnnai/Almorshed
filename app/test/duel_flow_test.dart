// M5/F5.3 — اختبارات آلة حالات المبارزة (DuelFlow) — نواة خالصة بلا واجهات.
// سيرفر وهمي يحكم حكمياً كالخادم الحقيقي (إعادة توليد الجلسة من البذرة
// وتصحيح المخزّن) + قناة وهمية للبث — يتحقق: إنشاء، انضمام، بدء، جولة
// كاملة بحكم خادمي، ومهلة السؤال. الحكم خادمي حصراً (docs/16 §٦).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';
import 'package:fizya_clash/core/duel/duel_flow.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';

void check(bool cond, String name, [String? detail]) {
  expect(cond, isTrue, reason: detail != null ? '$name → $detail' : name);
}

// ── حزمة 15 سؤالاً عبر 5 فصول (كاختبار المحرك) ──
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

// ── سيرفر وهمي مشترك (يحكم حكمياً كما الخادم الحقيقي) ──
class FakeServer implements DuelGateway {
  FakeServer(this.p);

  final ContentPack p;
  DuelRow? duel;
  bool started = false;
  final doneSet = <String>{};
  final inserted = <String, Map<int, int>>{}; // device → qIndex → chosen
  int finishCalls = 0;

  DuelRow _row() => duel!;

  @override
  Future<DuelRow> createDuel({
    required String accessToken,
    required String roomCode,
    required int seed,
    required Map<String, dynamic> scopeJson,
    required String hostDevice,
    required String hostName,
  }) async {
    duel = DuelRow(
      id: 'duel-0000-0000-0000-000000000001',
      roomCode: roomCode,
      seed: seed,
      status: 'lobby',
      scopeJson: scopeJson,
      hostDevice: hostDevice,
      hostName: hostName,
    );
    return _row();
  }

  @override
  Future<DuelRow?> findLobbyDuel({
    required String accessToken,
    required String roomCode,
  }) async {
    final d = duel;
    if (d == null || d.roomCode != roomCode || d.status != 'lobby') {
      return null;
    }
    return d;
  }

  @override
  Future<DuelRow> joinAsGuest({
    required String accessToken,
    required String duelId,
    required String guestDevice,
    required String guestName,
  }) async {
    final d = duel!;
    duel = DuelRow(
      id: d.id,
      roomCode: d.roomCode,
      seed: d.seed,
      status: d.status,
      scopeJson: d.scopeJson,
      hostDevice: d.hostDevice,
      guestDevice: guestDevice,
      hostName: d.hostName,
      guestName: guestName,
    );
    return _row();
  }

  @override
  Future<void> startDuel({
    required String accessToken,
    required String duelId,
  }) async {
    started = true;
    final d = duel!;
    duel = DuelRow(
      id: d.id,
      roomCode: d.roomCode,
      seed: d.seed,
      status: 'live',
      scopeJson: d.scopeJson,
      hostDevice: d.hostDevice,
      guestDevice: d.guestDevice,
      hostName: d.hostName,
      guestName: d.guestName,
    );
  }

  @override
  Future<DuelRow> fetchDuel({
    required String accessToken,
    required String duelId,
  }) async =>
      _row();

  @override
  Future<void> insertAnswer({
    required String accessToken,
    required String duelId,
    required String deviceId,
    required int qIndex,
    required int chosen,
  }) async {
    inserted.putIfAbsent(deviceId, () => <int, int>{})[qIndex] = chosen;
  }

  @override
  Future<void> markDone({
    required String accessToken,
    required String duelId,
    required String deviceId,
  }) async {
    doneSet.add(deviceId);
  }

  @override
  Future<DuelVerdict> finish({
    required String accessToken,
    required String duelId,
    required String myDevice,
  }) async {
    finishCalls++;
    final d = duel!;
    final host = d.hostDevice!;
    final guest = d.guestDevice!;
    if (!doneSet.contains(host) || !doneSet.contains(guest)) {
      throw const TransportException(409, 'WAITING_OPPONENT');
    }
    // حكم خادمي حقيقي: إعادة توليد الجلسة وتصحيح المخزّن
    final scope = DuelScope.fromJson(d.scopeJson);
    final session = buildDuelSession(p, seed: d.seed, scope: scope);
    DuelSideResult grade(String dev) {
      final answers = inserted[dev] ?? <int, int>{};
      final chosenByIndex =
          List<int?>.generate(session.length, (i) => answers[i]);
      return gradeDuelSide(session, chosenByIndex);
    }

    final hostG = grade(host);
    final guestG = grade(guest);
    final hostWon = hostWins(host: hostG, guest: guestG, seed: d.seed);
    return DuelVerdict(
      hostScore: hostG.score,
      guestScore: guestG.score,
      winnerDevice: hostWon ? host : guest,
      already: false,
      myDevice: myDevice,
      corrects: session.correctDisplay,
    );
  }
}

// ── قناة وهمية ──
class FakeChannel implements DuelChannelLike {
  final _b = StreamController<Map<String, dynamic>>.broadcast();
  final _pj = StreamController<Map<String, dynamic>>.broadcast();
  final _pl = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];

  @override
  String get topic => 'duel:x';
  @override
  Stream<Map<String, dynamic>> get broadcasts => _b.stream;
  @override
  Stream<Map<String, dynamic>> get presenceJoins => _pj.stream;
  @override
  Stream<Map<String, dynamic>> get presenceLeaves => _pl.stream;
  @override
  Future<bool> join() async => true;
  @override
  bool sendBroadcast(String event, Map<String, dynamic> payload) {
    sent.add(<String, dynamic>{'event': event, 'payload': payload});
    return true;
  }

  void inject(Map<String, dynamic> msg) => _b.add(msg);
  void injectPresence(Map<String, dynamic> p) => _pj.add(p);
}

class FakeWire implements DuelWireLike {
  FakeWire(this.ch);

  final FakeChannel ch;
  @override
  Future<void> connect({required String accessToken}) async {}
  @override
  Future<void> close() async {}
  @override
  DuelChannelLike channel(String topic, {String? presenceKey}) => ch;
}

void main() {
  test('إنشاء (مضيف): رمز، لوبي، دور، بذرة، حضور، بدء', () async {
    final server = FakeServer(pack());
    final ch = FakeChannel();
    final wire = FakeWire(ch);
    final flow = DuelFlow(
      gateway: server,
      wireFactory: () => wire,
      deviceId: 'dev-host',
      accessToken: 'tok',
      buildSession: (seed, scope) =>
          buildDuelSession(pack(), seed: seed, scope: scope),
    );
    final code = await flow.create(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    check(code.length == 11 && code[5] == '-', 'رمز الغرفة Crockford-10', code);
    check(flow.snapshot.phase == DuelPhase.lobby, 'الطور = لوبي');
    check(flow.snapshot.role == DuelRole.host, 'الدور = مضيف');
    check(flow.snapshot.questionCount == 10, '١٠ أسئلة',
        '${flow.snapshot.questionCount}');
    check(server.duel != null, 'المبارزة في السيرفر');
    check(server.duel!.roomCode == code, 'رمز السيرفر = رمز العميل');

    ch.injectPresence(<String, dynamic>{'dev-guest': <String, dynamic>{}});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    check(flow.snapshot.opponentJoined, 'الخصم انضم (presence)');

    await flow.start();
    check(flow.snapshot.phase == DuelPhase.live, 'الطور = حي بعد البدء');
    check(server.started, 'السيرفر بدأ');
    await flow.dispose();
  });

  test('انضمام (ضيف) + بدء المضيف يبث الانتقال للحي', () async {
    final server = FakeServer(pack());
    final hostCh = FakeChannel();
    final guestCh = FakeChannel();
    final host = DuelFlow(
      gateway: server,
      wireFactory: () => FakeWire(hostCh),
      deviceId: 'dev-host',
      accessToken: 'tok',
      buildSession: (seed, scope) =>
          buildDuelSession(pack(), seed: seed, scope: scope),
    );
    final guest = DuelFlow(
      gateway: server,
      wireFactory: () => FakeWire(guestCh),
      deviceId: 'dev-guest',
      accessToken: 'tok',
      buildSession: (seed, scope) =>
          buildDuelSession(pack(), seed: seed, scope: scope),
    );
    final code = await host.create(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    await guest.joinByCode(code);
    check(guest.snapshot.phase == DuelPhase.lobby, 'الضيف في اللوبي');
    check(guest.snapshot.role == DuelRole.guest, 'الضيف دوره ضيف');

    hostCh.injectPresence(<String, dynamic>{'dev-guest': <String, dynamic>{}});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    check(host.snapshot.opponentJoined, 'المضيف يرى الضيف');

    await host.start();
    for (final m in hostCh.sent) {
      guestCh.inject(m);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    check(guest.snapshot.phase == DuelPhase.live, 'الضيف انتقل لحي');
    await host.dispose();
    await guest.dispose();
  });

  test('جولة كاملة: حكم خادمي + XP حسم (duelWin/duelLoss)', () async {
    final server = FakeServer(pack());
    final hostCh = FakeChannel();
    final guestCh = FakeChannel();
    final xpHost = <String>[];
    final xpGuest = <String>[];
    final host = DuelFlow(
      gateway: server,
      wireFactory: () => FakeWire(hostCh),
      deviceId: 'dev-host',
      accessToken: 'tok',
      buildSession: (seed, scope) =>
          buildDuelSession(pack(), seed: seed, scope: scope),
      xpSink: (t, x) async => xpHost.add(t),
    );
    final guest = DuelFlow(
      gateway: server,
      wireFactory: () => FakeWire(guestCh),
      deviceId: 'dev-guest',
      accessToken: 'tok',
      buildSession: (seed, scope) =>
          buildDuelSession(pack(), seed: seed, scope: scope),
      xpSink: (t, x) async => xpGuest.add(t),
    );
    final code = await host.create(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    await guest.joinByCode(code);
    hostCh.injectPresence(<String, dynamic>{'dev-guest': <String, dynamic>{}});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await host.start();
    for (final m in hostCh.sent) {
      guestCh.inject(m);
    }

    // المضيف يجيب الصحيح دائماً، والضيف يجيب الخطأ دائماً
    for (var i = 0; i < 10; i++) {
      final qid = host.snapshot.questionIds[i];
      final correctShown =
          host.snapshot.optionOrders[qid]!.indexOf((qid - 1) % 4);
      final wrongShown = (correctShown + 1) % 4;
      await host.submitAnswer(correctShown);
      await guest.submitAnswer(wrongShown);
      for (final m in hostCh.sent) {
        guestCh.inject(m);
      }
      for (final m in guestCh.sent) {
        hostCh.inject(m);
      }
    }

    // بعد آخر سؤال: الاثنان أنهيا ⇒ حكم (المضيف يعيد بعد ~1ث إن سبقه الضيف)
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    check(host.snapshot.phase == DuelPhase.finished, 'المضيف أنهى',
        host.snapshot.phase.name);
    check(guest.snapshot.phase == DuelPhase.finished, 'الضيف أنهى',
        guest.snapshot.phase.name);
    check(host.snapshot.verdict != null, 'حكم صادر للمضيف');
    check(host.snapshot.iWon, 'المضيف فاز (أجاب كلها صح)');
    check(host.snapshot.myScore == 2300, 'نقاط المضيف 2300 (2×100+3×200+5×300)',
        '${host.snapshot.myScore}');
    check(server.finishCalls >= 2, 'استدعاء الحكم من الطرفين');
    check(xpHost.contains('duelWin'), 'XP مضيف = duelWin', '$xpHost');
    check(xpGuest.contains('duelLoss'), 'XP ضيف = duelLoss', '$xpGuest');
    await host.dispose();
    await guest.dispose();
  });

  test('مهلة السؤال: تقدم تلقائي بلا إجابة والسلسلة تصفر', () async {
    final server = FakeServer(pack());
    final ch = FakeChannel();
    final flow = DuelFlow(
      gateway: server,
      wireFactory: () => FakeWire(ch),
      deviceId: 'dev-host',
      accessToken: 'tok',
      buildSession: (seed, scope) =>
          buildDuelSession(pack(), seed: seed, scope: scope),
      questionSeconds: 0, // تنتهي فوراً
    );
    await flow.create(
      units: const ['U1', 'U2', 'U3'],
      packTag: 'test-pack-1',
    );
    ch.injectPresence(<String, dynamic>{'dev-guest': <String, dynamic>{}});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await flow.start();
    // questionSeconds=0 ⇒ أول نبضة (250ms) تنهي السؤال الأول
    await Future<void>.delayed(const Duration(milliseconds: 400));
    check(flow.snapshot.currentIndex > 0, 'تقدمت الأسئلة تلقائياً بالمهلة',
        'idx=${flow.snapshot.currentIndex}');
    check(flow.snapshot.myAnswers[0] == null, 'إجابة السؤال الأول null (مهلة)');
    check(flow.snapshot.myStreak == 0, 'السلسلة صفر بعد المهلة');
    await flow.dispose();
  });
}
