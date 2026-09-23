/// F3.1 — تنفيذات التخزين على قاعدة Drift المشفّرة، **خلف الواجهات المجرّدة
/// القائمة** (ProgressStore/TrainingStore/XpEventStore) دون كسر أي عقد.
///
/// المبدأ: نفس نماذج المجال (ReadProgress/TrainingData/XpEvent) تُقرأ وتُكتب
/// كما هي؛ Drift يحلّ محلّ `shared_preferences` فقط كطبقة تخزين. المخازن هنا
/// حرّة من أي منطق أعمال — تحويل صفوف ↔ نماذج حصراً.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../progress/progress_store.dart';
import '../training/training_store.dart';
import '../xp/xp_event.dart';
import '../xp/xp_store.dart';
import 'app_database.dart';

// ── تقدّم القراءة ────────────────────────────────────────────────────
class DriftProgressStore implements ProgressStore {
  DriftProgressStore(this.db);
  final AppDatabase db;

  @override
  Future<ReadProgress> load() async {
    final rows = await db.select(db.chapterProgressRows).get();
    return ReadProgress(chapters: {
      for (final r in rows)
        r.chapterId:
            ChapterProgress(cursor: r.cursor, completed: r.completed),
    });
  }

  @override
  Future<void> save(ReadProgress progress) async {
    await db.transaction(() async {
      // الحفظ = المصدر الكامل للحقيقة: امسح ثم أدرج (لقطة كاملة كالـKV القديم).
      await db.delete(db.chapterProgressRows).go();
      for (final e in progress.chapters.entries) {
        await db.into(db.chapterProgressRows).insert(
              ChapterProgressRowsCompanion.insert(
                chapterId: e.key,
                cursor: Value(e.value.cursor),
                completed: Value(e.value.completed),
              ),
            );
      }
    });
  }
}

// ── التدريب (دفعة اليوم + أخطائي + بطاقات + طابور اليوم + تحدي المختبر) ─
class DriftTrainingStore implements TrainingStore {
  DriftTrainingStore(this.db);
  final AppDatabase db;

  static const int _singletonId = 1;

  @override
  Future<TrainingData> load() async {
    // دفعة اليوم (صف مفرد).
    final dailyRow = await (db.select(db.dailyBatchRows)
          ..where((t) => t.id.equals(_singletonId)))
        .getSingleOrNull();
    final daily = dailyRow == null
        ? null
        : DailyBatchState(
            dateKey: dailyRow.dateKey,
            order: (jsonDecode(dailyRow.orderJson) as List<dynamic>)
                .cast<int>(),
            answers: {
              for (final e in (jsonDecode(dailyRow.answersJson)
                      as Map<String, dynamic>)
                  .entries)
                int.parse(e.key): e.value as int,
            },
            done: dailyRow.done,
            score: dailyRow.score,
          );

    // أخطائي — الأحدث أولاً.
    final mistakeRows = await (db.select(db.mistakeRows)
          ..orderBy([(t) => OrderingTerm.desc(t.atMs)]))
        .get();
    final mistakes = [
      for (final m in mistakeRows)
        MistakeRecord(
          questionId: m.questionId,
          chosenIndex: m.chosenIndex,
          correctIndex: m.correctIndex,
          atMs: m.atMs,
        ),
    ];

    // حالات البطاقات.
    final cardRows = await db.select(db.cardStateRows).get();
    final cardStates = {
      for (final c in cardRows)
        c.cardId: CardStateData(
          cardId: c.cardId,
          difficulty: c.difficulty,
          stability: c.stability,
          reviews: c.reviews,
          lapses: c.lapses,
          dueDateKey: c.dueDateKey,
        ),
    };

    // طابور بطاقات اليوم (صف مفرد).
    final dayRow = await (db.select(db.cardDayRows)
          ..where((t) => t.id.equals(_singletonId)))
        .getSingleOrNull();
    final cardDay = dayRow == null
        ? null
        : CardDayState(
            dateKey: dayRow.dateKey,
            queue:
                (jsonDecode(dayRow.queueJson) as List<dynamic>).cast<int>(),
            doneCount: dayRow.doneCount,
            finished: dayRow.finished,
          );

    // أيام تحدّي المختبر + مفتاح النابض المفرد (من جدول الإعدادات).
    final labRows = await db.select(db.labChallengeRows).get();
    final labDays = {for (final l in labRows) l.experimentId: l.dateKey};
    final labSpring = await _getSetting('labChallengeDoneDateKey');

    return TrainingData(
      daily: daily,
      mistakes: mistakes,
      cardStates: cardStates,
      cardDay: cardDay,
      labChallengeDoneDateKey: labSpring,
      labChallengeDays: labDays,
    );
  }

  @override
  Future<void> save(TrainingData data) async {
    await db.transaction(() async {
      // دفعة اليوم.
      await db.delete(db.dailyBatchRows).go();
      final d = data.daily;
      if (d != null) {
        await db.into(db.dailyBatchRows).insert(
              DailyBatchRowsCompanion.insert(
                id: const Value(_singletonId),
                dateKey: d.dateKey,
                orderJson: jsonEncode(d.order),
                answersJson: Value(jsonEncode(
                    {for (final e in d.answers.entries) '${e.key}': e.value})),
                done: Value(d.done),
                score: Value(d.score),
              ),
            );
      }

      // أخطائي.
      await db.delete(db.mistakeRows).go();
      for (final m in data.mistakes) {
        await db.into(db.mistakeRows).insert(
              MistakeRowsCompanion.insert(
                questionId: m.questionId,
                chosenIndex: m.chosenIndex,
                correctIndex: m.correctIndex,
                atMs: m.atMs,
              ),
            );
      }

      // حالات البطاقات.
      await db.delete(db.cardStateRows).go();
      for (final c in data.cardStates.values) {
        await db.into(db.cardStateRows).insert(
              CardStateRowsCompanion.insert(
                cardId: c.cardId,
                difficulty: c.difficulty,
                stability: c.stability,
                reviews: Value(c.reviews),
                lapses: Value(c.lapses),
                dueDateKey: c.dueDateKey,
              ),
            );
      }

      // طابور اليوم.
      await db.delete(db.cardDayRows).go();
      final cd = data.cardDay;
      if (cd != null) {
        await db.into(db.cardDayRows).insert(
              CardDayRowsCompanion.insert(
                id: const Value(_singletonId),
                dateKey: cd.dateKey,
                queueJson: jsonEncode(cd.queue),
                doneCount: Value(cd.doneCount),
                finished: Value(cd.finished),
              ),
            );
      }

      // أيام تحدّي المختبر.
      await db.delete(db.labChallengeRows).go();
      for (final e in data.labChallengeDays.entries) {
        await db.into(db.labChallengeRows).insert(
              LabChallengeRowsCompanion.insert(
                experimentId: e.key,
                dateKey: e.value,
              ),
            );
      }

      // مفتاح النابض المفرد.
      await _setSetting(
          'labChallengeDoneDateKey', data.labChallengeDoneDateKey);
    });
  }

  Future<String?> _getSetting(String key) async {
    final row = await (db.select(db.settingsRows)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSetting(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.settingsRows)..where((t) => t.key.equals(key))).go();
      return;
    }
    await db.into(db.settingsRows).insertOnConflictUpdate(
          SettingsRowsCompanion.insert(key: key, value: value),
        );
  }
}

// ── دفتر XP (Append-only منطقياً — لقطة كاملة تُكتب بترتيب seq) ─────────
class DriftXpEventStore implements XpEventStore {
  DriftXpEventStore(this.db);
  final AppDatabase db;

  @override
  Future<List<XpEvent>> loadEvents() async {
    final rows = await (db.select(db.xpEventRows)
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .get();
    return [
      for (final r in rows)
        XpEvent(
          seq: r.seq,
          type: r.type,
          tsMs: r.tsMs,
          payload: (jsonDecode(r.payloadJson) as Map<String, dynamic>),
          prevHash: r.prevHash,
          hash: r.hash,
          sigB64: r.sigB64,
        ),
    ];
  }

  @override
  Future<void> saveEvents(List<XpEvent> events) async {
    await db.transaction(() async {
      await db.delete(db.xpEventRows).go();
      for (final e in events) {
        await db.into(db.xpEventRows).insert(
              XpEventRowsCompanion.insert(
                seq: e.seq,
                type: e.type,
                tsMs: e.tsMs,
                payloadJson: Value(jsonEncode(e.payload)),
                prevHash: e.prevHash,
                hash: e.hash,
                sigB64: e.sigB64,
              ),
            );
      }
    });
  }
}
