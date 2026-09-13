// BISECT ج٨ — البنية المجرّدة حصراً
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';

class _Spy {
  //BISECT بلا حقل دالة مكتوب
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
      req.response.statusCode = 200; //BISECT رد ثابت
      req.response.headers.contentType = ContentType.json;
      req.response.write('{}');
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
    spy = _Spy();
    final base = await spy.start();
    transport = SupabaseTransport(baseUrl: base, anonKey: anon);
    api = DuelApi(transport);
  });

  tearDown(() async => spy.stop());

  test('BISECT test1 مجرّد', () async {
    final id = 'dev-1'; //BISECT بلا نداء حقيقي
    expect(id, 'dev-1');
  });
}
