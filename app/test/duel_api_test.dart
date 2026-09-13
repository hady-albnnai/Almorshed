// M5 — DuelApi: تجسس HTTP محلي حقيقي (ملف خالص بلا testWidgets) —
// الترويسات (bearer+apikey بمفتاح النقلية)، الأجسام، وبثّ DuelRow/Verdict.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';

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
  Map<String, dynamic> Function(
          String method, String path, String query, Map<String, dynamic> body)
      _handler;
  late final HttpServer server;
  final List<_Hit> hits = [];

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      final body = <String, dynamic>{};
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) body.addAll(d);
      } catch (_) {}
      hits.add(_Hit(req.method, req.uri.path, req.uri.query, {
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
  late _Spy spy;
  late SupabaseTransport transport;
  late DuelApi api;
  const anon =
      'eyJhbGciOiJIUzI1NiJ9.eyJyZWYiOiJ0ZXN0In0.kk';
  const uuidHost = '11111111-1111-1111-1111-111111111111';
  const uuidGuest = '22222222-2222-2222-2222-222222222222';
  const duelUuid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  setUp(() async {
    spy = _Spy((method, path, query, body) => const <String, dynamic>{});
    final base = await spy.start();
    transport = SupabaseTransport(baseUrl: base, anonKey: anon);
    api = DuelApi(transport);
  });

  tearDown(() async => spy.stop());

  test('myDeviceId: قراءة RLS بمفتاحي النقلية — uuid مستخرج', () async {
    spy._handler = (m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[<String, dynamic>{'id': uuidHost}],
        };
    final id = await api.myDeviceId(accessToken: 'tok', pubkeyB64: 'PK9=');
    expect(id, uuidHost);
    final h = spy.hits.single;
    expect(h.path, '/rest/v1/devices');
    expect(h.query.contains('pubkey_b64=eq.PK9%3D') ||
        h.query.contains('pubkey_b64=eq.PK9='), isTrue);
    expect(h.headers['authorization'], 'Bearer tok');
    expect(h.headers['apikey'], anon); // مفتاح النقلية لا الثابت — درس الدوري
  });
}
