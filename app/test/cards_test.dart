import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/fsrs/fsrs5.dart';
import 'package:fizya_clash/core/training/cards_service.dart';
import 'package:fizya_clash/core/training/training_store.dart';

/// F3.4 — اختبارات نواة البطاقات: الطابور الحتمي + تطبيق FSRS + التخزين.

CardItem _card(int id) => CardItem(
      id: id,
      unit: 'U1',
      chapter: 'C1',
      front: 'وجه $id',
      back: 'ظهر $id',
    );

const _today = '2026-09-12';

void main() {
  group('بنّاء طابور البطاقات', () {
    test('بلا حالات ⇒ ٦ جديدة حصراً (الأصغر معرفاً أولاً)', () {
      final cards = [for (var i = 1; i <= 10; i++) _card(i)];
      final q = buildCardQueue(cards: cards, states: const {}, dateKey: _today);
      expect(q, [1, 2, 3, 4, 5, 6]);
    });

    test('السقف ٢٠ حصراً والمستحقة قبل الجديدة', () {
      final cards = [for (var i = 1; i <= 30; i++) _card(i)];
      final states = {
        // مستحقة أمس وأخرى مستحقة اليوم — والثالثة مستقبلية تُستبعد
        25: const CardStateData(
            cardId: 25,
            difficulty: 5,
            stability: 3,
            reviews: 1,
            lapses: 0,
            dueDateKey: '2026-09-11'),
        27: const CardStateData(
            cardId: 27,
            difficulty: 5,
            stability: 3,
            reviews: 1,
            lapses: 0,
            dueDateKey: '2026-09-12'),
        29: const CardStateData(
            cardId: 29,
            difficulty: 5,
            stability: 9,
            reviews: 2,
            lapses: 0,
            dueDateKey: '2026-09-13'),
      };
      final q = buildCardQueue(cards: cards, states: states, dateKey: _today);
      expect(q, hasLength(20));
      expect(q.take(2), [25, 27]); // المستحقة: الأقدم استحقاقاً أولاً
      expect(q.contains(29), isFalse);
      expect(q.skip(2).take(6), [1, 2, 3, 4, 5, 6]); // ثم الجديدة الست
    });

    test('الحتمية: نفس المدخلات ⇒ نفس الطابور', () {
      final cards = [for (var i = 1; i <= 12; i++) _card(i)];
      final a = buildCardQueue(cards: cards, states: const {}, dateKey: _today);
      final b = buildCardQueue(cards: cards, states: const {}, dateKey: _today);
      expect(a, b);
    });
  });

  group('تطبيق التقييمات (FSRS-5)', () {
    test('جديدة + أعرفها ⇒ S1 = W2 = 3.173 والاستحقاق بعد ~٣ أيام', () {
      final s = reviewCard(
          previous: null, cardId: 7, grade: Grade.good, todayKey: _today);
      expect(s.stability, moreOrLessEquals(3.173, epsilon: 1e-9));
      expect(s.reviews, 1);
      expect(s.lapses, 0);
      // الفترة عند هدف ٩٠٪ تساوي S1 بالبناء الرياضياتي (0.9^-2 − 1 = 19/81)
      expect(s.dueDateKey, '2026-09-15'); // +3 أيام
    });

    test('جديدة + ما عرفتها ⇒ أدنى فترة (غداً) مع هفوة', () {
      final s = reviewCard(
          previous: null, cardId: 7, grade: Grade.again, todayKey: _today);
      expect(s.stability, moreOrLessEquals(Fsrs5.w[0], epsilon: 1e-9));
      expect(s.lapses, 1);
      expect(s.dueDateKey, '2026-09-13');
    });

    test('بصعوبة ⇒ S1 = W1 والاستحقاق غداً', () {
      final s = reviewCard(
          previous: null, cardId: 7, grade: Grade.hard, todayKey: _today);
      expect(s.stability, moreOrLessEquals(Fsrs5.w[1], epsilon: 1e-9));
      expect(s.dueDateKey, '2026-09-13');
    });

    test('تطبيق التقييم يرقّي اليوم ولا يمس بقية البيانات', () {
      const day = CardDayState(dateKey: _today, queue: [7, 8]);
      const before = TrainingData(
        cardDay: day,
        mistakes: [
          MistakeRecord(questionId: 1, chosenIndex: 0, correctIndex: 1, atMs: 5)
        ],
      );
      final after = applyCardReview(before,
          cardId: 7, grade: Grade.good, todayKey: _today);
      expect(after.cardDay!.doneCount, 1);
      expect(after.cardDay!.finished, isFalse);
      expect(after.cardStates[7], isNotNull);
      expect(after.mistakes, hasLength(1)); // الأرشيف محفوظ
      final done =
          applyCardReview(after, cardId: 8, grade: Grade.hard, todayKey: _today);
      expect(done.cardDay!.finished, isTrue);
      expect(done.cardStates, hasLength(2));
    });

    test('لا تقييم بعد الإتمام أو بيوم غير مجمد', () {
      const finished = CardDayState(
          dateKey: _today, queue: [7], doneCount: 1, finished: true);
      const data = TrainingData(cardDay: finished);
      expect(
        applyCardReview(data, cardId: 7, grade: Grade.good, todayKey: _today),
        same(data),
      );
      const stale =
          TrainingData(cardDay: CardDayState(dateKey: '2026-09-11', queue: [7]));
      expect(
        applyCardReview(stale, cardId: 7, grade: Grade.good, todayKey: _today),
        same(stale),
      );
    });
  });

  group('تجميد اليوم (نمط مهام اليوم)', () {
    test('أول نداء يجمد والثاني يترك كما هو ويوم جديد يعيد البناء', () {
      final cards = [for (var i = 1; i <= 8; i++) _card(i)];
      final frozen =
          startCardDay(const TrainingData(), cards: cards, dateKey: _today);
      expect(frozen.cardDay!.queue, [1, 2, 3, 4, 5, 6]);
      expect(
        startCardDay(frozen, cards: cards, dateKey: _today),
        same(frozen),
      );
      // غداً: الست المجمدة استحقاقها بعد ٣ أيام — الطابور يجلب الجديد التالي
      final tomorrow =
          startCardDay(frozen, cards: cards, dateKey: '2026-09-13');
      expect(tomorrow.cardDay!.queue, [7, 8]);
    });

    test('بلا بطاقات ⇒ لا تجميد (نفس البيانات)', () {
      final out =
          startCardDay(const TrainingData(), cards: const [], dateKey: _today);
      expect(out.cardDay, isNull);
    });
  });
}
