// ج٤٠ب — أدنى ملف نظيف: كل استيراد ورمز مستخدم
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _Hit {
  _Hit(this.method, this.path, this.query, this.headers, this.body);
  final String method;
  final String path;
  final String query;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}

class _Spy {
  _Spy(this._handler);

  final Map<String, dynamic> Function(
          String method, String path, String query, Map<String, dynamic> body)
      _handler;

  late final HttpServer server;
  final List<_Hit> hits = <_Hit>[];

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      Map<String, dynamic> body = const {};
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) body = d;
      } catch (_) {}
      hits.add(_Hit(req.method, req.uri.path, req.uri.query, <String, String>{
        'authorization': req.headers.value('authorization') ?? '',
        'apikey': req.headers.value('apikey') ?? '',
        'prefer': req.headers.value('prefer') ?? '',
      }, body));
      final resp = _handler(req.method, req.uri.path, req.uri.query, body);
      req.response.statusCode = (resp[':status'] as int?) ?? 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(resp[':payload'] ?? resp));
      await req.response.close();
    });
    return 'http://127.0.0.1:${server.port}';
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  test('ج٤٠ب — نظيف تماماً', () async {
    final spy = _Spy((m, p, q, b) => const <String, dynamic>{});
    final base = await spy.start();
    expect(base, isNotEmpty);
    expect(spy.hits, isEmpty);
    await spy.stop();
  });
}
