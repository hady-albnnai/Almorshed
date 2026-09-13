// M5 — DuelApi: تجسس HTTP محلي حقيقي (ملف خالص بلا testWidgets) —
// الترويسات (bearer+apikey بمفتاح النقلية)، الأجسام، وبثّ DuelRow/Verdict.
// نمط الإنشاء: كل اختبار ينشئ تجسسه الخاص بحقل معالج نهائي — لا إسناد لاحق
// (درس جولة M5: حقل غير نهائي يوقظ prefer_final_fields، ونهائي مع إسناد
// لاحق يكسر التصريف — الحل الأنظف: إنشاء لكل اختبار).
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

const String _anon =
    'eyJhbGciOiJIUzI1NiJ9.eyJyZWYiOiJ0ZXN0In0.kk';
const String _uuidHost = '11111111-1111-1111-1111-111111111111';
const String _uuidGuest = '22222222-2222-2222-2222-222222222222';
const String _duelUuid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

typedef _Handler = Map<String, dynamic> Function(String method, String path,
    String query, Map<String, dynamic> body);

/// تجسس + نقلية + عميل جاهزة لاختبار واحد.
Future<(_Spy, DuelApi)> _make(_Handler handler) async {
  final spy = _Spy(handler);
  final base = await spy.start();
  final transport = SupabaseTransport(baseUrl: base, anonKey: _anon);
  return (spy, DuelApi(transport));
}

void main() {
  test('ج٣٧ — _make وtypedef فقط', () async {
    final (spy, api) = await _make((m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[<String, dynamic>{'id': _uuidHost}],
        });
    expect(spy, isNotNull);
    expect(api, isNotNull);
    expect(_anon, isNotEmpty);
    expect(_uuidGuest, isNotEmpty);
    expect(_duelUuid, isNotEmpty);
    await spy.stop();
  });
}
