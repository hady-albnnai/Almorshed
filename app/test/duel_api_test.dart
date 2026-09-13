// BISECT ج٨ — البنية المجرّدة حصراً
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

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      final body = <String, dynamic>{};
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) body.addAll(d);
      } catch (_) {}
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
  late _Spy spy;
  late SupabaseTransport transport;
  late DuelApi api;
  const anon = 'test-anon';

  setUp(() async {
    spy = _Spy((method, path, query, body) => const <String, dynamic>{});
    final base = await spy.start();
    transport = SupabaseTransport(baseUrl: base, anonKey: anon);
    api = DuelApi(transport);
  });

  tearDown(() async => spy.stop());

  test('BISECT test1 مجرّد', () async {
    spy._handler = (m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[<String, dynamic>{'id': 'dev-1'}],
        };
    final id = await api.myDeviceId(accessToken: 'tok', pubkeyB64: 'PK9=');
    expect(id, 'dev-1');
  });
}
