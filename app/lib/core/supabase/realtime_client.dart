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

//BISECT /// حالة قناة المبارزة.
//BISECT enum DuelChannelStatus { joining, joined, closed, error }
//BISECT 
//BISECT /// قناة مبارزة واحدة (topic مثل duel:{uuid}) — بث + حضور.
//BISECT class DuelChannel {
//BISECT   DuelChannel._(
//BISECT     this._client,
//BISECT     this.topic,
//BISECT     {required String? presenceKey})
//BISECT       : _presenceKey = presenceKey ?? '' {
//BISECT     _client._channels.add(this);
//BISECT   }
//BISECT 
//BISECT   final SupabaseRealtime _client;
//BISECT   final String topic;
//BISECT   final String _presenceKey;
//BISECT 
//BISECT   final _status = StreamController<DuelChannelStatus>.broadcast();
//BISECT   final _broadcasts = StreamController<Map<String, dynamic>>.broadcast();
//BISECT   final _presenceJoins = StreamController<Map<String, dynamic>>.broadcast();
//BISECT   final _presenceLeaves = StreamController<Map<String, dynamic>>.broadcast();
//BISECT 
//BISECT   String? _joinRef;
//BISECT   Completer<bool>? _joinCompleter;
//BISECT   bool _joinedOnce = false;
//BISECT 
//BISECT   Stream<DuelChannelStatus> get status => _status.stream;
//BISECT   Stream<Map<String, dynamic>> get broadcasts => _broadcasts.stream;
//BISECT   Stream<Map<String, dynamic>> get presenceJoins => _presenceJoins.stream;
//BISECT   Stream<Map<String, dynamic>> get presenceLeaves => _presenceLeaves.stream;
//BISECT 
//BISECT   /// الانضمام — يكتمل true عند phx_reply ok (مهلة 10 ثوانٍ ⇒ false).
//BISECT   Future<bool> join() async {
//BISECT     if (_joinCompleter != null) return _joinCompleter!.future;
//BISECT     final c = Completer<bool>();
//BISECT     _joinCompleter = c;
//BISECT     _status.add(DuelChannelStatus.joining);
//BISECT     final ref = _client._nextRef();
//BISECT     _joinRef = ref;
//BISECT     _client._send(<String, dynamic>{
//BISECT       'topic': 'realtime:$topic',
//BISECT       'event': 'phx_join',
//BISECT       'payload': <String, dynamic>{
//BISECT         'config': <String, dynamic>{
//BISECT           'broadcast': <String, dynamic>{'ack': false, 'self': false},
//BISECT           'presence': <String, dynamic>{'key': _presenceKey},
//BISECT         },
//BISECT         'access_token': _client._accessToken,
//BISECT       },
//BISECT       'ref': ref,
//BISECT       'join_ref': ref,
//BISECT     });
//BISECT     Timer(const Duration(seconds: 10), () {
//BISECT       if (!c.isCompleted) {
//BISECT         _status.add(DuelChannelStatus.error);
//BISECT         c.complete(false);
//BISECT       }
//BISECT     });
//BISECT     return c.future;
//BISECT   }
//BISECT 
//BISECT   /// بث حدث على القناة (لا انتظار إقرار — ack:false بالتصميم).
//BISECT   bool sendBroadcast(String event, Map<String, dynamic> payload) {
//BISECT     final ref = _client._nextRef();
//BISECT     return _client._send(<String, dynamic>{
//BISECT       'topic': 'realtime:$topic',
//BISECT       'event': 'broadcast',
//BISECT       'payload': <String, dynamic>{
//BISECT         'type': 'broadcast',
//BISECT         'event': event,
//BISECT         'payload': payload,
//BISECT       },
//BISECT       'ref': ref,
//BISECT       'join_ref': _joinRef ?? ref,
//BISECT     });
//BISECT   }
//BISECT 
//BISECT   /// تحديث توكن القناة (تجديد الوليدة المجهولة أثناء اللعب).
//BISECT   void updateToken() {
//BISECT     if (_joinRef == null) return;
//BISECT     final ref = _client._nextRef();
//BISECT     _client._send(<String, dynamic>{
//BISECT       'topic': 'realtime:$topic',
//BISECT       'event': 'access_token',
//BISECT       'payload': <String, dynamic>{'access_token': _client._accessToken},
//BISECT       'ref': ref,
//BISECT       'join_ref': _joinRef,
//BISECT     });
//BISECT   }
//BISECT 
//BISECT   void _handleReply(Map<String, dynamic> msg) {
//BISECT     if (msg['ref'] != _joinRef) return;
//BISECT     final status = (msg['payload'] as Map<String, dynamic>?)?['status'];
//BISECT     if (status == 'ok') {
//BISECT       _joinedOnce = true;
//BISECT       _status.add(DuelChannelStatus.joined);
//BISECT       _joinCompleter?.complete(true);
//BISECT     } else {
//BISECT       _status.add(DuelChannelStatus.error);
//BISECT       if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
//BISECT         _joinCompleter!.complete(false);
//BISECT       }
//BISECT     }
//BISECT   }
//BISECT 
//BISECT   void _handle(Map<String, dynamic> msg) {
//BISECT     final event = msg['event'] as String?;
//BISECT     final payload = (msg['payload'] as Map<String, dynamic>?) ?? const {};
//BISECT     if (event == 'phx_reply') return _handleReply(msg);
//BISECT     if (event == 'broadcast') {
//BISECT       _broadcasts.add(<String, dynamic>{
//BISECT         'event': payload['event'],
//BISECT         'payload': (payload['payload'] as Map<String, dynamic>?) ?? const {},
//BISECT       });
//BISECT     } else if (event == 'presence_state') {
//BISECT       _presenceJoins.add(payload);
//BISECT     } else if (event == 'presence_diff') {
//BISECT       _presenceJoins.add((payload['joins'] as Map<String, dynamic>?) ?? const {});
//BISECT       _presenceLeaves.add(
//BISECT           (payload['leaves'] as Map<String, dynamic>?) ?? const {});
//BISECT     } else if (event == 'phx_close' || event == 'phx_error') {
//BISECT       _status.add(DuelChannelStatus.closed);
//BISECT       if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
//BISECT         _joinCompleter!.complete(false);
//BISECT       }
//BISECT     }
//BISECT   }
//BISECT 
//BISECT   void _resetForRejoin() {
//BISECT     _joinedOnce = false;
//BISECT     _joinRef = null;
//BISECT     _joinCompleter = null;
//BISECT     _status.add(DuelChannelStatus.closed);
//BISECT   }
//BISECT 
//BISECT   void _dispose() {
//BISECT     _status.add(DuelChannelStatus.closed);
//BISECT     _status.close();
//BISECT     _broadcasts.close();
//BISECT     _presenceJoins.close();
//BISECT     _presenceLeaves.close();
//BISECT   }
//BISECT }
//BISECT 

/// عميل Realtime خفيف: اتصال واحد + نبض + إعادة اتصال بتراجع + قنوات.
class SupabaseRealtime {
  SupabaseRealtime({
    required this.baseUrl,
    required this.anonKey,
    this.heartbeatInterval = const Duration(seconds: 20),
    WsFactory? wsFactory, //BISECT بلا قيمة افتراضية — tear-off ربما غير ثابت هنا
  }) : _wsFactory = wsFactory ?? ioWsFactory;

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

  //BISECT final List<DuelChannel> _channels = [];
  final _socketStatus = StreamController<bool>.broadcast(); // مفتوح؟

  /// مفتوح الآن؟ (مفيد لمؤشر الاتصال بالواجهة)
  Stream<bool> get connection => _socketStatus.stream;

  String get _wireBase => baseUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');

  Future<void> updateToken(String jwt) async {
    _accessToken = jwt;
    //BISECT قنوات معطلة بهذه الجولة
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
  }

  void _onDead() {
    if (_disposed) return;
    final bool wasOpen = _socket != null; // onDone+onError قد يصلان معاً
    _heartbeat?.cancel();
    _socket = null;
    if (!wasOpen) return; // ثانية من قناة ميتة أصلاً — لا مجدولة مزدوجة
    _socketStatus.add(false);
    _tries++;
    final delay = Duration(
        seconds: (1 << (_tries - 1)).clamp(1, 16).toInt()); // clamp يعيد num
    Timer(delay, () {
      //BISECT استدعاء صريح بدل tear-off
      _open();
    });
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
    await _socket?.close();
    _socket = null;
    await _socketStatus.close();
  }
}
