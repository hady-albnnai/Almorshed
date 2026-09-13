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
    server.listen((req) async {
      await utf8.decoder.bind(req).join(); //BISECT بلا decode
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
  test('BISECT تافه', () {
    expect(SupabaseTransport, isNotNull);
    expect(jsonEncode(<String, int>{'a': 1}), '{"a":1}');
    expect(HttpServer, isNotNull);
    expect(DuelApi, isNotNull);
  });
}
