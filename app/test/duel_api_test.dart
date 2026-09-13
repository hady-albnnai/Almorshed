// BISECT ج١١ — بلا أي try/catch
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';

class _Spy {
  late final HttpServer server;

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      Map<String, dynamic> body = const <String, dynamic>{};
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) body = decoded;
      }
      req.response.statusCode = 200;
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
  const anon = 'test-anon';

  setUp(() async {
    spy = _Spy();
    await spy.start();
  });

  tearDown(() async => spy.stop());

  test('BISECT ج١١', () async {
    final transport = SupabaseTransport(
        baseUrl: 'http://127.0.0.1:${spy.server.port}', anonKey: anon);
    final api = DuelApi(transport);
    expect(api, isNotNull);
  });
}
