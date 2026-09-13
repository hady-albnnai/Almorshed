// M5 — اختبارات عميل Realtime الأدنى (F5.2) — بروتوكول Phoenix vsn=1.0.0.
// خادم WS مزيف محلي (dart:io حصراً — بلا testWidgets ولا شبكة خارجية):
// يتحقق من مظروف الانضمام/الرد، البث الوارد والصادر، والنبض الدوري.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/realtime_client.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  final received = <Map<String, dynamic>>[];
  // مخزّن أحادي (البثّ الأساسي يفقد الأحداث بلا مستمع لحظتها)
  final joinReplies = StreamController<WebSocket>();

  Future<void> pumpEventLoop() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() async {
    received.clear();
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      ws.stream.listen((raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        received.add(msg);
        if (msg['event'] == 'phx_join') {
          ws.add(jsonEncode(<String, dynamic>{
            'topic': msg['topic'],
            'event': 'phx_reply',
            'payload': <String, dynamic>{'status': 'ok'},
            'ref': msg['ref'],
          }));
          joinReplies.add(ws);
        }
      });
    });
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
    await joinReplies.close();
  });

  test('الانضمام: مظروف صحيح + phx_reply ok ⇒ join() يكتمل true', () async {
    final rt = SupabaseRealtime(
      baseUrl: baseUri.toString(),
      anonKey: 'test-anon',
      heartbeatInterval: const Duration(seconds: 30),
    );
    await rt.connect(accessToken: 'jwt-1');
    final ch = rt.channel('duel:abc', presenceKey: 'dev-1');
    final ok = await ch.join();
    expect(ok, isTrue);

    final join = received.firstWhere((m) => m['event'] == 'phx_join');
    expect(join['topic'], 'realtime:duel:abc');
    expect(join['join_ref'], join['ref']);
    final payload = join['payload'] as Map<String, dynamic>;
    expect((payload['config'] as Map)['broadcast'],
        <String, dynamic>{'ack': false, 'self': false});
    expect((payload['access_token'] as String), 'jwt-1');
    await rt.close();
  });

  test('البث الوارد: إطار broadcast من الخادم ⇒ يصل مستمع القناة', () async {
    final rt = SupabaseRealtime(
      baseUrl: baseUri.toString(),
      anonKey: 'test-anon',
      heartbeatInterval: const Duration(seconds: 30),
    );
    await rt.connect(accessToken: 'jwt-1');
    final ch = rt.channel('duel:abc');
    final got = <Map<String, dynamic>>[];
    ch.broadcasts.listen(got.add);
    final ws = await ch.join().then((_) => joinReplies.first);
    await pumpEventLoop();
    ws.add(jsonEncode(<String, dynamic>{
      'topic': 'realtime:duel:abc',
      'event': 'broadcast',
      'payload': <String, dynamic>{
        'type': 'broadcast',
        'event': 'ans',
        'payload': <String, dynamic>{'i': 3, 'c': 1, 'by': 'dev-2'},
      },
      'ref': 'srv-1',
    }));
    await pumpEventLoop();
    expect(got.single['event'], 'ans');
    expect((got.single['payload'] as Map)['i'], 3);
    await rt.close();
  });

  test('البث الصادر: sendBroadcast بمظروف type/event/payload وjoin_ref',
      () async {
    final rt = SupabaseRealtime(
      baseUrl: baseUri.toString(),
      anonKey: 'test-anon',
      heartbeatInterval: const Duration(seconds: 30),
    );
    await rt.connect(accessToken: 'jwt-1');
    final ch = rt.channel('duel:abc');
    await ch.join();
    await pumpEventLoop();
    final sent = ch.sendBroadcast('start', <String, dynamic>{'t': 123});
    expect(sent, isTrue);
    await pumpEventLoop();
    final b = received
        .firstWhere((m) => m['event'] == 'broadcast' && m['topic'] == 'realtime:duel:abc');
    expect((b['payload'] as Map)['type'], 'broadcast');
    expect(((b['payload'] as Map)['event'] as String), 'start');
    expect((b['payload'] as Map)['payload'], <String, dynamic>{'t': 123});
    await rt.close();
  });

  test('النبض: topic phoenix دورياً حسب الفاصل المعطى', () async {
    final rt = SupabaseRealtime(
      baseUrl: baseUri.toString(),
      anonKey: 'test-anon',
      heartbeatInterval: const Duration(milliseconds: 60),
    );
    await rt.connect(accessToken: 'jwt-1');
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final beats = received.where(
        (m) => m['topic'] == 'phoenix' && m['event'] == 'heartbeat').length;
    expect(beats, greaterThanOrEqualTo(2));
    await rt.close();
  });

  test('بعد الإغلاق: الإرسال يفشل بهدوء ولا إعادة اتصال', () async {
    final rt = SupabaseRealtime(
      baseUrl: baseUri.toString(),
      anonKey: 'test-anon',
      heartbeatInterval: const Duration(seconds: 30),
    );
    await rt.connect(accessToken: 'jwt-1');
    final ch = rt.channel('duel:abc');
    await ch.join();
    await rt.close();
    expect(ch.sendBroadcast('x', const {}), isFalse);
    final before = received.length;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(received.length, before); // لا نشاط بعد الإغلاق
  });
}
