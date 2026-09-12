import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/training/batch_builder.dart';
import 'package:fizya_clash/core/training/training_store.dart';

/// F3.3 — اختبارات نواة التدريب: البذرة اليومية الحتمية + البنّاء + المخزن.
/// الحتمية أساس عدالة «مهام اليوم» (docs/12 §٢.١): نفس اليوم ⇒ نفس الدفعة.

Question _q(int id, String chapter, {bool approved = true, int correct = 1}) =>
    Question(
      id: id,
      unit: 'U1',
      chapter: chapter,
      approved: approved,
      stem: 'متن السؤال $id',
      options: ['خيار أ ($id)', 'خيار ب ($id)', 'خيار ج ($id)', 'خيار د ($id)'],
      correctIndex: correct,
      solutionSteps: const ['الخطوة الأولى', 'الخطوة الثانية'],
      followThrough: const [],
    );

ContentPack _packWith(List<Question> qs) => ContentPack(
      packId: 't',
      year: 2027,
      edition: 1,
      units: const [
        Unit(id: 'U1', title: 'وحدة', chapters: [
          Chapter(id: 'A', title: 'فصل أ', page: 1, paragraphs: []),
          Chapter(id: 'B', title: 'فصل ب', page: 2, paragraphs: []),
          Chapter(id: 'C', title: 'فصل ج', page: 3, paragraphs: []),
        ]),
      ],
      questions: qs,
      cards: const [],
    );

void main() {
  group('البذرة اليومية والتواريخ (docs/12 §٢.١)', () {
    test('مفتاح اليوم المحلي ورقمه — roundtrip', () {
      expect(dateKeyOf(DateTime(2026, 9, 12)), '2026-09-12');
      expect(dayNumberOf('2026-09-12'), 20708);
      expect(dayNumberOf(dateKeyOf(DateTime(2027, 1, 1))),
          dayNumberOf('2027-01-01'));
    });

    test('متجه ذهبي: mix64(deviceId ⊕ dayNumber)', () {
      // محسوب مستقلاً (مرجع SplitMix64 نفسه) — أي انزياح يكسر الاختبار
      expect(dailySeed(deviceId: 7, dateKey: '2026-09-12'),
          0x03DC12206D0163D3);
      expect(dailySeed(deviceId: 0, dateKey: '2026-09-12'),
          0x38C761EE882717C1);
      // اليوم التالي يغيّر البذرة كلياً
      expect(dailySeed(deviceId: 7, dateKey: '2026-09-13'),
          isNot(0x03DC12206D0163D3));
    });
  });

  group('بنّاء دفعة اليوم', () {
    final pack12 = _packWith([
      for (var i = 1; i <= 4; i++) _q(100 + i, 'A'),
      for (var i = 1; i <= 4; i++) _q(200 + i, 'B'),
      for (var i = 1; i <= 4; i++) _q(300 + i, 'C'),
    ]);

    test('الحتمية: نفس اليوم ⇒ نفس الترتيب كلياً (أسئلة وخيارات)', () {
      final a = buildDailyBatch(pack12, dateKey: '2026-09-12')!;
      final b = buildDailyBatch(pack12, dateKey: '2026-09-12')!;
      expect(a.session.questionIds, b.session.questionIds);
      expect(a.session.optionOrders, b.session.optionOrders);
      final c = buildDailyBatch(pack12, dateKey: '2026-09-13')!;
      expect(c.session.questionIds, isNot(a.session.questionIds));
    });

    test('المعتمد حصراً (قرار ٢٤) — المحجوب لا يدخل الدفعة أبداً', () {
      final mixed = _packWith([
        _q(1, 'A', approved: false),
        _q(2, 'A'),
        _q(3, 'A', approved: false),
        _q(4, 'A'),
      ]);
      final batch = buildDailyBatch(mixed, dateKey: '2026-09-12')!;
      expect(batch.session.questionIds, everyElement(isIn([2, 4])));
    });

    test('لا بنك معتمد ⇒ null (شاشة الانتظار)', () {
      final locked = _packWith([_q(1, 'A', approved: false)]);
      expect(buildDailyBatch(locked, dateKey: '2026-09-12'), isNull);
    });

    test('العدد: حصة اليوم ١٠ أو ما دونها', () {
      expect(
        buildDailyBatch(pack12, dateKey: '2026-09-12')!.session.questionIds,
        hasLength(10),
      );
      final small = _packWith([_q(1, 'A'), _q(2, 'B'), _q(3, 'C')]);
      expect(
        buildDailyBatch(small, dateKey: '2026-09-12')!.session.questionIds,
        hasLength(3),
      );
    });

    test('توازن الفصول round-robin — لا تركز الدفعة في فصل واحد', () {
      final ids =
          buildDailyBatch(pack12, dateKey: '2026-09-12')!.session.questionIds;
      int countOf(int lo, int hi) =>
          ids.where((id) => id >= lo && id <= hi).length;
      // بنك 4/4/4 ودفعة 10 ⇒ توزيع 4/3/3 بأي ترتيب
      final counts = [
        countOf(100, 199),
        countOf(200, 299),
        countOf(300, 399),
      ]..sort();
      expect(counts, [3, 3, 4]);
    });

    test('خلط الخيارات حتمي + الصحيح بالعرض يطابق نص الصحيح الأصلي', () {
      final batch = buildDailyBatch(pack12, dateKey: '2026-09-12')!;
      final q = pack12.questions.first;
      final order = batch.session.optionOrders[q.id]!;
      expect(order.toSet(), {0, 1, 2, 3}); // تبديل كامل بلا فقدان
      final shown = q.options[order[displayCorrectIndex(q, order)]];
      expect(shown, q.options[q.correctIndex]);
    });
  });

  group('التخزين والنماذج', () {
    test('DailyBatchState — roundtrip كامل', () {
      const s = DailyBatchState(dateKey: '2026-09-12', order: [103, 107]);
      final s2 = s.withAnswer(103, 2).withAnswer(107, 0).finish(1);
      final back = DailyBatchState.fromJson(s2.toJson());
      expect(back.dateKey, '2026-09-12');
      expect(back.order, [103, 107]);
      expect(back.answers, {103: 2, 107: 0});
      expect(back.done, isTrue);
      expect(back.score, 1);
      expect(back.answeredCount, 2);
    });

    test('withNewMistakes — الأحدث محل الأقدم والترتيب تنازلياً', () {
      const old = MistakeRecord(
          questionId: 5, chosenIndex: 1, correctIndex: 0, atMs: 1000);
      const other = MistakeRecord(
          questionId: 9, chosenIndex: 2, correctIndex: 3, atMs: 2000);
      const fresh = MistakeRecord(
          questionId: 5, chosenIndex: 0, correctIndex: 1, atMs: 3000);
      final merged = withNewMistakes(
          const TrainingData(mistakes: [old]), [other, fresh]);
      expect(merged.mistakes.map((m) => m.questionId).toList(), [5, 9]);
      expect(merged.mistakes.first.chosenIndex, 0); // الأحدث حلت محل القديم
    });

    test('TrainingData — roundtrip مع daily وأرشيف', () {
      const data = TrainingData(
        daily: DailyBatchState(
            dateKey: '2026-09-12', order: [1], answers: {1: 2}, done: true, score: 0),
        mistakes: [
          MistakeRecord(questionId: 1, chosenIndex: 2, correctIndex: 0, atMs: 9)
        ],
      );
      final back = TrainingData.fromJson(data.toJson());
      expect(back.daily!.answers, {1: 2});
      expect(back.mistakes.single.correctIndex, 0);
      // والمسار الفارغ
      const empty = TrainingData();
      expect(TrainingData.fromJson(empty.toJson()).daily, isNull);
      expect(TrainingData.fromJson(empty.toJson()).mistakes, isEmpty);
    });

    test('InMemoryTrainingStore — آخر حفظ هو المحمّل', () async {
      final store = InMemoryTrainingStore();
      expect((await store.load()).daily, isNull);
      await store.save(const TrainingData(
          daily: DailyBatchState(dateKey: '2026-09-12', order: [7])));
      expect((await store.load()).daily!.order, [7]);
    });
  });
}
