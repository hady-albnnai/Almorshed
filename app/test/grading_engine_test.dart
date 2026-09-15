// المادة ١١ — محرك التصحيح: اختياري · رقمي ±٢٪ + وحدة · مفاتيح «علّل/اذكر»
// بتطبيع عربي · برهان مرتّب بخصومات السلم (docs/20 §٢ · docs/14 §د).
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/grading/arabic_normalizer.dart';
import 'package:fizya_clash/core/grading/grading_engine.dart';

void main() {
  group('التطبيع العربي', () {
    test('ة→ه · أإآ→ا · ى→ي · حذف التشكيل والتطويل والترقيم', () {
      expect(ArabicNormalizer.normalize('الطّاقةُ الحركيّة،'), 'الطاقه الحركيه');
      expect(ArabicNormalizer.normalize('أعظميّة!'), 'اعظميه');
      expect(ArabicNormalizer.normalize('إلى الأعلى'), 'الي الاعلي');
      expect(ArabicNormalizer.normalize('الســـرعة'), 'السرعه');
    });

    test('الأرقام العربية-الهندية → لاتينية', () {
      expect(ArabicNormalizer.normalize('٢٠٢٦ و١٢٫٥'), '2026 و 12 5');
    });

    test('tokens تحذف «ال» و«و» العطف', () {
      expect(ArabicNormalizer.tokens('الكتلة والصلابة'), ['كتله', 'صلابه']);
      expect(ArabicNormalizer.tokens('k وm ثابتان'), ['k', 'm', 'ثابتان']);
    });

    test('contains: مطابقة كلامية متتالية بعد التطبيع', () {
      expect(ArabicNormalizer.contains('لأنّ السُّرعة أعظميّة هناك', 'السرعة أعظمية'), isTrue);
      expect(ArabicNormalizer.contains('لأن السرعة معدومة', 'السرعة أعظمية'), isFalse);
      expect(ArabicNormalizer.contains('k و m مقداران ثابتان وموجبان', 'k وm مقادير ثابتة وموجبة'), isFalse);
      expect(ArabicNormalizer.contains('k وm مقداران ثابتان وموجبان', 'k و m مقداران ثابتان وموجبان'), isTrue);
      expect(ArabicNormalizer.contains('تتعلق بالكتلة والصلابة', 'الكتلة'), isTrue);
    });
  });

  group('اختياري', () {
    test('مطابقة مباشرة', () {
      expect(gradeMcq(chosenIndex: 2, correctIndex: 2).correct, isTrue);
      final r = gradeMcq(chosenIndex: 1, correctIndex: 2, weight: 10);
      expect(r.points, 0);
      expect(r.maxPoints, 10);
    });
  });

  group('رقمي ±٢٪ + وحدة', () {
    test('توحيد الوحدات: m/s ≡ m·s⁻¹ ≡ m.s-1', () {
      expect(canonicalUnit('m·s⁻¹'), canonicalUnit('m/s'));
      expect(canonicalUnit('m.s-1'), canonicalUnit('m/s'));
      expect(canonicalUnit('N·m⁻¹'), canonicalUnit('N/m'));
      expect(canonicalUnit('m·s⁻²'), canonicalUnit('m/s²'));
      expect(canonicalUnit('N·m·rad⁻¹'), canonicalUnit('rad⁻¹·N·m'));
      expect(canonicalUnit('kg·m²'), isNot(canonicalUnit('kg·m')));
      expect(canonicalUnit('ثا'), canonicalUnit('s'));
    });

    test('تحليل الإجابة الحرة: قيمة + وحدة + إشارة + π + جذر', () {
      final a = parseNumericAnswer('−0.4 m·s⁻²')!;
      expect(a.value, closeTo(-0.4, 1e-9));
      expect(canonicalUnit(a.unit), canonicalUnit('m/s²'));
      final b = parseNumericAnswer('٢ ثا')!;
      expect(b.value, 2);
      expect(canonicalUnit(b.unit), 's');
      final c = parseNumericAnswer('8π/5 rad·s⁻¹')!;
      expect(c.value, closeTo(8 * 3.14159265 / 5, 1e-6));
      expect(canonicalUnit(c.unit), canonicalUnit('rad/s'));
      final d = parseNumericAnswer('√10 rad/s')!;
      expect(d.value, closeTo(3.1622776, 1e-6));
      expect(parseNumericAnswer('لا أعرف'), isNull);
    });

    test('ضمن ±٢٪ مع الوحدة ⇒ كامل · بلا وحدة ⇒ −١ · وحدة خاطئة ⇒ −١', () {
      final full = gradeNumeric(keyValue: 2, keyUnit: 's', raw: '2 s');
      expect(full.correct, isTrue);
      expect(full.points, 10);
      final within = gradeNumeric(keyValue: 2, keyUnit: 's', raw: '2.03 s');
      expect(within.correct, isTrue);
      final noUnit = gradeNumeric(keyValue: 2, keyUnit: 's', raw: '2');
      expect(noUnit.points, 9);
      expect(noUnit.correct, isFalse);
      expect(noUnit.notes.single, contains('ناقصة'));
      final badUnit = gradeNumeric(keyValue: 2, keyUnit: 's', raw: '2 m');
      expect(badUnit.points, 9);
      expect(badUnit.notes.single, contains('خاطئة'));
    });

    test('خارج ±٢٪ ⇒ صفر · الإشارة المعكوسة ⇒ صفر مع ملاحظة', () {
      final off = gradeNumeric(keyValue: 2, keyUnit: 's', raw: '2.1 s');
      expect(off.points, 0);
      final sign = gradeNumeric(keyValue: -0.4, keyUnit: 'm·s⁻²', raw: '0.4 m·s⁻²');
      expect(sign.points, 0);
      expect(sign.notes.single, contains('الإشارة'));
      final abs = gradeNumeric(
        keyValue: -0.4,
        keyUnit: 'm·s⁻²',
        raw: '0.4 m·s⁻²',
        signMatters: false,
      );
      expect(abs.correct, isTrue);
    });

    test('مسألة ٢٠٢٦: √10 rad·s⁻¹ يقبل 3.16 rad/s ويرفض 3.5', () {
      const key = 3.1622776601683795;
      expect(gradeNumeric(keyValue: key, keyUnit: 'rad·s⁻¹', raw: '3.16 rad/s').correct, isTrue);
      expect(gradeNumeric(keyValue: key, keyUnit: 'rad·s⁻¹', raw: '√10 rad·s⁻¹').correct, isTrue);
      expect(gradeNumeric(keyValue: key, keyUnit: 'rad·s⁻¹', raw: '3.5 rad/s').points, 0);
    });
  });

  group('«اذكر N» و«علّل»', () {
    test('درجة لكل عنصر بحد N (قاعدة السلم ٧) مع مرادفات', () {
      final r = gradeKeywords(
        answer: 'تتعلق بكتلة الجسم وثابت الصلابة فقط',
        keyGroups: const [
          ['كتلة الجسم', 'الكتلة'],
          ['ثابت صلابة النابض', 'ثابت الصلابة', 'الصلابة'],
          ['لا تتعلق بالسعة', 'السعة'],
        ],
        pointsPerItem: 5,
      );
      expect(r.points, 10);
      expect(r.maxPoints, 15);
      expect(r.correct, isFalse);
      expect(r.notes.single, contains('لا تتعلق بالسعة'));
    });

    test('«علّل» بوزن البند: المفتاح المضاد يصفّر', () {
      const keys = [
        ['k وm مقداران ثابتان وموجبان', 'k و m ثابتان وموجبان', 'ثابتان وموجبان'],
      ];
      final ok = gradeKeywords(
        answer: 'لأنَّ k و m ثابتان وموجبان',
        keyGroups: keys,
        antiKeys: const ['لأن الحركة انسحابية', 'لأن الحركة غير متخامدة'],
        weight: 10,
      );
      expect(ok.correct, isTrue);
      expect(ok.points, 10);
      final anti = gradeKeywords(
        answer: 'لأن الحركة انسحابية وk وm ثابتان وموجبان',
        keyGroups: keys,
        antiKeys: const ['لأن الحركة انسحابية'],
        weight: 10,
      );
      expect(anti.points, 0);
      expect(anti.notes.single, contains('مغلوط'));
    });

    test('الحد N يمنع الزيادة: ٥ عناصر صحيحة مقابل «اذكر ٣» = ٣ درجات', () {
      final r = gradeKeywords(
        answer: 'أ ب ج د هـ',
        keyGroups: const [['أ'], ['ب'], ['ج'], ['د'], ['هـ']],
        maxItems: 3,
      );
      expect(r.points, 3);
      expect(r.correct, isTrue);
    });
  });

  group('برهان بخطوات مرتّبة', () {
    // برهان الهزازة ٢٠٢٦ (٢٥ درجة): 5/4/4/2/2/2/2/4
    final steps = [
      const ProofStep(n: 1, text: 'x = XmaX·cos(ω0·t + φ)', points: 5, penalty: {'missing_phi': -1}, block: 0),
      const ProofStep(n: 2, text: 'x′', points: 4, block: 1),
      const ProofStep(n: 3, text: 'x″', points: 4, block: 1),
      const ProofStep(n: 4, text: 'x″ = −ω0²·x', points: 2, penalty: {'missing_minus': -4}, block: 2),
      const ProofStep(n: 5, text: 'ω0² = k/m', points: 2, block: 3),
      const ProofStep(n: 6, text: 'ω0 = √(k/m)', points: 2, block: 3),
      const ProofStep(n: 7, text: 'ω0 = 2π/T0', points: 2, block: 4),
      const ProofStep(n: 8, text: 'T0 = 2π√(m/k)', points: 4, block: 4),
    ];

    test('كامل ومرتّب = ٢٥', () {
      final r = gradeProof(
        steps: steps,
        attempt: const ProofAttempt(orderedStepNumbers: [1, 2, 3, 4, 5, 6, 7, 8]),
      );
      expect(r.points, 25);
      expect(r.correct, isTrue);
    });

    test('إهمال الإشارة −٤ (قاعدة ٥) وإهمال φ −١ (قاعدة ٤)', () {
      final r = gradeProof(
        steps: steps,
        attempt: const ProofAttempt(
          orderedStepNumbers: [1, 2, 3, 4, 5, 6, 7, 8],
          flags: {4: {'missing_minus'}, 1: {'missing_phi'}},
        ),
      );
      expect(r.points, 20);
      expect(r.notes, contains(contains('الإشارة السالبة')));
      expect(r.notes, contains(contains('φ')));
    });

    test('الطريق البديل داخل الكتلة مقبول (قاعدة ٦) · القفز بين الكتل لا يُحتسب', () {
      final swapInside = gradeProof(
        steps: steps,
        attempt: const ProofAttempt(orderedStepNumbers: [1, 3, 2, 4, 6, 5, 8, 7]),
      );
      expect(swapInside.points, 25);
      // الخطوة ٨ (الكتلة ٤) قُدِّمت بعد ١ مباشرة ⇒ تُحتسب هي، وكل ما بعدها
      // من كتل أسبق (٢..٦) «قبل أوانه» فلا يُحتسب؛ أما ٧ فمن كتلة ٨ نفسها
      // (ترتيب مرن داخل الكتلة) فتُحتسب: 5 + 4 + 2 = 11
      final jump = gradeProof(
        steps: steps,
        attempt: const ProofAttempt(orderedStepNumbers: [1, 8, 2, 3, 4, 5, 6, 7]),
      );
      expect(jump.points, 11);
      expect(jump.notes.where((n) => n.contains('غير موضعها')).length, 5);
    });

    test('خطوات ناقصة تُذكر بعباراتها', () {
      final r = gradeProof(
        steps: steps,
        attempt: const ProofAttempt(orderedStepNumbers: [1, 2, 3]),
      );
      expect(r.points, 13);
      expect(r.notes.where((n) => n.startsWith('ناقص')).length, 5);
    });
  });

  group('الموزّع gradeItem على بنود المولّد', () {
    test('رقمي من حقل answer', () {
      final item = {
        'type': 'numeric',
        'weight': 10,
        'correctIndex': 2,
        'options': ['2.5 s', '5.5 s', '5 s', '20 s'],
        'answer': {'value': 5.0, 'unit': 's', 'tolerance': 0.02},
      };
      expect(gradeItem(item, '5 s').correct, isTrue);
      expect(gradeItem(item, '٥ ثا').correct, isTrue);
      expect(gradeItem(item, 2).correct, isTrue);
      expect(gradeItem(item, '5').points, 9);
    });

    test('علّل من keys/antiKeys · برهان من steps', () {
      final why = {
        'type': 'why',
        'weight': 10,
        'correctIndex': 0,
        'keys': ['k وm مقادير ثابتة وموجبة', 'ω0 = √(k/m)'],
        'antiKeys': ['لأن الحركة انسحابية'],
      };
      final half = gradeItem(why, 'لأن k و m مقادير ثابتة وموجبة');
      expect(half.points, 5);
      final proof = {
        'type': 'proof',
        'steps': [
          {'n': 1, 'text': 'أ', 'points': 5, 'penalty': {'missing_phi': -1}},
          {'n': 2, 'text': 'ب', 'points': 4},
        ],
      };
      final r = gradeItem(
        proof,
        const ProofAttempt(orderedStepNumbers: [1, 2], flags: {1: {'missing_phi'}}),
      );
      expect(r.points, 8);
      expect(r.maxPoints, 9);
    });
  });
}
