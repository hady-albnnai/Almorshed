// ═══════════════════════════════════════════════════════════════════════
// realtime_client.dart — عميل Supabase Realtime الأدنى (F5.2).
// بروتوكول Phoenix JSON vsn=1.0.0 (بحث 2026-09-13 — docs/16 §٧):
// wss://{ref}.supabase.co/realtime/v1/websocket?apikey=…&vsn=1.0.0
// مظروف الرسالة {topic,event,payload,ref,join_ref} — النبض ≤25 ثانية على
// topic «phoenix» — القناة الخاصة بaccess_token داخل الانضمام.
// dart:io حصراً (فلسفة النقلية) — القناة factory مُحقَنة للاختبار.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// قناة نقل مجردة — يحقنها الاختبار بدل WebSocket الحقيقي.
abstract class WsChannel {
  Stream<dynamic> get stream;
  void add(String data);
  Future<void> close();
}

class IoWsChannel implements WsChannel {
  IoWsChannel._(this._ws);
  final WebSocket _ws;

  static Future<IoWsChannel> connect(Uri uri) async {
    final ws = await WebSocket.connect(uri.toString());
    return IoWsChannel._(ws);
  }

  @override
  Stream<dynamic> get stream => _ws;

  @override
  void add(String data) => _ws.add(data);

  @override
  Future<void> close() => _ws.close();
}

typedef WsFactory = Future<WsChannel> Function(Uri uri);

Future<WsChannel> ioWsFactory(Uri uri) => IoWsChannel.connect(uri);

/// حالة قناة المبارزة.
enum DuelChannelStatus { joining, joined, closed, error }

/// قناة مبارزة واحدة (topic مثل duel:{uuid}) — بث + حضور.
class DuelChannel {
  DuelChannel._(
    this._client,
    this.topic,
    {required String? presenceKey})
      : _presenceKey = presenceKey ?? '' {
    _client._channels.add(this);
  }

  final SupabaseRealtime _client;
  final String topic;
  final String _presenceKey;

  final _status = StreamController<DuelChannelStatus>.broadcast();
  final _broadcasts = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceJoins = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceLeaves = StreamController<Map<String, dynamic>>.broadcast();

  String? _joinRef;
  Completer<bool>? _joinCompleter;
  bool _joinedOnce = false;

  Stream<DuelChannelStatus> get status => _status.stream;
  Stream<Map<String, dynamic>> get broadcasts => _broadcasts.stream;
  Stream<Map<String, dynamic>> get presenceJoins => _presenceJoins.stream;
  Stream<Map<String, dynamic>> get presenceLeaves => _presenceLeaves.stream;

  /// الانضمام — يكتمل true عند phx_reply ok (مهلة 10 ثوانٍ ⇒ false).
  Future<bool> join() async {
    if (_joinCompleter != null) return _joinCompleter!.future;
    final c = Completer<bool>();
    _joinCompleter = c;
    _status.add(DuelChannelStatus.joining);
    final ref = _client._nextRef();
    _joinRef = ref;
    _client._send(<String, dynamic>{
      'topic': 'realtime:$topic',
      'event': 'phx_join',
      'payload': <String, dynamic>{
        'config': <String, dynamic>{
          'broadcast': <String, dynamic>{'ack': false, 'self': false},
          'presence': <String, dynamic>{'key': _presenceKey},
        },
        'access_token': _client._accessToken,
      },
      'ref': ref,
      'join_ref': ref,
    });
    Timer(const Duration(seconds: 10), () {
      if (!c.isCompleted) {
        _status.add(DuelChannelStatus.error);
        c.complete(false);
      }
    });
    return c.future;
  }

  /// بث حدث على القناة (لا انتظار إقرار — ack:false بالتصميم).
  bool sendBroadcast(String event, Map<String, dynamic> payload) {
    final ref = _client._nextRef();
    return _client._send(<String, dynamic>{
      'topic': 'realtime:$topic',
      'event': 'broadcast',
      'payload': <String, dynamic>{
        'type': 'broadcast',
        'event': event,
        'payload': payload,
      },
      'ref': ref,
      'join_ref': _joinRef ?? ref,
    });
  }

  /// تحديث توكن القناة (تجديد الوليدة المجهولة أثناء اللعب).
  void updateToken() {
    if (_joinRef == null) return;
    final ref = _client._nextRef();
    _client._send(<String, dynamic>{
      'topic': 'realtime:$topic',
      'event': 'access_token',
      'payload': <String, dynamic>{'access_token': _client._accessToken},
      'ref': ref,
      'join_ref': _joinRef,
    });
  }

  void _handleReply(Map<String, dynamic> msg) {
    if (msg['ref'] != _joinRef) return;
    final status = (msg['payload'] as Map<String, dynamic>?)?['status'];
    if (status == 'ok') {
      _joinedOnce = true;
      _status.add(DuelChannelStatus.joined);
      _joinCompleter?.complete(true);
    } else {
      _status.add(DuelChannelStatus.error);
      if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
        _joinCompleter!.complete(false);
      }
    }
  }

  void _handle(Map<String, dynamic> msg) {
    final event = msg['event'] as String?;
    final payload = (msg['payload'] as Map<String, dynamic>?) ?? const {};
    if (event == 'phx_reply') return _handleReply(msg);
    if (event == 'broadcast') {
      _broadcasts.add(<String, dynamic>{
        'event': payload['event'],
        'payload': (payload['payload'] as Map<String, dynamic>?) ?? const {},
      });
    } else if (event == 'presence_state') {
      _presenceJoins.add(payload);
    } else if (event == 'presence_diff') {
      _presenceJoins.add((payload['joins'] as Map<String, dynamic>?) ?? const {});
      _presenceLeaves.add(
          (payload['leaves'] as Map<String, dynamic>?) ?? const {});
    } else if (event == 'phx_close' || event == 'phx_error') {
      _status.add(DuelChannelStatus.closed);
      if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
        _joinCompleter!.complete(false);
      }
    }
  }

  void _resetForRejoin() {
    _joinedOnce = false;
    _joinRef = null;
    _joinCompleter = null;
    _status.add(DuelChannelStatus.closed);
  }

  void _dispose() {
    _status.add(DuelChannelStatus.closed);
    _status.close();
    _broadcasts.close();
    _presenceJoins.close();
    _presenceLeaves.close();
  }
}

/// عميل Realtime خفيف: اتصال واحد + نبض + إعادة اتصال بتراجع + قنوات.
class SupabaseRealtime {
  SupabaseRealtime({
    required this.baseUrl,
    required this.anonKey,
    this.heartbeatInterval = const Duration(seconds: 20),
    WsFactory wsFactory = ioWsFactory,
  }) : _wsFactory = wsFactory;

  final String baseUrl; // مثل https://xdk….supabase.co
  final String anonKey;
  final Duration heartbeatInterval;
  final WsFactory _wsFactory;

  WsChannel? _socket;
  Timer? _heartbeat;
  int _ref = 0;
  int _tries = 0;
  bool _disposed = false;
  String _accessToken = '';

  final List<DuelChannel> _channels = [];
  final _socketStatus = StreamController<bool>.broadcast(); // مفتوح؟

  /// مفتوح الآن؟ (مفيد لمؤشر الاتصال بالواجهة)
  Stream<bool> get connection => _socketStatus.stream;

  String get _wireBase => baseUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');

  DuelChannel channel(String topic, {String? presenceKey}) =>
      DuelChannel._(this, topic, presenceKey: presenceKey);

  Future<void> updateToken(String jwt) async {
    _accessToken = jwt;
    for (final ch in _channels) {
      ch.updateToken();
    }
  }

  /// فتح الاتصال — يعيد المحاولة بتراجع 1→2→4…بسقف 16 ثانية.
  Future<void> connect({required String accessToken}) async {
    _accessToken = accessToken;
    await _open();
  }

  Future<void> _open() async {
    if (_disposed) return;
    final uri = Uri.parse(
        '$_wireBase/realtime/v1/websocket?apikey=$anonKey&vsn=1.0.0');
    try {
      final ws = await _wsFactory(uri);
      _socket = ws;
      _tries = 0;
      _socketStatus.add(true);
      ws.stream.listen(
        (data) => _onData(data as String),
        onDone: () => _onDead(),
        onError: (_) => _onDead(),
      );
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(heartbeatInterval, (_) {
        _send(<String, dynamic>{
          'topic': 'phoenix',
          'event': 'heartbeat',
          'payload': <String, dynamic>{},
          'ref': _nextRef(),
        });
      });
      // إعادة انضمام القنوات بعد الفتح
      for (final ch in _channels) {
        if (ch._joinedOnce || ch._joinCompleter != null) {
          ch._resetForRejoin();
          ch.join();
        }
      }
    } catch (_) {
      _onDead();
    }
  }

  void _onData(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return;
    }
    for (final ch in _channels) {
      if (msg['topic'] == 'realtime:${ch.topic}') ch._handle(msg);
    }
  }

  void _onDead() {
    if (_disposed) return;
    _heartbeat?.cancel();
    _socket = null;
    _socketStatus.add(false);
    for (final ch in _channels) {
      if (ch._joinCompleter != null) ch._resetForRejoin();
    }
    _tries++;
    final delay = Duration(seconds: (1 << (_tries - 1)).clamp(1, 16));
    Timer(delay, _open);
  }

  int _nextRef() => ++_ref;

  bool _send(Map<String, dynamic> msg) {
    final s = _socket;
    if (s == null) return false;
    try {
      s.add(jsonEncode(msg));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    _disposed = true;
    _heartbeat?.cancel();
    _socketStatus.add(false);
    for (final ch in _channels) {
      ch._dispose();
    }
    _channels.clear();
    await _socket?.close();
    _socket = null;
    await _socketStatus.close();
  }
}
