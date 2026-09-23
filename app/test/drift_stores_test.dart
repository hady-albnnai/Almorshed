/// F3.1 — اختبارات مخازن Drift على قاعدة ذاكرة (بلا تشفير، بلا جهاز).
/// تتحقّق أن جولة كتابة→قراءة تُعيد نفس نماذج المجال حرفياً (round-trip)
/// عبر نفس الواجهات المجرّدة القائمة — إثبات أن Drift بديل أمين لـKV.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/db/app_database.dart';
import 'package:fizya_clash/core/db/drift_stores.dart';
import 'package:fizya_clash/core/progress/progress_store.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/core/xp/xp_event.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('DriftProgressStore', () {
    test('جولة كتابة→قراءة تحفظ الفصول والاكتمال', () async {
      final store = DriftProgressStore(db);
      const p = ReadProgress(chapters: {
        'U1C1': ChapterProgress(cursor: 3, completed: true),
        'U1C2': ChapterProgress(cursor: 1, completed: false),
      });
      await store.save(p);
      final loaded = await store.load();
      expect(loaded.chapters.length, 2);
      expect(loaded.chapters['U1C1']!.cursor, 3);
      expect(loaded.chapters['U1C1']!.completed, isTrue);
      expect(loaded.chapters['U1C2']!.completed, isFalse);
      expect(loaded.completedIds, {'U1C1'});
    });

    test('الحفظ لقطة كاملة — يمسح المحذوف', () async {
      final store = DriftProgressStore(db);
      await store.save(const ReadProgress(chapters: {
        'A': ChapterProgress(cursor: 1),
        'B': ChapterProgress(cursor: 2),
      }));
      await store.save(const ReadProgress(chapters: {
        'A': ChapterProgress(cursor: 9),
      }));
      final loaded = await store.load();
      expect(loaded.chapters.keys, {'A'});
      expect(loaded.chapters['A']!.cursor, 9);
    });

    test('قاعدة فارغة ⇒ تقدّم فارغ', () async {
      final loaded = await DriftProgressStore(db).load();
      expect(loaded.chapters, isEmpty);
    });
  });

  group('DriftTrainingStore', () {
    test('جولة كاملة: دفعة + أخطاء + بطاقات + طابور + تحدّي', () async {
      final store = DriftTrainingStore(db);
      final data = TrainingData(
        daily: const DailyBatchState(
          dateKey: '2026-09-23',
          order: [10, 20, 30],
          answers: {10: 2, 20: 0},
          done: false,
          score: 0,
        ),
        mistakes: const [
          MistakeRecord(
              questionId: 20, chosenIndex: 0, correctIndex: 1, atMs: 200),
          MistakeRecord(
              questionId: 10, chosenIndex: 3, correctIndex: 2, atMs: 100),
        ],
        cardStates: const {
          5: CardStateData(
            cardId: 5,
            difficulty: 6.2,
            stability: 12.5,
            reviews: 3,
            lapses: 1,
            dueDateKey: '2026-09-25',
          ),
        },
        cardDay: const CardDayState(
          dateKey: '2026-09-23',
          queue: [5, 6, 7],
          doneCount: 1,
          finished: false,
        ),
        labChallengeDoneDateKey: '2026-09-22',
        labChallengeDays: const {'spring': '2026-09-22', 'wave': '2026-09-23'},
      );
      await store.save(data);
      final loaded = await store.load();

      expect(loaded.daily!.order, [10, 20, 30]);
      expect(loaded.daily!.answers, {10: 2, 20: 0});
      // أخطائي مرتّبة الأحدث أولاً (atMs تنازلياً).
      expect(loaded.mistakes.map((m) => m.questionId), [20, 10]);
      expect(loaded.cardStates[5]!.stability, 12.5);
      expect(loaded.cardStates[5]!.difficulty, 6.2);
      expect(loaded.cardDay!.queue, [5, 6, 7]);
      expect(loaded.cardDay!.doneCount, 1);
      expect(loaded.labChallengeDoneDateKey, '2026-09-22');
      expect(loaded.labChallengeDays, {'spring': '2026-09-22', 'wave': '2026-09-23'});
    });

    test('null الحقول المفردة تبقى null بعد الجولة', () async {
      final store = DriftTrainingStore(db);
      await store.save(const TrainingData());
      final loaded = await store.load();
      expect(loaded.daily, isNull);
      expect(loaded.cardDay, isNull);
      expect(loaded.labChallengeDoneDateKey, isNull);
      expect(loaded.mistakes, isEmpty);
      expect(loaded.cardStates, isEmpty);
      expect(loaded.labChallengeDays, isEmpty);
    });

    test('الحفظ الثاني يمسح مفتاح النابض عند صيرورته null', () async {
      final store = DriftTrainingStore(db);
      await store.save(const TrainingData(labChallengeDoneDateKey: '2026-01-01'));
      expect((await store.load()).labChallengeDoneDateKey, '2026-01-01');
      await store.save(const TrainingData());
      expect((await store.load()).labChallengeDoneDateKey, isNull);
    });
  });

  group('DriftXpEventStore', () {
    test('جولة أحداث تحفظ الترتيب والسلسلة', () async {
      final store = DriftXpEventStore(db);
      final events = <XpEvent>[
        const XpEvent(
          seq: 1,
          type: 'batchDone',
          tsMs: 1000,
          payload: {'points': 15, 'dateKey': '2026-09-23'},
          prevHash: genesisPrevHash,
          hash: 'aa',
          sigB64: 'sig1',
        ),
        const XpEvent(
          seq: 2,
          type: 'streakDay',
          tsMs: 1001,
          payload: {'points': 10},
          prevHash: 'aa',
          hash: 'bb',
          sigB64: 'sig2',
        ),
      ];
      await store.saveEvents(events);
      final loaded = await store.loadEvents();
      expect(loaded.length, 2);
      expect(loaded[0].seq, 1);
      expect(loaded[0].type, 'batchDone');
      expect(loaded[0].payload['points'], 15);
      expect(loaded[1].prevHash, 'aa');
      expect(loaded[1].hash, 'bb');
      expect(loaded[1].sigB64, 'sig2');
    });

    test('قاعدة فارغة ⇒ قائمة فارغة', () async {
      expect(await DriftXpEventStore(db).loadEvents(), isEmpty);
    });
  });
}
