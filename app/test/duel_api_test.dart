// BISECT — هيكل أدنى بنفس الاستيرادات
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';


//BISECT ج١٢ — الكلاس وحده مضاف فوق ج٤ الأخضر
class _Spy {
  late final HttpServer server;

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    //BISECT ج١٥ — بلا listen إطلاقاً
    return 'http://127.0.0.1:${server.port}';
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  late _Spy spy;

  setUp(() async {
    spy = _Spy();
    await spy.start();
  });

  tearDown(() async => spy.stop());

  test('BISECT ج١٤ — مستخدَم فعلاً', () {
    expect(spy.server.port, greaterThan(0));
  });
}
