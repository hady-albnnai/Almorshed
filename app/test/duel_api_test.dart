// BISECT — هيكل أدنى بنفس الاستيرادات
// ignore_for_file: unused_element
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';


class _Spy {
  _Spy(this._handler);
  Map<String, dynamic> Function(
          String method, String path, String query, Map<String, dynamic> body)
      _handler;
  late final HttpServer server;
  final List<String> paths = <String>[];

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      Map<String, dynamic> body = const {};
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) body = d;
      } catch (_) {}
      paths.add(req.uri.path);
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
  test('E2d — _Spy مستخدمة بلا أي unused', () {
    final spy = _Spy((method, path, query, body) => <String, dynamic>{});
    expect(spy.paths, isEmpty);
    expect(SupabaseTransport, isNotNull);
    expect(jsonEncode(<String, int>{'a': 1}), '{"a":1}');
    expect(HttpServer, isNotNull);
    expect(DuelApi, isNotNull);
  });
}
