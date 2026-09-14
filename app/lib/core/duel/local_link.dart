// ═══════════════════════════════════════════════════════════════════════
// local_link.dart — النقلية المحلية للمبارزات (F5.4).
// رابط رسائل JSON موثوق (سطر لكل رسالة) بين جهازين بلا سيرفر — النواة
// مجردة عن الناقل: اليوم TCP (نقطة اتصال/شبكة مشتركة — قرار ٢٥، يعمل على
// أي جهاز بلا GMS)، ولاحقاً nearby_connections كطبقة فوق نفس العقد.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// رابط محلي — قناة رسائل JSON موثوقة مرتبة.
abstract class LocalLink {
  Stream<Map<String, dynamic>> get messages;
  void send(Map<String, dynamic> message);
  Future<void> close();
  bool get isClosed;
}

/// ترميز سطر: JSON بلا أسطر داخلية + فاصل سطر.
List<int> encodeLine(Map<String, dynamic> m) =>
    utf8.encode('${jsonEncode(m)}\n');

/// نقلية مبارزة محلية: المضيف يستمع ويقبل ضيفاً، والضيف يتصل بالمضيف.
abstract class LocalDuelTransport {
  /// المضيف: يستمع على منفذ ويقبل أول ضيف (يمنع التكرار).
  Future<LocalLink> awaitGuest({int port});

  /// الضيف: يتصل بعنوان المضيف.
  Future<LocalLink> joinHost({required String hostIp, required int port});

  /// إيقاف الاستماع (إلغاء قبل وصول ضيف).
  Future<void> shutdown();
}

/// رابط TCP — سطر JSON لكل رسالة (utf8 + LineSplitter).
class TcpLink implements LocalLink {
  TcpLink(this._socket) {
    utf8.decoder.bind(_socket).transform(const LineSplitter()).listen(
          _onLine,
          onDone: () => _closed = true,
          onError: (_) => _closed = true,
          cancelOnError: true,
        );
  }

  final Socket _socket;
  final StreamController<Map<String, dynamic>> _ctrl =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _closed = false;

  void _onLine(String line) {
    if (_closed) return;
    final text = line.trim();
    if (text.isEmpty) return;
    try {
      final m = jsonDecode(text) as Map<String, dynamic>;
      if (!_ctrl.isClosed) _ctrl.add(m);
    } catch (_) {
      // سطر تالف — نتجاهله (الرابط موثوق النقل لا المحتوى)
    }
  }

  @override
  Stream<Map<String, dynamic>> get messages => _ctrl.stream;

  @override
  bool get isClosed => _closed;

  @override
  void send(Map<String, dynamic> m) {
    if (_closed) return;
    try {
      _socket.add(encodeLine(m));
    } catch (_) {
      // المقبس ميت — لا شيء
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    if (!_ctrl.isClosed) await _ctrl.close();
    _socket.destroy();
  }
}

/// عنوان المضيف المرجّح في نقطة الاتصال/الشبكة المشتركة — أفضل مجهود:
/// يبحث في واجهات الشبكة عن عناوين نقطة الاتصال المعروفة (Android عادةً
/// 192.168.43.1) ثم أي عنوان خاص غير حلقي. يعود null عند التعذر.
Future<String?> detectHostIp() async {
  try {
    const hotspots = [
      '192.168.43.',
      '192.168.49.',
      '192.168.137.',
      '172.20.10.',
      '10.42.0.',
    ];
    String? anyPrivate;
    final ifaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (hotspots.any(ip.startsWith)) return ip;
        if (_isPrivateIpv4(ip)) anyPrivate ??= ip;
      }
    }
    return anyPrivate;
  } catch (_) {
    return null;
  }
}

bool _isPrivateIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final o1 = int.tryParse(parts[0]);
  final o2 = int.tryParse(parts[1]);
  if (o1 == null || o2 == null) return false;
  return o1 == 10 ||
      (o1 == 172 && o2 >= 16 && o2 <= 31) ||
      (o1 == 192 && o2 == 168);
}

/// نقلية TCP — المضيف يستمع على كل الواجهات (نقطة الاتصال/الشبكة المشتركة).
class TcpDuelTransport implements LocalDuelTransport {
  static const int defaultPort = 4118;

  ServerSocket? _server;
  int? _boundPort;

  /// المنفذ الفعلي بعد الاستماع (مفيد عند port=0 بالاختبارات).
  int? get boundPort => _boundPort;

  @override
  Future<LocalLink> awaitGuest({int port = defaultPort}) async {
    final server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: false);
    _server = server;
    _boundPort = server.port;
    final socket = await server.first; // أول ضيف حصراً
    await server.close();
    _server = null;
    return TcpLink(socket);
  }

  @override
  Future<LocalLink> joinHost({
    required String hostIp,
    int port = defaultPort,
  }) async {
    final socket = await Socket.connect(hostIp, port);
    return TcpLink(socket);
  }

  @override
  Future<void> shutdown() async {
    await _server?.close();
    _server = null;
  }
}
