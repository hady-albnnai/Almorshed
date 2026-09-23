/// F3.1 — اختبارات الترحيل لمرة واحدة من KV القديم إلى Drift.
/// كلها على قاعدة ذاكرة + مخازن قديمة بالذاكرة (InMemory*) — بلا جهاز.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/db/app_database.dart';
import 'package:fizya_clash/core/db/drift_stores.dart';
import 'package:fizya_clash/core/db/legacy_migration.dart';
import 'package:fizya_clash/core/progress/progress_store.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/core/xp/xp_event.dart';
import 'package:fizya_clash/core/xp/xp_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  LegacyMigration build({
    ReadProgress? progress,
    TrainingData? training,
    List<XpEvent>? events,
  }) =>
      LegacyMigration(
        db: db,
        legacyProgress: InMemoryProgressStore()
          ..save(progress ?? const ReadProgress()),
        legacyTraining: InMemoryTrainingStore()
          ..save(training ?? const TrainingData()),
        legacyXp: InMemoryXpEventStore(events),
      );

  test('ينسخ التقدّم والتدريب ودفتر XP القديمة إلى Drift', () async {
    final m = build(
      progress: const ReadProgress(chapters: {
        'U1C1': ChapterProgress(cursor: 4, completed: true),
      }),
      training: const TrainingData(
        mistakes: [
          MistakeRecord(
              questionId: 7, chosenIndex: 1, correctIndex: 2, atMs: 50),
        ],
      ),
      events: [
        const XpEvent(
          seq: 1,
          type: 'batchDone',
          tsMs: 900,
          payload: {'points': 15},
          prevHash: genesisPrevHash,
          hash: 'h1',
          sigB64: 's1',
        ),
      ],
    );

    final ran = await m.runIfNeeded();
    expect(ran, isTrue);

    expect((await DriftProgressStore(db).load()).chapters['U1C1']!.cursor, 4);
    expect((await DriftTrainingStore(db).load()).mistakes.single.questionId, 7);
    expect((await DriftXpEventStore(db).loadEvents()).single.hash, 'h1');
  });

  test('idempotent — لا يعيد الترحيل مرتين', () async {
    final m = build(
      progress: const ReadProgress(
          chapters: {'A': ChapterProgress(cursor: 1)}),
    );
    expect(await m.runIfNeeded(), isTrue);
    expect(await m.alreadyMigrated(), isTrue);
    // نداء ثانٍ ⇒ لا عمل (false).
    expect(await m.runIfNeeded(), isFalse);
  });

  test('لا يدوس بيانات Drift الموجودة إن كان KV القديم فارغاً', () async {
    // اكتب في Drift مباشرة ثم شغّل ترحيلاً بمصدر قديم فارغ.
    await DriftProgressStore(db).save(const ReadProgress(
        chapters: {'X': ChapterProgress(cursor: 9, completed: true)}));
    final m = build(); // كل المصادر فارغة
    expect(await m.runIfNeeded(), isTrue); // نُفّذ (رفع العلم) لكن بلا نسخ
    // بيانات Drift سليمة لم تُمسح.
    expect((await DriftProgressStore(db).load()).chapters['X']!.cursor, 9);
  });

  test('العلم وحده يُرفع حتى لو كل المصادر فارغة', () async {
    final m = build();
    expect(await m.alreadyMigrated(), isFalse);
    await m.runIfNeeded();
    expect(await m.alreadyMigrated(), isTrue);
  });
}
