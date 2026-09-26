// app/test/gen_golden_test.dart
//
// الفحص الذهبيّ لمحرّك التوليد على الجهاز (core/gen/problem_engine.dart).
//
// لكل توليفة قيم في test/fixtures/gen_golden.json — المولّدة من مولّد بايثون
// المتحقَّق (tools/gen_items.py · 69/69 · 22138/22138) عبر tools/gen_golden.py —
// يجب أن يُنتج المحرّك المخرَج الحتميّ نفسه بالضبط (أو يرفض التوليفة نفسها).
// الترتيب العشوائيّ للخيارات مُستثنى بمقارنة الخيارات كمجموعة مرتّبة.
//
// التشغيل:  cd app && flutter test test/gen_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:fizya_clash/core/gen/problem_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asset = jsonDecode(File('assets/content/templates.json').readAsStringSync())
      as Map<String, dynamic>;
  final gold = jsonDecode(File('test/fixtures/gen_golden.json').readAsStringSync())
      as Map<String, dynamic>;
  final engine = ProblemEngine(asset);
  final fixtures = (gold['fixtures'] as List).cast<Map<String, dynamic>>();

  test('محرّك Dart يطابق المولّد المتحقَّق على ${fixtures.length} تجهيزة ذهبية', () {
    var okCount = 0;
    final errors = <String>[];
    for (final fx in fixtures) {
      final tid = fx['templateId'] as String;
      final t = engine.templates[tid]!;
      final base = Map<String, Object?>.from(fx['vars'] as Map);
      final got = engine.fromParts(t, base);
      final reject = fx['reject'] == true;

      if (reject) {
        if (got == null) {
          okCount++;
        } else {
          errors.add('$tid $base: توقّعت رفضاً فأنتج');
        }
        continue;
      }
      if (got == null) {
        errors.add('$tid $base: توقّعت إنتاجاً فرفض');
        continue;
      }
      final diff = _deepEq(_canon(got), fx['item'], '');
      if (diff == null) {
        okCount++;
      } else {
        errors.add('$tid $base: $diff');
      }
    }
    if (errors.isNotEmpty) {
      final sample = errors.take(20).join('\n  ');
      fail('اختلافات ${errors.length}/${fixtures.length}:\n  $sample');
    }
    expect(okCount, fixtures.length);
  });
}

Map<String, Object?> _canon(Map<String, Object?> item) {
  final parts = (item['parts'] as List).cast<Map<String, Object?>>();
  return {
    'stem': item['stem'],
    'weight': item['weight'],
    'parts': [
      for (final p in parts)
        {
          'label': p['label'],
          'prompt': p['prompt'],
          'weight': p['weight'],
          'answerText': p['answerText'],
          'answerValue': p['answerValue'],
          'answerUnit': p['answerUnit'],
          'unitRequired': p['unitRequired'],
          'rubric': [
            for (final r in (p['rubric'] as List).cast<Map<String, Object?>>())
              {'step': r['step'], 'kind': r['kind'], 'points': r['points']}
          ],
          'optionSet': () {
            final opts = (p['options'] as List).cast<String>();
            if (opts.isEmpty) return const <String>[];
            final s = [...opts]..sort();
            return s;
          }(),
          'correctText':
              (p['options'] as List).isEmpty ? null : p['answerText'],
        }
    ],
    'followThrough': item['followThrough'],
  };
}

/// مقارنة عميقة: قوائم مرتّبة، خرائط بلا ترتيب، أعداد بسماحية.
String? _deepEq(Object? a, Object? b, String path) {
  if (a is Map && b is Map) {
    final ak = a.keys.map((e) => e.toString()).toSet();
    final bk = b.keys.map((e) => e.toString()).toSet();
    if (ak.length != bk.length || !ak.containsAll(bk)) {
      return '$path: مفاتيح مختلفة ${ak.difference(bk)}|${bk.difference(ak)}';
    }
    for (final k in a.keys) {
      final r = _deepEq(a[k], b[k as String], '$path.$k');
      if (r != null) return r;
    }
    return null;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$path: أطوال ${a.length}≠${b.length}';
    for (var i = 0; i < a.length; i++) {
      final r = _deepEq(a[i], b[i], '$path[$i]');
      if (r != null) return r;
    }
    return null;
  }
  if (a is num && b is num) {
    if ((a - b).abs() <= 1e-9 * (1 + a.abs().clamp(0, double.infinity) + b.abs())) {
      return null;
    }
    return '$path: $a ≠ $b';
  }
  if (a == b) return null;
  return '$path: ${_show(a)} ≠ ${_show(b)}';
}

String _show(Object? v) => v == null ? 'null' : '"$v"';
