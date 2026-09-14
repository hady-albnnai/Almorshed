// ═══════════════════════════════════════════════════════════════════════
// duel_flow.dart — آلة حالات المبارزة الحية (F5.3).
// نقية Dart (بلا Flutter) — تربط duel_engine (البناء الحتمي) بـ duel_api
// (REST) والقناة الخاصة (Realtime) وتُنتج لقطات للواجهات.
// العقد: docs/16 §٦ — الحكم خادمي حصراً (العميل يعرض تقديره الخاص حصراً).
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math';

import 'duel_engine.dart';
import '../supabase/duel_api.dart';
import '../supabase/realtime_client.dart';
import '../supabase/supabase_transport.dart';

/// مراحل المبارزة — من منظور جهازي.
enum DuelPhase { idle, creating, lobby, live, finished, failed }

/// دوري في المبارزة.
enum DuelRole { host, guest }

/// بثّ XP عند الحسم (إنتاج: XpRecorder.record — اختبار: التقاط).
typedef DuelXpSink = Future<void> Function(
    String typeId, Map<String, dynamic> extra);

/// عقد REST المبارزة — مطابق لدوال `DuelApi` (إنتاج: `ApiDuelGateway`).
abstract class DuelGateway {
  Future<DuelRow> createDuel({
    required String accessToken,
    required String roomCode,
    required int seed,
    required Map<String, dynamic> scopeJson,
    required String hostDevice,
    required String hostName,
  });

  Future<DuelRow?> findLobbyDuel({
    required String accessToken,
    required String roomCode,
  });

  Future<DuelRow> joinAsGuest({
    required String accessToken,
    required String duelId,
    required String guestDevice,
    required String guestName,
  });

  Future<void> startDuel({required String accessToken, required String duelId});

  Future<DuelRow> fetchDuel({required String accessToken, required String duelId});

  Future<void> insertAnswer({
    required String accessToken,
    required String duelId,
    required String deviceId,
    required int qIndex,
    required int chosen,
  });

  Future<void> markDone({
    required String accessToken,
    required String duelId,
    required String deviceId,
  });

  Future<DuelVerdict> finish({
    required String accessToken,
    required String duelId,
    required String myDevice,
  });
}

/// غلاف إنتاجي فوق `DuelApi`.
class ApiDuelGateway implements DuelGateway {
  ApiDuelGateway(this._api);

  final DuelApi _api;

  @override
  Future<DuelRow> createDuel({
    required String accessToken,
    required String roomCode,
    required int seed,
    required Map<String, dynamic> scopeJson,
    required String hostDevice,
    required String hostName,
  }) =>
      _api.createDuel(
        accessToken: accessToken,
        roomCode: roomCode,
        seed: seed,
        scopeJson: scopeJson,
        hostDevice: hostDevice,
        hostName: hostName,
      );

  @override
  Future<DuelRow?> findLobbyDuel({
    required String accessToken,
    required String roomCode,
  }) =>
      _api.findLobbyDuel(accessToken: accessToken, roomCode: roomCode);

  @override
  Future<DuelRow> joinAsGuest({
    required String accessToken,
    required String duelId,
    required String guestDevice,
    required String guestName,
  }) =>
      _api.joinAsGuest(
        accessToken: accessToken,
        duelId: duelId,
        guestDevice: guestDevice,
        guestName: guestName,
      );

  @override
  Future<void> startDuel({required String accessToken, required String duelId}) =>
      _api.startDuel(accessToken: accessToken, duelId: duelId);

  @override
  Future<DuelRow> fetchDuel({required String accessToken, required String duelId}) =>
      _api.fetchDuel(accessToken: accessToken, duelId: duelId);

  @override
  Future<void> insertAnswer({
    required String accessToken,
    required String duelId,
    required String deviceId,
    required int qIndex,
    required int chosen,
  }) =>
      _api.insertAnswer(
        accessToken: accessToken,
        duelId: duelId,
        deviceId: deviceId,
        qIndex: qIndex,
        chosen: chosen,
      );

  @override
  Future<void> markDone({
    required String accessToken,
    required String duelId,
    required String deviceId,
  }) =>
      _api.markDone(accessToken: accessToken, duelId: duelId, deviceId: deviceId);

  @override
  Future<DuelVerdict> finish({
    required String accessToken,
    required String duelId,
    required String myDevice,
  }) =>
      _api.finish(accessToken: accessToken, duelId: duelId, myDevice: myDevice);
}

/// قناة حيّة مجردة (لوبي/لعب) — إنتاجها `RealtimeDuelWire`، واختبارها وهمي.
abstract class DuelChannelLike {
  String get topic;
  Stream<Map<String, dynamic>> get broadcasts;
  Stream<Map<String, dynamic>> get presenceJoins;
  Stream<Map<String, dynamic>> get presenceLeaves;
  Future<bool> join();
  bool sendBroadcast(String event, Map<String, dynamic> payload);
}

/// نقلية حيّة مجردة — قناة واحدة لكل مبارزة.
abstract class DuelWireLike {
  Future<void> connect({required String accessToken});
  Future<void> close();
  DuelChannelLike channel(String topic, {String? presenceKey});
}

/// غلاف إنتاجي فوق `SupabaseRealtime` (F5.2).
class RealtimeDuelWire implements DuelWireLike {
  RealtimeDuelWire(this._rt);

  final SupabaseRealtime _rt;

  @override
  Future<void> connect({required String accessToken}) =>
      _rt.connect(accessToken: accessToken);

  @override
  Future<void> close() => _rt.close();

  @override
  DuelChannelLike channel(String topic, {String? presenceKey}) =>
      _RealtimeDuelChannel(_rt.channel(topic, presenceKey: presenceKey));
}

class _RealtimeDuelChannel implements DuelChannelLike {
  _RealtimeDuelChannel(this._c);

  final DuelChannel _c;

  @override
  String get topic => _c.topic;

  @override
  Stream<Map<String, dynamic>> get broadcasts => _c.broadcasts;

  @override
  Stream<Map<String, dynamic>> get presenceJoins => _c.presenceJoins;

  @override
  Stream<Map<String, dynamic>> get presenceLeaves => _c.presenceLeaves;

  @override
  Future<bool> join() => _c.join();

  @override
  bool sendBroadcast(String event, Map<String, dynamic> payload) =>
      _c.sendBroadcast(event, payload);
}

/// سياق بناء تدفق — تجميع ما تحضّره `main.dart` (جلسة + جهاز + نقلية).
class DuelContext {
  const DuelContext({
    required this.gateway,
    required this.wireFactory,
    required this.accessToken,
    required this.deviceId,
  });

  final DuelGateway gateway;
  final DuelWireLike Function() wireFactory;
  final String accessToken;
  final String deviceId;
}

/// لقطة حالة التدفق — كل تغيير يُبث عبر `stream`.
class DuelSnapshot {
  const DuelSnapshot({
    this.phase = DuelPhase.idle,
    this.role,
    this.duelId,
    this.roomCode,
    this.error = '',
    this.opponentJoined = false,
    this.opponentName,
    this.questionIds = const <int>[],
    this.optionOrders = const <int, List<int>>{},
    this.currentIndex = 0,
    this.myAnswers = const <int?>[],
    this.myStreak = 0,
    this.myScore = 0,
    this.myCorrects = 0,
    this.oppStreak = 0,
    this.oppScore = 0,
    this.oppCorrects = 0,
    this.oppAnswered = 0,
    this.myDone = false,
    this.oppDone = false,
    this.remainingSeconds = 0,
    this.verdict,
    this.myDeviceId,
  });

  final DuelPhase phase;
  final DuelRole? role;
  final String? duelId;
  final String? roomCode;
  final String error;
  final bool opponentJoined;
  final String? opponentName;
  final List<int> questionIds;
  final Map<int, List<int>> optionOrders;
  final int currentIndex;
  final List<int?> myAnswers;
  final int myStreak;
  final int myScore;
  final int myCorrects;
  final int oppStreak;
  final int oppScore;
  final int oppCorrects;
  final int oppAnswered;
  final bool myDone;
  final bool oppDone;
  final int remainingSeconds;
  final DuelVerdict? verdict;
  final String? myDeviceId;

  bool get isHost => role == DuelRole.host;
  int get questionCount => questionIds.length;
  bool get iWon =>
      verdict != null && myDeviceId != null && verdict!.winnerDevice == myDeviceId;
  int? get hostScore => verdict?.hostScore;
  int? get guestScore => verdict?.guestScore;
}

/// آلة حالات المبارزة — الحكم خادمي، والعرض المحلي تقديري حصراً.
class DuelFlow {
  DuelFlow({
    required DuelGateway gateway,
    required DuelWireLike Function() wireFactory,
    required String deviceId,
    required String accessToken,
    required DuelSession Function(int seed, DuelScope scope) buildSession,
    this.questionSeconds = DuelConstants.questionSeconds,
    this.xpSink,
    int Function()? nowMs,
    Duration Function(int attempt)? retryDelay,
  })  : _gateway = gateway,
        _wireFactory = wireFactory,
        deviceId = deviceId,
        accessToken = accessToken,
        _buildSession = buildSession,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _retryDelay = retryDelay ??
            ((attempt) => Duration(seconds: attempt <= 3 ? 1 : 3));

  final DuelGateway _gateway;
  final DuelWireLike Function() _wireFactory;
  final String deviceId;
  final String accessToken;
  final DuelSession Function(int seed, DuelScope scope) _buildSession;
  final int questionSeconds;

  /// بثّ نقاط الحسم (duelWin/duelLoss) — null بالاختبارات.
  final DuelXpSink? xpSink;
  final int Function() _nowMs;
  final Duration Function(int attempt) _retryDelay;

  DuelWireLike? _wire;
  DuelChannelLike? _channel;
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  DuelRole? _role;
  String? _duelId;
  String? _roomCode;
  DuelSession? _session;
  List<int?> _myAnswers = const <int?>[];
  bool _myDone = false;
  bool _oppDone = false;
  bool _oppJoined = false;
  String? _oppName;
  int _myStreak = 0;
  int _myScore = 0;
  int _myCorrects = 0;
  int _oppStreak = 0;
  int _oppScore = 0;
  int _oppCorrects = 0;
  int _oppAnswered = 0;
  int _currentIndex = 0;
  int _questionDeadlineMs = 0;
  DuelVerdict? _verdict;
  String _error = '';
  DuelPhase _phase = DuelPhase.idle;
  Timer? _tick;
  final List<Future<void>> _pendingInserts = <Future<void>>[];

  final StreamController<DuelSnapshot> _ctrl =
      StreamController<DuelSnapshot>.broadcast();

  /// تيار اللقطات — الواجهة تبني عليه.
  Stream<DuelSnapshot> get stream => _ctrl.stream;

  /// أحدث لقطة.
  DuelSnapshot get snapshot => _build();

  DuelSnapshot _build() => DuelSnapshot(
        phase: _phase,
        role: _role,
        duelId: _duelId,
        roomCode: _roomCode,
        error: _error,
        opponentJoined: _oppJoined,
        opponentName: _oppName,
        questionIds: _session?.built.questionIds ?? const <int>[],
        optionOrders:
            _session?.built.optionOrders ?? const <int, List<int>>{},
        currentIndex: _currentIndex,
        myAnswers: List<int?>.unmodifiable(_myAnswers),
        myStreak: _myStreak,
        myScore: _myScore,
        myCorrects: _myCorrects,
        oppStreak: _oppStreak,
        oppScore: _oppScore,
        oppCorrects: _oppCorrects,
        oppAnswered: _oppAnswered,
        myDone: _myDone,
        oppDone: _oppDone,
        remainingSeconds: _remainingSeconds(),
        verdict: _verdict,
        myDeviceId: deviceId,
      );

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_build());
  }

  int _remainingSeconds() {
    if (_phase != DuelPhase.live) return 0;
    final ms = _questionDeadlineMs - _nowMs();
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// توليد رمز غرفة ٥٠ بت (Crockford-10) — تصادمٌ نادر يُعاد محاولته.
  int _newRoomCode() {
    final r = Random.secure();
    return ((r.nextInt(1 << 25)) << 25) | r.nextInt(1 << 25);
  }

  /// إنشاء مبارزة (مضيف) — يعيد رمز الغرفة عند النجاح.
  Future<String> create({
    required List<String> units,
    required String packTag,
  }) async {
    _phase = DuelPhase.creating;
    _role = DuelRole.host;
    _emit();
    final scope = DuelScope(units: units, packTag: packTag);
    final tag = scopeTagOf(scope);
    DuelRow? row;
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = _newRoomCode();
      final seed = makeSeed(tag: tag, roomCode: code);
      try {
        row = await _gateway.createDuel(
          accessToken: accessToken,
          roomCode: RoomCode.encode(code),
          seed: seed,
          scopeJson: scope.toJson(),
          hostDevice: deviceId,
          hostName: 'المضيف',
        );
        break;
      } on TransportException catch (e) {
        // 409 = تصادم رمز غرفة نشط — أعد المحاولة برمز جديد
        if (e.status != 409 || attempt == 2) {
          return _fail('تعذر إنشاء المبارزة: ${e.message}');
        }
      }
    }
    if (row == null) return _fail('تعذر إنشاء المبارزة');
    _duelId = row.id;
    _roomCode = row.roomCode;
    try {
      _session = _buildSession(row.seed, scope);
    } on FormatException {
      return _fail('بنك الأسئلة المعتمدة لا يكفي لهذه المبارزة');
    }
    _myAnswers = List<int?>.filled(_session!.length, null);
    await _openWire();
    _phase = DuelPhase.lobby;
    _emit();
    return row.roomCode;
  }

  /// انضمام ضيف برمز الغرفة.
  Future<void> joinByCode(String roomCode) async {
    _phase = DuelPhase.creating;
    _role = DuelRole.guest;
    _emit();
    int code;
    try {
      code = RoomCode.decode(roomCode);
    } on FormatException {
      _fail('رمز غير صالح');
      return;
    }
    try {
      final row = await _gateway.findLobbyDuel(
        accessToken: accessToken,
        roomCode: RoomCode.encode(code),
      );
      if (row == null) {
        _fail('لا مبارزة بهذا الرمز');
        return;
      }
      final joined = await _gateway.joinAsGuest(
        accessToken: accessToken,
        duelId: row.id,
        guestDevice: deviceId,
        guestName: 'الضيف',
      );
      if (joined.scopeJson['units'] is! List) {
        _fail('نطاق المبارزة غير صالح');
        return;
      }
      final scope = DuelScope.fromJson(joined.scopeJson);
      _duelId = joined.id;
      _roomCode = joined.roomCode;
      _oppName = joined.hostName;
      _oppJoined = true;
      try {
        _session = _buildSession(joined.seed, scope);
      } on FormatException {
        _fail('بنك الأسئلة المعتمدة لا يكفي لهذه المبارزة');
        return;
      }
      _myAnswers = List<int?>.filled(_session!.length, null);
      await _openWire();
      _phase = DuelPhase.lobby;
      _emit();
    } on TransportException catch (e) {
      _fail('تعذر الانضمام: ${e.message}');
    }
  }

  /// بدء المضيف — من لوبي فيه الضيف.
  Future<void> start() async {
    if (_role != DuelRole.host || _phase != DuelPhase.lobby || !_oppJoined) {
      return;
    }
    try {
      await _gateway.startDuel(accessToken: accessToken, duelId: _duelId!);
      _enterLive();
      _channel?.sendBroadcast('start', const <String, dynamic>{});
    } on TransportException catch (e) {
      _fail('تعذر البدء: ${e.message}');
    }
  }

  void _enterLive() {
    _phase = DuelPhase.live;
    _currentIndex = 0;
    _questionDeadlineMs = _nowMs() + questionSeconds * 1000;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
    _emit();
  }

  void _onTick() {
    if (_phase != DuelPhase.live) return;
    if (_nowMs() >= _questionDeadlineMs) {
      unawaited(timeout());
    } else {
      _emit();
    }
  }

  /// إجابة عن السؤال الحالي — يتقدم فوراً (لا ينتظر الشبكة)، والإدراج يُعلَّق
  /// ليُنتظر قبل إعلان النهاية (تفادي سباق الحكم الخادمي على آخر سؤال).
  Future<void> submitAnswer(int chosen) async {
    if (_phase != DuelPhase.live) return;
    final index = _currentIndex;
    if (index >= (_session?.length ?? 0)) return;
    _recordAnswer(index, chosen);
    _pendingInserts.add(_gateway
        .insertAnswer(
          accessToken: accessToken,
          duelId: _duelId!,
          deviceId: deviceId,
          qIndex: index,
          chosen: chosen,
        )
        .catchError((Object _) {
      // العرض المحلي مستمر — الحكم الخادمي يحسم (إجابة مفقودة = خطأ)
    }));
    _advance();
  }

  /// انتهت مهلة السؤال — بلا إجابة (يعاملها الخادم كخطأ).
  Future<void> timeout() async {
    if (_phase != DuelPhase.live) return;
    final index = _currentIndex;
    if (index >= (_session?.length ?? 0)) return;
    _recordAnswer(index, null);
    _advance();
  }

  void _recordAnswer(int index, int? chosen) {
    final s = _session!;
    final correct = chosen != null && chosen == s.correctDisplay[index];
    final answers = List<int?>.of(_myAnswers);
    answers[index] = chosen;
    _myAnswers = answers;
    if (correct) {
      _myStreak++;
      _myCorrects++;
      final mult = _myStreak >= 6 ? 3 : (_myStreak >= 3 ? 2 : 1);
      _myScore += DuelConstants.pointsPerCorrect * mult;
    } else {
      _myStreak = 0;
    }
    // بثّ تقدّمي لا يكشف الاختيار — السلسلة فقط (يحسم الخادم)
    _channel?.sendBroadcast(
        'answer', <String, dynamic>{'i': index, 'streak': _myStreak});
    _emit();
  }

  void _advance() {
    _currentIndex++;
    if (_currentIndex >= _session!.length) {
      _tick?.cancel();
      unawaited(_finishMine());
    } else {
      _questionDeadlineMs = _nowMs() + questionSeconds * 1000;
      _emit();
    }
  }

  Future<void> _finishMine() async {
    _myDone = true;
    _emit();
    // انتظر إجاباتي المعلقة قبل الإعلان — لا يحكم الخادم قبل وصولها
    await Future.wait(_pendingInserts);
    _pendingInserts.clear();
    try {
      await _gateway.markDone(
        accessToken: accessToken,
        duelId: _duelId!,
        deviceId: deviceId,
      );
    } on TransportException catch (_) {
      // الإعلان فشل — الحكم قد يتأخر لانتهاء المهلة لكنه سيصدر
    }
    _channel?.sendBroadcast('done', const <String, dynamic>{});
    await _awaitVerdict();
  }

  Future<void> _awaitVerdict() async {
    // سقف: count×20ث + 60ث سماح + هامش — بتراجع تصاعدي
    final deadline = _nowMs() + (questionSeconds * 10 + 90) * 1000;
    var attempt = 0;
    while (_nowMs() < deadline) {
      try {
        final v = await _gateway.finish(
          accessToken: accessToken,
          duelId: _duelId!,
          myDevice: deviceId,
        );
        _onVerdict(v);
        return;
      } on TransportException catch (e) {
        const retryable = <String>{
          'WAITING_OPPONENT',
          'NOT_DONE_YET',
          'COMMIT_RACE',
        };
        if (e.status != 409 || !retryable.contains(e.message)) {
          _fail('تعذر إصدار الحكم: ${e.message}');
          return;
        }
      }
      attempt++;
      await Future<void>.delayed(_retryDelay(attempt));
    }
    _fail('انتهت مهلة المبارزة');
  }

  void _onVerdict(DuelVerdict v) {
    _verdict = v;
    _phase = DuelPhase.finished;
    _emit();
    final sink = xpSink;
    if (sink != null && _duelId != null) {
      final won = v.winnerDevice == deviceId;
      unawaited(sink(won ? 'duelWin' : 'duelLoss', <String, dynamic>{
        'duelId': _duelId!,
      }));
    }
  }

  /// إلغاء من اللوبي (لا إلغاء بعد البدء — بلا void خادمي في v1).
  Future<void> cancel() async {
    if (_phase == DuelPhase.live || _phase == DuelPhase.finished) return;
    _phase = DuelPhase.idle;
    _emit();
    await _teardown();
  }

  /// تنظيف كامل (تُستدعى عند مغادرة الشاشات نهائياً).
  Future<void> dispose() async {
    _tick?.cancel();
    await _teardown();
    await _ctrl.close();
  }

  Future<void> _teardown() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _wire?.close();
    _wire = null;
    _channel = null;
  }

  Future<void> _openWire() async {
    final wire = _wireFactory();
    _wire = wire;
    await wire.connect(accessToken: accessToken);
    final ch = wire.channel('duel:$_duelId', presenceKey: deviceId);
    _channel = ch;
    _subs.add(ch.presenceJoins.listen(_onPresence));
    _subs.add(ch.broadcasts.listen(_onBroadcast));
    await ch.join();
  }

  void _onPresence(Map<String, dynamic> payload) {
    if (_role != DuelRole.host) return;
    final hasOther = payload.keys.any((k) => k != deviceId);
    if (hasOther) unawaited(_onOpponentJoined());
  }

  Future<void> _onOpponentJoined() async {
    if (_oppJoined) return;
    _oppJoined = true;
    _emit();
    try {
      final row = await _gateway.fetchDuel(
        accessToken: accessToken,
        duelId: _duelId!,
      );
      if (_role == DuelRole.host) {
        _oppName = row.guestName;
      } else {
        _oppName = row.hostName;
      }
    } on TransportException catch (_) {
      // الاسم تجميلي — لا يفشل التدفق
    }
    _emit();
  }

  void _onBroadcast(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;
    final payload = (msg['payload'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    switch (event) {
      case 'start':
        if (_role == DuelRole.guest && _phase == DuelPhase.lobby) _enterLive();
      case 'answer':
        final i = (payload['i'] as num?)?.toInt();
        final streak = (payload['streak'] as num?)?.toInt();
        if (i != null && streak != null) _onOppAnswer(i, streak);
      case 'done':
        _oppDone = true;
        _emit();
    }
  }

  void _onOppAnswer(int index, int streak) {
    // الصحة تُستنتج من تطور السلسلة: تزايدٌ = صحيح، صفر = خطأ
    if (streak > _oppStreak) {
      _oppCorrects++;
      final mult = streak >= 6 ? 3 : (streak >= 3 ? 2 : 1);
      _oppScore += DuelConstants.pointsPerCorrect * mult;
    }
    _oppStreak = streak;
    if (index + 1 > _oppAnswered) _oppAnswered = index + 1;
    _emit();
  }

  String _fail(String message) {
    _error = message;
    _phase = DuelPhase.failed;
    _tick?.cancel();
    _emit();
    return message;
  }
}
