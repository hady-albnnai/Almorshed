// F4.6 — عميل الدوري: تجميع أحدث أسبوع ومجموعتي + isMe + الأمان (خادم
// تجسس محلي حقيقي — ملف خالص بلا testWidgets: درس الربط الاختباري 400).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/anonymous_auth.dart';
import 'package:fizya_clash/core/supabase/league_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';

class _Spy {
  _Spy(this._handler);

  final Map<String, dynamic> Function(String path, String query,
          Map<String, String> headers)
      _handler;

  late final HttpServer server;
  final List<(String, String, Map<String, String>)> hits = [];

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      final headers = <String, String>{
        'authorization': req.headers.value('authorization') ?? '',
        'apikey': req.headers.value('apikey') ?? '',
      };
      final path = req.uri.path;
      final query = req.uri.query;
      hits.add((path, query, headers));
      final resp = _handler(path, query, headers);
      req.response.statusCode = (resp[':status'] as int?) ?? 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(resp[':payload'] ?? resp));
      await req.response.close();
    });
    return 'http://127.0.0.1:${server.port}';
  }

  Future<void> stop() => server.close(force: true);
}

InMemorySessionStore _cachedSession() {
  final store = InMemorySessionStore();
  final session = AuthSession(
      userId: 'u-1',
      accessToken: 'tok',
      refreshToken: 'r',
      expiresAtMs: 1790000000000 + 3600000);
  store.write(jsonEncode(session.toJson()));
  return store;
}

AnonymousAuth _auth(SupabaseTransport t) => AnonymousAuth(
    transport: t, store: _cachedSession(), nowMs: () => 1790000000000);

void main() {
  test('التجميع: أحدث أسبوع + اللوحة كلها + isMe + الترتيب محفوظ (قرار ٦٥)',
      () async {
    final spy = _Spy((path, query, headers) {
      if (path == '/rest/v1/devices') {
        expect(query.contains('pubkey_b64=eq.'), true);
        return <String, dynamic>{
          ':payload': <Map<String, dynamic>>[<String, dynamic>{'id': 'dev-9'}],
        };
      }
      expect(path, '/rest/v1/league_standings');
      expect(query.contains('order=iso_week.desc'), true);
      return <String, dynamic>{
        ':payload': <Map<String, dynamic>>[
          <String, dynamic>{'iso_week': 202637, 'group_no': 1, 'rank_no': 1,
              'device_id': 'dev-1', 'xp': 300},
          <String, dynamic>{'iso_week': 202637, 'group_no': 1, 'rank_no': 2,
              'device_id': 'dev-9', 'xp': 220},
          <String, dynamic>{'iso_week': 202637, 'group_no': 1, 'rank_no': 3,
              'device_id': 'dev-4', 'xp': 190},
          <String, dynamic>{'iso_week': 202637, 'group_no': 2, 'rank_no': 31,
              'device_id': 'dev-7', 'xp': 50},
          <String, dynamic>{'iso_week': 202636, 'group_no': 1, 'rank_no': 1,
              'device_id': 'dev-9', 'xp': 999},
        ],
      };
    });
    final base = await spy.start();
    try {
      final t = SupabaseTransport(baseUrl: base, anonKey: 'k');
      final api = LeagueApi(transport: t, auth: _auth(t));
      final v = await api.fetch('QUJD');
      expect(v.isoWeek, 202637); // الأقدم انحذف من العرض
      expect(v.groupNo, 1); // قرار ٦٥: group_no ثابت = ١ (بلا مجموعات)
      // قرار ٦٥: اللوحة كلها تُعرض — لا فلترة «مجموعتي» (الصف ٣١ يُعرض)
      expect(v.rows.length, 4);
      expect(v.myRank, 2);
      expect(v.rows[1].isMe, true);
      expect(v.rows[0].isMe, false);
      // الترويسات: Bearer + apikey بكل القراءات
      for (final h in spy.hits.map((h) => h.$3)) {
        expect(h['authorization'], 'Bearer tok');
        expect(h['apikey'], 'k');
      }
    } finally {
      await spy.stop();
    }
  });

  test('لا ترتيب بعد (قائمة فارغة) ⇒ أسبوع 0 وعرض البداية', () async {
    final spy = _Spy((path, query, headers) {
      if (path == '/rest/v1/devices') {
        return <String, dynamic>{
          ':payload': <Map<String, dynamic>>[<String, dynamic>{'id': 'd1'}],
        };
      }
      return <String, dynamic>{':payload': <dynamic>[]};
    });
    final base = await spy.start();
    try {
      final t = SupabaseTransport(baseUrl: base, anonKey: 'k');
      final api = LeagueApi(transport: t, auth: _auth(t));
      final v = await api.fetch('QUJD');
      expect(v.isEmpty, true);
      expect(v.isoWeek, 0);
    } finally {
      await spy.stop();
    }
  });

  test('جهاز غير موجود (RLS رفض) ⇒ استثناء موثق', () async {
    final spy = _Spy((path, query, headers) =>
        <String, dynamic>{':payload': <dynamic>[]});
    final base = await spy.start();
    try {
      final t = SupabaseTransport(baseUrl: base, anonKey: 'k');
      final api = LeagueApi(transport: t, auth: _auth(t));
      await expectLater(api.fetch('QUJD'), throwsA(isA<TransportException>()));
    } finally {
      await spy.stop();
    }
  });
}
