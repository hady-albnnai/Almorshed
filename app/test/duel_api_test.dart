// BISECT — هيكل أدنى بنفس الاستيرادات
// ignore_for_file: type=lint
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/duel_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';

void main() {
  test('BISECT تافه', () {
    expect(SupabaseTransport, isNotNull);
    expect(jsonEncode(<String, int>{'a': 1}), '{"a":1}');
    expect(HttpServer, isNotNull);
    expect(DuelApi, isNotNull);
  });
}
