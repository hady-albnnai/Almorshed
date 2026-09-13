// M5 — DuelApi: تجسس HTTP محلي حقيقي (ملف خالص بلا testWidgets) —
// ignore_for_file: type=lint
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

  test('createDuel: POST بالبذرة والنطاق — وDuelRow مبنية', () async {
    spy._handler = (m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[
            <String, dynamic>{
              'id': duelUuid,
              'room_code': 'K7M2P-9QW4X',
              'seed': 3211743424056914077,
              'status': 'lobby',
              'scope': <String, dynamic>{'units': <String>['U1'], 'count': 10,
                  'mode': 'quiz', 'pack': 'test-pack-1'},
              'host_device': uuidHost,
              'guest_device': null,
              'host_name': 'أحمد',
              'guest_name': null,
              'host_score': null,
              'guest_score': null,
              'winner_device': null,
            },
          ],
        };
    final row = await api.createDuel(
      accessToken: 'tok',
      roomCode: 'K7M2P-9QW4X',
      seed: 3211743424056914077,
      scopeJson: <String, dynamic>{'units': <String>['U1'], 'count': 10,
          'mode': 'quiz', 'pack': 'test-pack-1'},
      hostDevice: uuidHost,
      hostName: 'أحمد',
    );
    expect(row.id, duelUuid);
    expect(row.seed, 3211743424056914077); // البذرة كاملة لا مقطوعة
    expect(row.status, 'lobby');
    final hit = spy.hits.single;
    expect(hit.method, 'POST');
    expect(hit.body['seed'], 3211743424056914077);
    expect(hit.body['host_device'], uuidHost);
    expect(hit.headers['prefer'], contains('representation'));
  });

  test('جلوس الضيف وبدء المضيف: PATCH بالأجسام الصحيحة', () async {
    spy._handler = (m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[
            <String, dynamic>{
              'id': duelUuid, 'room_code': 'K7M2P-9QW4X', 'seed': 7,
              'status': m == 'PATCH' && b['status'] != null ? 'live' : 'lobby',
              'scope': <String, dynamic>{},
              'host_device': uuidHost, 'guest_device': uuidGuest,
              'host_name': 'أحمد', 'guest_name': 'سارة',
              'host_score': null, 'guest_score': null, 'winner_device': null,
            },
          ],
        };
    final joined = await api.joinAsGuest(
        accessToken: 'tok', duelId: duelUuid, guestDevice: uuidGuest,
        guestName: 'سارة');
    expect(joined.guestName, 'سارة');
    final startHit = spy.hits.last;
    await api.startDuel(accessToken: 'tok', duelId: duelUuid);
    final h2 = spy.hits.last;
    expect(h2.method, 'PATCH');
    expect(h2.body['status'], 'live');
    expect((h2.body['started_at'] as String), isNotEmpty);
    expect(startHit.query.contains('id=eq.$duelUuid'), isTrue);
  });

  test('الإجابات وإعلان الإتمام: POST بreturn=minimal', () async {
    spy._handler = (m, p, q, b) => <String, dynamic>{':payload': const []};
    await api.insertAnswer(
        accessToken: 'tok', duelId: duelUuid, deviceId: uuidHost,
        qIndex: 3, chosen: 1);
    await api.markDone(
        accessToken: 'tok', duelId: duelUuid, deviceId: uuidHost);
    final a = spy.hits[0];
    expect(a.body, <String, dynamic>{'duel_id': duelUuid,
        'device_id': uuidHost, 'q_index': 3, 'chosen': 1});
    expect(a.headers['prefer'], 'return=minimal');
    final d = spy.hits[1];
    expect(d.path, '/rest/v1/duel_status');
  });

  test('duel_finish: النتيجة تُبثّ Verdict — والرفض 422 يرمي بالسبب', () async {
    spy._handler = (m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>{
            'ok': true, 'already': false, 'duel_id': duelUuid,
            'host_score': 2300, 'guest_score': 300, 'winner_device': uuidHost,
            'tie_break': 'score',
            'corrects': <int>[1, 1, 3, 1, 0, 1, 1, 1, 3, 0],
            'my_device': uuidHost,
          },
        };
    final v = await api.finish(
        accessToken: 'tok', duelId: duelUuid, myDevice: uuidHost);
    expect(v.hostScore, 2300);
    expect(v.guestScore, 300);
    expect(v.winnerDevice, uuidHost);
    expect(v.corrects.length, 10);
    expect(spy.hits.single.path, '/functions/v1/duel_finish');

    spy._handler = (m, p, q, b) => <String, dynamic>{
          ':status': 422,
          ':payload': <String, dynamic>{'ok': false, 'reason': 'BAD_ANSWER'},
        };
    await expectLater(
      api.finish(accessToken: 'tok', duelId: duelUuid, myDevice: uuidHost),
      throwsA(isA<TransportException>()
          .having((e) => e.message, 'message', 'BAD_ANSWER')),
    );
  });
}
