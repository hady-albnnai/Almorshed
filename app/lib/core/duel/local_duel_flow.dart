// ═══════════════════════════════════════════════════════════════════════
// local_duel_flow.dart — آلة حالات المبارزة المحلية (F5.4).
// بلا سيرفر: جهازان على ناقل محلي (نقطة اتصال/شبكة مشتركة) يتبادلان
// (الرمز، البذرة، السلسلة، الإنجاز) والمضيف يصدر الحكم بمحرك حتمي مطابق
// للسيرفر (gradeDuelSide/hostWins) — نفس الأسئلة بالجهازين من نفس البذرة.
// ⚠️ بلا XP للدوري: دعوى xpDuelWin/Loss تتطلب صفاً خادمياً (verify_commit)
// لا وجود له في المبارزة المحلية — المبارزة المحلية تدريب نزيه بلا نقاط.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math';

import 'duel_engine.dart';
import 'duel_flow.dart' show DuelPhase, DuelRole, DuelSnapshot;
import 'local_link.dart';
import '../supabase/duel_api.dart' show DuelVerdict;

/// مولّد رمز محلي: ٦ محارف Crockford (٣٠ بت) — قصير للنقل شفهياً.
String encodeLocalCode(int v) {
  final buf = StringBuffer();
  var x = v & 0x3FFFFFFF;
  for (var i = 0; i < 6; i++) {
    buf.write(RoomCode.alphabet[x & 31]);
    x >>= 5;
  }
  return buf.toString();
}

/// تطبيع رمز مُدخل يدوياً (كبير + بلا شرطات + I/O/L→1/0/1).
String normalizeLocalCode(String raw) => raw
    .toUpperCase()
    .replaceAll('-', '')
    .replaceAll(' ', '')
    .replaceAllMapped(RegExp('[OIL]'), (m) => m.group(0) == 'O' ? '0' : '1');

/// آلة حالات مبارزة محلية — تُنتج نفس DuelSnapshot فتعرضها شاشات F5.3.
class LocalDuelFlow {
  LocalDuelFlow({
    required LocalDuelTransport transport,
    required this.deviceId,
    required this.myName,
    required DuelSession Function(int seed, DuelScope scope) buildSession,
    this.questionSeconds = DuelConstants.questionSeconds,
    int Function()? nowMs,
  })  : _transport = transport,
        _buildSession = buildSession,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final LocalDuelTransport _transport;
  final String deviceId;
  final String myName;
  final DuelSession Function(int seed, DuelScope scope) _buildSession;
  final int questionSeconds;
  final int Function() _nowMs;

  DuelRole? _role;
  String? _roomCode;
  int? _seed;
  DuelScope? _scope;
  DuelSession? _session;
  List<int?> _myAnswers = const <int?>[];
  bool _myDone = false;
  bool _oppDone = false;
  bool _oppJoined = false;
  String? _oppName;
  String? _oppDeviceId;
  int _myStreak = 0;
  int _myScore = 0;
  int _myCorrects = 0;
  int _oppStreak = 0;
  int _oppScore = 0;
  int _oppCorrects = 0;
  int _oppAnswered = 0;
  final List<int> _oppStreaks = <int>[];
  int _currentIndex = 0;
  int _questionDeadlineMs = 0;
  Timer? _tick;
  DuelVerdict? _verdict;
  String _error = '';
  DuelPhase _phase = DuelPhase.idle;
  LocalLink? _link;
  StreamSubscription<Map<String, dynamic>>? _sub;

  final StreamController<DuelSnapshot> _ctrl =
      StreamController<DuelSnapshot>.broadcast();

  Stream<DuelSnapshot> get stream => _ctrl.stream;
  DuelSnapshot get snapshot => _build();

  // ═════════════ المضيف ═════════════
  /// إنشاء مبارزة محلية — يستمع للضيف ويعيد الرمز فوراً (العرض بلا انتظار).
  Future<String> host({
    required List<String> units,
    required String packTag,
    int port = TcpDuelTransport.defaultPort,
  }) async {
    _role = DuelRole.host;
    _phase = DuelPhase.creating;
    _emit();
    final scope = DuelScope(units: units, packTag: packTag);
    final code = ((Random.secure().nextInt(1 << 15)) << 15) |
        Random.secure().nextInt(1 << 15);
    final seed = makeSeed(tag: scopeTagOf(scope), roomCode: code);
    _roomCode = encodeLocalCode(code);
    _seed = seed;
    _scope = scope;
    _session = _buildSession(seed, scope);
    _myAnswers = List<int?>.filled(_session!.length, null);
    unawaited(_acceptGuest(port, code));
    _phase = DuelPhase.lobby;
    _emit();
    return _roomCode!;
  }

  Future<void> _acceptGuest(int port, int code) async {
    try {
      final link = await _transport.awaitGuest(port: port);
      _link = link;
      _sub = link.messages.listen(_onMessage);
    } catch (_) {
      if (_phase != DuelPhase.idle && _phase != DuelPhase.finished) {
        _fail('تعذر فتح الاتصال المحلي — تأكد من تفعيل نقطة الاتصال');
      }
    }
  }

  // ═════════════ الضيف ═════════════
  Future<void> join({
    required String hostIp,
    required int port,
    required String code,
  }) async {
    _role = DuelRole.guest;
    _phase = DuelPhase.creating;
    _roomCode = normalizeLocalCode(code);
    _emit();
    try {
      final link = await _transport.joinHost(hostIp: hostIp, port: port);
      _link = link;
      _sub = link.messages.listen(_onMessage);
      link.send(<String, dynamic>{
        't': 'join',
        'name': myName,
        'code': _roomCode,
        'deviceId': deviceId,
      });
    } catch (_) {
      _fail('تعذر الاتصال بالمضيف — تحقق من العنوان والرمز');
    }
  }

  // ═════════════ مشترك ═════════════
  Future<void> start() async {
    if (_role != DuelRole.host || _phase != DuelPhase.lobby || !_oppJoined) {
      return;
    }
    _enterLive();
    _link?.send(const <String, dynamic>{'t': 'start'});
  }

  Future<void> submitAnswer(int chosen) async {
    if (_phase != DuelPhase.live) return;
    final index = _currentIndex;
    if (index >= _session!.length) return;
    _recordAnswer(index, chosen);
    _link?.send(<String, dynamic>{'t': 'answer', 'i': index, 'streak': _myStreak});
    await _advance();
  }

  /// مهلة السؤال — بلا اختيار (يُعامل كخطأ) وبث سلسلة صفر.
  Future<void> timeout() async {
    if (_phase != DuelPhase.live) return;
    final index = _currentIndex;
    if (index >= _session!.length) return;
    _recordAnswer(index, null);
    _link?.send(<String, dynamic>{'t': 'answer', 'i': index, 'streak': _myStreak});
    await _advance();
  }

  Future<void> cancel() async {
    if (_phase == DuelPhase.live || _phase == DuelPhase.finished) return;
    _phase = DuelPhase.idle;
    _emit();
    await _teardown();
  }

  Future<void> dispose() async {
    _tick?.cancel();
    await _teardown();
    await _ctrl.close();
  }

  Future<void> _teardown() async {
    _tick?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      _link?.send(const <String, dynamic>{'t': 'bye'});
    } catch (_) {}
    await _link?.close();
    _link = null;
    await _transport.shutdown();
  }

  // ═════════════ الرسائل ═════════════
  void _onMessage(Map<String, dynamic> m) {
    switch (m['t'] as String?) {
      case 'join':
        _onJoin(m);
      case 'hello':
        _onHello(m);
      case 'start':
        if (_role == DuelRole.guest && _phase == DuelPhase.lobby) _enterLive();
      case 'answer':
        _onAnswer(m);
      case 'done':
        _oppDone = true;
        _emit();
        if (_role == DuelRole.host) _maybeVerdict();
      case 'verdict':
        _onVerdictMsg(m);
      case 'reject':
        _fail('الرمز غير صحيح');
      case 'bye':
        if (_phase != DuelPhase.finished) _fail('أنهى الطرف الآخر المبارزة');
    }
  }

  void _onJoin(Map<String, dynamic> m) {
    if (_role != DuelRole.host) return;
    final code = m['code'] as String?;
    if (normalizeLocalCode(code ?? '') != _roomCode) {
      _link?.send(const <String, dynamic>{'t': 'reject'});
      return;
    }
    _oppName = (m['name'] as String?) ?? 'الضيف';
    _oppDeviceId = (m['deviceId'] as String?) ?? '';
    _oppJoined = true;
    _link?.send(<String, dynamic>{
      't': 'hello',
      'name': myName,
      'seed': _seed,
      'scope': _scope!.toJson(),
      'code': _roomCode,
      'deviceId': deviceId,
    });
    _emit();
  }

  void _onHello(Map<String, dynamic> m) {
    if (_role != DuelRole.guest) return;
    final seed = (m['seed'] as num?)?.toInt();
    final scopeJson = (m['scope'] as Map?)?.cast<String, dynamic>();
    if (seed == null || scopeJson == null) {
      _fail('استقبال غير صالح من المضيف');
      return;
    }
    _seed = seed;
    _scope = DuelScope.fromJson(scopeJson);
    _session = _buildSession(seed, _scope!);
    _myAnswers = List<int?>.filled(_session!.length, null);
    _oppName = (m['name'] as String?) ?? 'المضيف';
    _oppDeviceId = (m['deviceId'] as String?) ?? '';
    _oppJoined = true;
    _phase = DuelPhase.lobby;
    _emit();
  }

  void _onAnswer(Map<String, dynamic> m) {
    final i = (m['i'] as num?)?.toInt();
    final streak = (m['streak'] as num?)?.toInt();
    if (i == null || streak == null) return;
    while (_oppStreaks.length <= i) {
      _oppStreaks.add(0);
    }
    _oppStreaks[i] = streak;
    // تقدير حي — الصحة من تطور السلسلة (تزايد = صحيح، صفر = خطأ)
    if (streak > _oppStreak) {
      _oppCorrects++;
      final mult = streak >= 6 ? 3 : (streak >= 3 ? 2 : 1);
      _oppScore += DuelConstants.pointsPerCorrect * mult;
    }
    _oppStreak = streak;
    if (i + 1 > _oppAnswered) _oppAnswered = i + 1;
    _emit();
  }

  void _onVerdictMsg(Map<String, dynamic> m) {
    if (_role != DuelRole.guest || _phase == DuelPhase.finished) return;
    final hostScore = (m['hostScore'] as num?)?.toInt() ?? 0;
    final guestScore = (m['guestScore'] as num?)?.toInt() ?? 0;
    final winner = m['winner'] as String?;
    final winnerDevice =
        winner == 'guest' ? deviceId : (_oppDeviceId ?? deviceId);
    _verdict = DuelVerdict(
      hostScore: hostScore,
      guestScore: guestScore,
      winnerDevice: winnerDevice,
      already: false,
      myDevice: deviceId,
      corrects: _session!.correctDisplay,
    );
    _phase = DuelPhase.finished;
    _emit();
  }

  // ═════════════ الحكم (المضيف) ═════════════
  void _maybeVerdict() {
    if (_role != DuelRole.host || !_myDone || !_oppDone) return;
    if (_verdict != null) return;
    final s = _session!;
    final hostG = gradeDuelSide(s, _myAnswers);
    final guestG = _gradeFromStreaks(_oppStreaks);
    final hostWon = hostWins(host: hostG, guest: guestG, seed: _seed!);
    final winnerDevice = hostWon ? deviceId : (_oppDeviceId ?? '');
    _verdict = DuelVerdict(
      hostScore: hostG.score,
      guestScore: guestG.score,
      winnerDevice: winnerDevice,
      already: false,
      myDevice: deviceId,
      corrects: s.correctDisplay,
    );
    _phase = DuelPhase.finished;
    _emit();
    _link?.send(<String, dynamic>{
      't': 'verdict',
      'hostScore': hostG.score,
      'guestScore': guestG.score,
      'winner': hostWon ? 'host' : 'guest',
      'hostCorrects': hostG.corrects,
      'guestCorrects': guestG.corrects,
    });
  }

  DuelSideResult _gradeFromStreaks(List<int> streaks) {
    var score = 0;
    var corrects = 0;
    var prev = 0;
    for (final st in streaks) {
      if (st > prev) {
        corrects++;
        final mult = st >= 6 ? 3 : (st >= 3 ? 2 : 1);
        score += DuelConstants.pointsPerCorrect * mult;
      }
      prev = st;
    }
    return DuelSideResult(score: score, corrects: corrects);
  }

  // ═════════════ السؤال والمهلة ═════════════
  void _enterLive() {
    _phase = DuelPhase.live;
    _currentIndex = 0;
    _startTick();
    _emit();
  }

  void _startTick() {
    _tick?.cancel();
    _questionDeadlineMs = _nowMs() + questionSeconds * 1000;
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_phase != DuelPhase.live) {
        _tick?.cancel();
        return;
      }
      if (_nowMs() >= _questionDeadlineMs) {
        unawaited(timeout());
      } else {
        _emit();
      }
    });
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
    _emit();
  }

  Future<void> _advance() async {
    _currentIndex++;
    if (_currentIndex >= _session!.length) {
      _tick?.cancel();
      await _finishMine();
    } else {
      _startTick();
      _emit();
    }
  }

  Future<void> _finishMine() async {
    _myDone = true;
    _emit();
    _link?.send(const <String, dynamic>{'t': 'done'});
    if (_role == DuelRole.host) _maybeVerdict();
  }

  int _remainingSeconds() {
    if (_phase != DuelPhase.live) return 0;
    final ms = _questionDeadlineMs - _nowMs();
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  String _fail(String message) {
    _error = message;
    _phase = DuelPhase.failed;
    _tick?.cancel();
    _emit();
    return message;
  }

  DuelSnapshot _build() => DuelSnapshot(
        phase: _phase,
        role: _role,
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
}
