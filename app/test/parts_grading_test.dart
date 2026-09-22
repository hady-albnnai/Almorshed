// F-GEN3 — تصحيح «المسألة بأجزاء» بالسلم الوزاري سطرًا سطرًا (قرار ٦٨).
// المادة ١١-ب: العلاقة ٥ · التعويض ٣ · النتيجة ١ · الوحدة ١، ومفاتيح مضادة
// تُصفِّر السطر، ومتابعة الخطأ (FT) تُكافئ من مشى صحيحاً على خطئه.
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/generated_items.dart';
import 'package:fizya_clash/core/grading/parts_grading.dart';

import 'fixtures/parts_item.dart';

void main() {
  final item = GeneratedItem.fromJson(partsSampleItem());

  double lineOf(PartScore s, String kind) =>
      s.lines.firstWhere((l) => l.kind == kind).points;

  String? noteOf(PartScore s, String kind) =>
      s.lines.firstWhere((l) => l.kind == kind).note;

  group('النموذج', () {
    test('parts-v1 يُقرأ: وزنان متطابقان ومتابعة خطأ ملصقة بالجزء', () {
      expect(item.isParts, isTrue);
      expect(item.grading, partsGradingKey);
      expect(item.parts, hasLength(2));
      expect(item.weight, item.partsWeight); // ٢٠ = ١٠ + ١٠ — قرار ٦٨
      expect(item.parts.first.hasOptions, isTrue);
      expect(item.parts.first.options, hasLength(4));
      expect(item.parts.last.follow, hasLength(1));
      expect(item.parts.last.follow.single.dependsOn, '١');
      expect(item.parts.last.follow.single.power, -1.0);
      expect(item.parts.last.follow.single.scale, 60.0);
      expect(item.options, isEmpty); // لا مفتاح مسطّح لبنود الأجزاء
    });

    test('بند مسطّح: isParts كاذب وأجزاؤه فارغة', () {
      final flat = GeneratedItem.fromJson(<String, dynamic>{
        'id': 1,
        'templateId': 'T.FLAT',
        'chapter': 'U1C1',
        'type': 'mcq',
        'stem': 'س',
        'options': ['أ', 'ب', 'ج', 'د'],
        'correctIndex': 0,
        'weight': 10,
        'approved': false,
      });
      expect(flat.isParts, isFalse);
      expect(flat.parts, isEmpty);
      expect(flat.partsWeight, 0);
    });
  });

  group('السلم سطرًا سطرًا', () {
    test('لا إجابة ⇒ صفر مع سبب مكتوب لكل سطر مهمل', () {
      final g = gradeParts(item, const {});
      expect(g.maxPoints, 20);
      expect(g.points, 0);
      expect(g.correct, isFalse);
      expect(noteOf(g.parts.first, 'relation'), contains('لم تُكتب العلاقة'));
      expect(noteOf(g.parts.first, 'result'), contains('لم تُكتب النتيجة'));
      expect(noteOf(g.parts.first, 'unit'), contains('بلا نتيجة صحيحة'));
      // ملاحظات مسلسلة بوسم الجزء ليعرف الطالب أين ينظر
      expect(g.notes.first, startsWith('الجزء ١'));
      expect(g.notes, hasLength(8));
      expect(g.toGrade().maxPoints, 20);
    });

    test('إجابة كاملة ⇒ وزن البند كله وبلا ملاحظات خصم', () {
      final g = gradeParts(item, {
        '١': (
          relation: fullRelation1,
          substitution: fullSubst1,
          result: fullResult1,
          chosen: null,
        ),
        '٢': (
          relation: fullRelation2,
          substitution: fullSubst2,
          result: fullResult2,
          chosen: null,
        ),
      });
      expect(g.points, 20);
      expect(g.maxPoints, 20);
      expect(g.correct, isTrue);
      expect(g.notes, isEmpty);
      for (final s in g.parts) {
        expect(s.followThrough, isFalse);
        expect(lineOf(s, 'relation'), 5);
        expect(lineOf(s, 'substitution'), 3);
        expect(lineOf(s, 'result'), 1);
        expect(lineOf(s, 'unit'), 1);
      }
    });

    test('مفتاح مضاد في العلاقة ⇒ صفر السطر مع «صيغة مغلوضة»', () {
      final g = gradeParts(item, {
        '١': (
          relation: 'Z = R + X = 140',
          substitution: fullSubst1,
          result: fullResult1,
          chosen: null,
        ),
      });
      expect(lineOf(g.parts.first, 'relation'), 0);
      expect(noteOf(g.parts.first, 'relation'), contains('مغلوضة'));
      // بقية الأسطر لا تتأثر: العلاقة وحدها ما سقط (٣ + ١ + ١)
      expect(lineOf(g.parts.first, 'result'), 1);
      expect(lineOf(g.parts.first, 'unit'), 1);
      expect(g.points, 5);
    });

    test('بعض أرقام التعويض ⇒ نصف السطر (١٫٥ من ٣)', () {
      final g = gradeParts(item, {
        '١': (
          relation: fullRelation1,
          substitution: 'Z = √(60² + …)',
          result: '',
          chosen: null,
        ),
      });
      expect(lineOf(g.parts.first, 'substitution'), 1.5);
      expect(noteOf(g.parts.first, 'substitution'), contains('من ٢'));
    });

    test('نتيجة بلا وحدة ⇒ النتيجة ١ والوحدة ٠ مع «الوحدة ناقصة»', () {
      final g = gradeParts(item, {
        '١': (
          relation: fullRelation1,
          substitution: fullSubst1,
          result: '100',
          chosen: null,
        ),
      });
      expect(lineOf(g.parts.first, 'result'), 1);
      expect(lineOf(g.parts.first, 'unit'), 0);
      expect(noteOf(g.parts.first, 'unit'), contains('الوحدة ناقصة'));
    });

    test('صيغة الجذر على صورة √a/b تُفهم جذراً ومقاماً (لا √a وحده)', () {
      final g = gradeParts(item, {
        '١': (
          relation: fullRelation1,
          substitution: fullSubst1,
          result: '√10000/1 Ω',
          chosen: null,
        ),
      });
      expect(lineOf(g.parts.first, 'result'), 1);
      expect(lineOf(g.parts.first, 'unit'), 1);
    });

    test('مقدار بلا بُعد ⇒ سطر الوحدة لا يُخصم (unitRequired كاذبة)', () {
      final g = gradeParts(item, {
        '٢': (
          relation: fullRelation2,
          substitution: fullSubst2,
          result: '0٫6', // أرقام هندية + فاصلة عربية
          chosen: null,
        ),
      });
      expect(lineOf(g.parts.last, 'result'), 1);
      expect(lineOf(g.parts.last, 'unit'), 1);
      expect(g.points, 10);
    });
  });

  group('الخيارات ومتابعة الخطأ', () {
    test('الخيار الصحيح ⇒ النتيجة والوحدة من نص الخيار', () {
      final g = gradeParts(item, {
        '١': (
          relation: fullRelation1,
          substitution: fullSubst1,
          result: '',
          chosen: fullChoice1,
        ),
      });
      expect(lineOf(g.parts.first, 'result'), 1);
      expect(lineOf(g.parts.first, 'unit'), 1); // «100 Ω» يحمل الوحدة
      expect(g.points, 10);
    });

    test('خيار خاطئ بلا اتساق ⇒ صفر في الجزءين', () {
      final g = gradeParts(item, {
        '١': (
          relation: fullRelation1,
          substitution: fullSubst1,
          result: '',
          chosen: 0, // 140 — خطأ Z_algebraic
        ),
      });
      expect(lineOf(g.parts.first, 'result'), 0);
      expect(lineOf(g.parts.first, 'unit'), 0);
      expect(g.points, 8); // ٥ + ٣ فقط: العلاقة والتعويض
    });

    test('FT: أخطأ في الجزء ١ ومشى صحيحاً عليه ⇒ نتيجته مقبولة مع ملاحظة', () {
      final g = gradeParts(item, {
        '١': (
          relation: '',
          substitution: '',
          result: '',
          chosen: 0, // 140 (خطأ)
        ),
        '٢': (
          relation: '',
          substitution: '',
          result: '0.428571', // = 60/140 — مبني على جوابه هو
          chosen: null,
        ),
      });
      final p2 = g.parts.last;
      expect(lineOf(p2, 'result'), 1);
      expect(p2.followThrough, isTrue);
      expect(lineOf(p2, 'unit'), 1); // بلا بُعد ⇒ لا تُخصم
      expect(g.points, 2);
      expect(g.notes.any((n) => n.contains('متابعة للخطأ')), isTrue);
    });

    test('FT ترفض الرقم غير المتسق مع جواب الطالب', () {
      final g = gradeParts(item, {
        '١': (relation: '', substitution: '', result: '', chosen: 0),
        '٢': (
          relation: '',
          substitution: '',
          result: '0.5', // ليس 60/140 ولا المفتاح 0٫6
          chosen: null,
        ),
      });
      expect(lineOf(g.parts.last, 'result'), 0);
      expect(g.parts.last.followThrough, isFalse);
      expect(g.points, 0);
    });

    test('نصوص السلم حرفيّة تحت كل سطر — حتى مع صفر الدرجة (§٦.٦-4)', () {
      final g = gradeParts(item, const {}); // لا إجابة: السلّم يُعرض كاملاً
      List<String> textsOf(PartScore s, String kind) =>
          s.lines.firstWhere((l) => l.kind == kind).stepTexts;
      // نفس JSON حرفياً — لا إعادة صياغة ولا تخمين
      expect(textsOf(g.parts.first, 'relation'),
          ['الجزء ١ · العلاقة: Z = √(R² + X²)']);
      expect(textsOf(g.parts.first, 'substitution'),
          ['الجزء ١ · التعويض: Z = √(60² + 80²)']);
      expect(textsOf(g.parts.first, 'result'), ['الجزء ١ · النتيجة: 100 Ω']);
      expect(textsOf(g.parts.first, 'unit'), ['الجزء ١ · الوحدة']);
      expect(textsOf(g.parts.last, 'relation'),
          ['الجزء ٢ · العلاقة: cos φ = R/Z']);
      expect(textsOf(g.parts.last, 'unit'),
          ['الجزء ٢ · الوحدة (مقدار بلا بُعد)']);
      // أي سطر ظهر في السلّم فكل نصوصه مسجّلة بنوعه في rubric — لا نصّ بلا مصدر
      for (final part in g.parts) {
        for (final line in part.lines) {
          expect(line.stepTexts, isNotEmpty, reason: line.step);
          for (final t in line.stepTexts) {
            expect(
              item.parts.any((x) =>
                  x.rubric.any((e) => e.kind == line.kind && e.step == t)),
              isTrue,
              reason: t,
            );
          }
        }
      }
    });
  });
}
