import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/fsrs/fsrs5.dart';

/// الأرقام المرجعية حُسبت بمقارن Python مستقل بنفس صيغ jakob.space
/// (الموثقة في docs/12 §٩) — 2026-09-11. سيناريو: بطاقة جديدة good ثم بعد
/// ٣ أيام hard؛ ومقارنة سيناريو النسيان بدلاً من hard.
void main() {
  group('FSRS-5 — أرقام ذهبية (مرجع Python مستقل)', () {
    test('بطاقة جديدة good: S=W2 · D1 · I1', () {
      final c = Fsrs5.review(CardMemory.newCard(), Grade.good);
      expect(c.stability, closeTo(3.173000, 1e-4)); // W[2]
      expect(c.difficulty, closeTo(4.991833, 1e-4));
      expect(Fsrs5.nextIntervalDays(c), closeTo(3.173000, 1e-4));
    });

    test('بعد ٣ أيام ثم hard: R وS2 وD2 وI2', () {
      final c1 = Fsrs5.review(CardMemory.newCard(), Grade.good);
      final c2 = Fsrs5.review(c1, Grade.hard, elapsedDays: 3.0);
      final r = Fsrs5.retrievability(3.0, c1.stability);
      expect(r, closeTo(0.904698, 1e-5));
      expect(c2.stability, closeTo(5.013534, 1e-4));
      expect(c2.difficulty, closeTo(5.792623, 1e-4));
      expect(Fsrs5.nextIntervalDays(c2), closeTo(5.013534, 1e-4));
    });

    test('بعد ٣ أيام ثم نسيان: الثبات ينهار إلى ~1.06 يوم', () {
      final c1 = Fsrs5.review(CardMemory.newCard(), Grade.good);
      final c2 = Fsrs5.review(c1, Grade.again, elapsedDays: 3.0);
      expect(c2.stability, closeTo(1.062152, 1e-4));
      expect(c2.lapses, 1);
    });
  });

  group('FSRS-5 — هويات رياضية ومعاملات سلوكية', () {
    test('الهوية: R(S,S) = 0.9 بالضبط (تعريف الثبات)', () {
      for (final s in [0.5, 3.173, 30.0, 180.0]) {
        expect(Fsrs5.retrievability(s, s), closeTo(0.9, 1e-9));
      }
    });

    test('الهوية: I(0.9, S) = S (الجدولة تعيد البطاقة عند ٩٠٪)', () {
      for (final s in [0.5, 3.173, 30.0]) {
        expect(Fsrs5.intervalAt(0.9, s), closeTo(s, 1e-9));
      }
    });

    test('الترتيب السلوكي: good يطيل أكثر من hard، والنسيان يقصّر', () {
      final c1 = Fsrs5.review(CardMemory.newCard(), Grade.good);
      final hard = Fsrs5.review(c1, Grade.hard, elapsedDays: 3.0);
      final good = Fsrs5.review(c1, Grade.good, elapsedDays: 3.0);
      final lapse = Fsrs5.review(c1, Grade.again, elapsedDays: 3.0);
      expect(good.stability, greaterThan(hard.stability));
      expect(hard.stability, greaterThan(lapse.stability));
      // الصعوبة: hard يرفعها أكثر من good
      expect(hard.difficulty, greaterThan(good.difficulty));
    });

    test('المقيدات: D ضمن [1,10] · الفترة ضمن [1,180]', () {
      var c = CardMemory.newCard();
      for (var i = 0; i < 30; i++) {
        c = Fsrs5.review(c, Grade.good, elapsedDays: 10.0);
        expect(c.difficulty, inInclusiveRange(1.0, 10.0));
        final iv = Fsrs5.nextIntervalDays(c);
        expect(iv, inInclusiveRange(1.0, Fsrs5.maxIntervalDays));
      }
    });

    test('عدم التغير بالحالة: المراجعة لا تعدّل البطاقة المُدخلة', () {
      final c1 = Fsrs5.review(CardMemory.newCard(), Grade.good);
      final sBefore = c1.stability;
      Fsrs5.review(c1, Grade.hard, elapsedDays: 3.0);
      expect(c1.stability, sBefore); // نفس الكائن بقي كما هو
    });
  });
}
