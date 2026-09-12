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

    test('المستحقة أولاً ثم ٦ جديدة — السقف أقصى لا حد أدنى (تصحيح بلصة المالك)', () {
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
      // ٢ مستحقة + ٦ جديدة = ٨ (السقف ٢٠ أقصى — لا حشو اصطناعي)
      expect(q, [25, 27, 1, 2, 3, 4, 5, 6]);
      expect(q.contains(29), isFalse);
    });

    test('السقف ٢٠ يُقطع فعلاً حين تتجاوز المستحقة إياه', () {
      final cards = [for (var i = 1; i <= 30; i++) _card(i)];
      final states = {
        for (var id = 1; id <= 22; id++)
          id: CardStateData(
              cardId: id,
              difficulty: 5,
              stability: 3,
              reviews: 1,
              lapses: 0,
              dueDateKey: '2026-09-11'),
      };
      final q = buildCardQueue(cards: cards, states: states, dateKey: _today);
      expect(q, hasLength(20)); // 22 مستحقة — القص عند السقف
      expect(q.last, 20);
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
          startCardDay(const TrainingData(), cards: cards, todayKey: _today);
      expect(frozen.cardDay!.queue, [1, 2, 3, 4, 5, 6]);
      expect(
        startCardDay(frozen, cards: cards, todayKey: _today),
        same(frozen),
      );
      // الاستخدام الحقيقي: تُراجع الست كلها (أعرفها ⇒ استحقاق بعد ٣ أيام)
      var data = frozen;
      for (final id in frozen.cardDay!.queue) {
        data = applyCardReview(data,
            cardId: id, grade: Grade.good, todayKey: _today);
      }
      // غداً: الست المراجعة غير مستحقة بعد ⇒ الجديد التالي ٧ و٨
      // (البطاقات الجديدة غير المراجعة تظل جديدة — توقيع بلصة المالك)
      final tomorrow =
          startCardDay(data, cards: cards, todayKey: '2026-09-13');
      expect(tomorrow.cardDay!.queue, [7, 8]);
    });

    test('بلا بطاقات ⇒ لا تجميد (نفس البيانات)', () {
      final out = startCardDay(const TrainingData(),
          cards: const [], todayKey: _today);
      expect(out.cardDay, isNull);
    });
  });

  group('التخزين والتوافق الخلفي', () {
    test('CardStateData وCardDayState — roundtrip', () {
      const s = CardStateData(
          cardId: 9,
          difficulty: 6.5,
          stability: 12.25,
          reviews: 3,
          lapses: 1,
          dueDateKey: '2026-12-01');
      final s2 = CardStateData.fromJson(s.toJson());
      expect(s2.cardId, 9);
      expect(s2.stability, 12.25);
      expect(s2.dueDateKey, '2026-12-01');
      const day = CardDayState(
          dateKey: _today, queue: [1, 2, 3], doneCount: 2, finished: true);
      final day2 = CardDayState.fromJson(day.toJson());
      expect(day2.queue, [1, 2, 3]);
      expect(day2.doneCount, 2);
      expect(day2.finished, isTrue);
    });

    test('بيانات قديمة بلا حقول البطاقات ⇒ افتراضات فارغة (توافق خلفي)', () {
      const legacy = TrainingData(
        daily: DailyBatchState(dateKey: _today, order: [101]),
      );
      final back = TrainingData.fromJson(legacy.toJson());
      expect(back.cardStates, isEmpty);
      expect(back.cardDay, isNull);
      expect(back.daily!.order, [101]);
    });

    test('todayCardQueue: المجمد إن كان لليوم وإلا استباقي', () {
      final cards = [for (var i = 1; i <= 4; i++) _card(i)];
      const frozen = TrainingData(
          cardDay: CardDayState(dateKey: _today, queue: [30, 31], doneCount: 1));
      expect(todayCardQueue(frozen, cards, _today), [30, 31]);
      expect(
          todayCardQueue(const TrainingData(), cards, _today), [1, 2, 3, 4]);
    });
  });
}
