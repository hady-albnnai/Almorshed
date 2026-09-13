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
  test('myDeviceId: قراءة RLS بمفتاحي النقلية — uuid مستخرج', () async {
    final (spy, api) = await _make((m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[<String, dynamic>{'id': _uuidHost}],
        });
    final id = await api.myDeviceId(accessToken: 'tok', pubkeyB64: 'PK9=');
    expect(id, _uuidHost);
    final h = spy.hits.single;
    expect(h.path, '/rest/v1/devices');
    expect(h.query.contains('pubkey_b64=eq.PK9%3D') ||
        h.query.contains('pubkey_b64=eq.PK9='), isTrue);
    expect(h.headers['authorization'], 'Bearer tok');
    expect(h.headers['apikey'], _anon); // مفتاح النقلية لا الثابت — درس الدوري
    await spy.stop();
  });

  test('createDuel: POST بالبذرة والنطاق — وDuelRow مبنية', () async {
    final (spy, api) = await _make((m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[
            <String, dynamic>{
              'id': _duelUuid,
              'room_code': 'K7M2P-9QW4X',
              'seed': 3211743424056914077,
              'status': 'lobby',
              'scope': <String, dynamic>{'units': <String>['U1'], 'count': 10,
                  'mode': 'quiz', 'pack': 'test-pack-1'},
              'host_device': _uuidHost,
              'guest_device': null,
              'host_name': 'أحمد',
              'guest_name': null,
              'host_score': null,
              'guest_score': null,
              'winner_device': null,
            },
          ],
        });
    final row = await api.createDuel(
      accessToken: 'tok',
      roomCode: 'K7M2P-9QW4X',
      seed: 3211743424056914077,
      scopeJson: <String, dynamic>{'units': <String>['U1'], 'count': 10,
          'mode': 'quiz', 'pack': 'test-pack-1'},
      hostDevice: _uuidHost,
      hostName: 'أحمد',
    );
    expect(row.id, _duelUuid);
    expect(row.seed, 3211743424056914077); // البذرة كاملة لا مقطوعة
    expect(row.status, 'lobby');
    final hit = spy.hits.single;
    expect(hit.method, 'POST');
    expect(hit.body['seed'], 3211743424056914077);
    expect(hit.body['host_device'], _uuidHost);
    expect(hit.headers['prefer'], contains('representation'));
    await spy.stop();
  });

  test('جلوس الضيف وبدء المضيف: PATCH بالأجسام الصحيحة', () async {
    final (spy, api) = await _make((m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>[
            <String, dynamic>{
              'id': _duelUuid, 'room_code': 'K7M2P-9QW4X', 'seed': 7,
              'status': m == 'PATCH' && b['status'] != null ? 'live' : 'lobby',
              'scope': <String, dynamic>{},
              'host_device': _uuidHost, 'guest_device': _uuidGuest,
              'host_name': 'أحمد', 'guest_name': 'سارة',
              'host_score': null, 'guest_score': null, 'winner_device': null,
            },
          ],
        });
    final joined = await api.joinAsGuest(
        accessToken: 'tok', duelId: _duelUuid, guestDevice: _uuidGuest,
        guestName: 'سارة');
    expect(joined.guestName, 'سارة');
    final startHit = spy.hits.last;
    await api.startDuel(accessToken: 'tok', duelId: _duelUuid);
    final h2 = spy.hits.last;
    expect(h2.method, 'PATCH');
    expect(h2.body['status'], 'live');
    expect((h2.body['started_at'] as String), isNotEmpty);
    expect(startHit.query.contains('id=eq.$_duelUuid'), isTrue);
    await spy.stop();
  });

  test('الإجابات وإعلان الإتمام: POST بreturn=minimal', () async {
    final (spy, api) =
        await _make((m, p, q, b) => <String, dynamic>{':payload': const []});
    await api.insertAnswer(
        accessToken: 'tok', duelId: _duelUuid, deviceId: _uuidHost,
        qIndex: 3, chosen: 1);
    await api.markDone(
        accessToken: 'tok', duelId: _duelUuid, deviceId: _uuidHost);
    final a = spy.hits[0];
    expect(a.body, <String, dynamic>{'duel_id': _duelUuid,
        'device_id': _uuidHost, 'q_index': 3, 'chosen': 1});
    expect(a.headers['prefer'], 'return=minimal');
    final d = spy.hits[1];
    expect(d.path, '/rest/v1/duel_status');
    await spy.stop();
  });

  test('duel_finish: النتيجة تُبثّ Verdict — والرفض 422 يرمي بالسبب', () async {
    final (spy, api) = await _make((m, p, q, b) => <String, dynamic>{
          ':payload': <String, dynamic>{
            'ok': true, 'already': false, 'duel_id': _duelUuid,
            'host_score': 2300, 'guest_score': 300, 'winner_device': _uuidHost,
            'tie_break': 'score',
            'corrects': <int>[1, 1, 3, 1, 0, 1, 1, 1, 3, 0],
            'my_device': _uuidHost,
          },
        });
    final v = await api.finish(
        accessToken: 'tok', duelId: _duelUuid, myDevice: _uuidHost);
    expect(v.hostScore, 2300);
    expect(v.guestScore, 300);
    expect(v.winnerDevice, _uuidHost);
    expect(v.corrects.length, 10);
    expect(spy.hits.single.path, '/functions/v1/duel_finish');
    await spy.stop();

    final (spy2, api2) = await _make((m, p, q, b) => <String, dynamic>{
          ':status': 422,
          ':payload': <String, dynamic>{'ok': false, 'reason': 'BAD_ANSWER'},
        });
    await expectLater(
      api2.finish(accessToken: 'tok', duelId: _duelUuid, myDevice: _uuidHost),
      throwsA(isA<TransportException>()
          .having((e) => e.message, 'message', 'BAD_ANSWER')),
    );
    await spy2.stop();
  });
}
