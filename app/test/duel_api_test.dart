// BISECT ج٢٢ — ج٤ الأخضر + _Hit مستخدَمة
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

void main() {
  test('BISECT ج٢٢', () {
    expect(SupabaseTransport, isNotNull);
    expect(jsonEncode(<String, int>{'a': 1}), '{"a":1}');
    expect(HttpServer, isNotNull);
    expect(DuelApi, isNotNull);
    final h = _Hit('POST', '/x', 'q=1', <String, String>{'k': 'v'},
        <String, dynamic>{'n': 1});
    expect(h.method, 'POST');
    expect(h.headers['k'], 'v');
    expect(h.body['n'], 1);
  });
}
