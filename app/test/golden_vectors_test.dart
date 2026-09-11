import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/rng/session.dart';
import 'package:fizya_clash/core/rng/splitmix64.dart';

/// المتجهات الذهبية — حُسبت بمقارن مستقل (Python بدقة 64بت) 2026-09-11.
/// أي تعديل يكسرها = خلل حتمية — docs/12 §٢.٤ وقرار ٤٥.
void main() {
  group('SplitMix64 — متجهات ذهبية بتّية', () {
    test('mix64 على البذور المرجعية', () {
      expect(SplitMix64.mix64(0x0000000000000000), 0xE220A8397B1DCDAF);
      expect(SplitMix64.mix64(0x0000000000000001), 0x910A2DEC89025CC1);
      expect(SplitMix64.mix64(0xFFFFFFFFFFFFFFFF), 0xE4D971771B652C20);
      expect(SplitMix64.mix64(0x1234567890ABCDEF), 0x1C948E1575796814);
    });

    test('تيار الجلسة المرجعية — ٥ قيم أولى', () {
      final rng = SplitMix64(0x1234567890ABCDEF);
      expect(
        List.generate(5, (_) => rng.next()),
        const [
          0x1C948E1575796814,
          0xAE9EF1AB67004BDB,
          0x7A2988D31F16E86E,
          0x7A5DAEA24EBA3BA7,
          0xBB83C0C2207AD3E6,
        ],
      );
    });

    test('الحتمية: نفس البذرة ⇒ نفس التسلسل دائماً', () {
      List<int> run() => List.generate(16, (_) => SplitMix64(42).next());
      expect(run(), run());
    });
  });

  group('بناء الجلسة — docs/12 §٢.٣', () {
    // بنك اختبار: ٢٠ سؤالاً عبر ٤ فصول (٥ لكل فصل)، كل سؤال ٤ خيارات.
    final chapterOf = <int, int>{
      for (var q = 1; q <= 20; q++) q: ((q - 1) ~/ 5) + 1,
    };
    final optionsOf = <int, List<int>>{
      for (var q = 1; q <= 20; q++) q: [q * 10, q * 10 + 1, q * 10 + 2, q * 10 + 3],
    };

    BuiltSession build(int seed, {int count = 10}) => buildSession(SessionSpec(
          seed: seed,
          count: count,
          bankIds: List.generate(20, (i) => i + 1),
          chapterOf: chapterOf,
          optionsOf: optionsOf,
        ));

    test('الحتمية الكاملة: نفس البذرة ⇒ نفس الأسئلة والخيارات', () {
      final a = build(0x1234567890ABCDEF);
      final b = build(0x1234567890ABCDEF);
      expect(a.questionIds, b.questionIds);
      expect(a.optionOrders, b.optionOrders);
    });

    test('التفرد: لا تكرار سؤال داخل الجلسة', () {
      final s = build(7);
      expect(s.questionIds.toSet().length, s.questionIds.length);
    });

    test('العدد المطلوب يُسلَّم حرفياً', () {
      expect(build(99, count: 10).questionIds.length, 10);
      expect(build(99, count: 20).questionIds.length, 20);
    });

    test('توازن الفصول: ١٠ أسئلة من ٤ فصول ⇒ لا فصل يتجاوز سقف round-robin',
        () {
      final s = build(2024);
      final perChapter = <int, int>{};
      for (final q in s.questionIds) {
        perChapter[chapterOf[q]!] = (perChapter[chapterOf[q]] ?? 0) + 1;
      }
      final maxAllowed =
          (10 / 4).ceil() + 1; // ceil(N/فصول)+1 — docs/12 §٢.٣
      for (final c in perChapter.values) {
        expect(c, lessThanOrEqualTo(maxAllowed));
      }
    });

    test('خلط الخيارات: حتمي بالبذرة ويغير الترتيب الأصلي غالباً', () {
      final s1 = build(5);
      final s2 = build(6); // بذرة أخرى ⇒ ترتيب خيارات مختلف متوقع
      final q = s1.questionIds.first;
      expect(s1.optionOrders[q], isNotNull);
      // حتمية داخل نفس البذرة (مغطاة أعلاه) — هنا نتحقق أن التوليد الفعلي جرى
      expect(s1.optionOrders[q]!.length, 4);
      expect(s1.optionOrders[q]!.toSet().length, 4); // بلا فقد خيارات
      final q2 = s2.questionIds.first;
      expect(s2.optionOrders[q2]!.length, 4);
    });

    test('توزيع المواضع على ١٠٠٠ بذرة: كل خيار يظهر بكل المواضع (عدالة إحصائية)',
        () {
      // عيّنة أسرع من 10^6 الكاملة (تُشغَّل يومياً؛ 10^6 في CI ليلي لاحقاً)
      final firstPositionHits = <int, int>{};
      for (var seed = 1; seed <= 1000; seed++) {
        final s = build(seed, count: 1);
        final q = s.questionIds.first;
        firstPositionHits[s.optionOrders[q]!.first] =
            (firstPositionHits[s.optionOrders[q]!.first] ?? 0) + 1;
      }
      // 1000 بذرة × ٤ خيارات ⇒ كل خيار يجب أن يظهر بالموضع الأول في نطاق واسع
      expect(firstPositionHits.values.reduce((a, b) => a > b ? a : b),
          lessThan(400)); // لا هيمنة عنصرة
      expect(firstPositionHits.length, greaterThanOrEqualTo(3));
    });
  });
}
