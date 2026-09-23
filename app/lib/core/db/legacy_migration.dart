/// F3.1 — ترحيل لمرة واحدة من `shared_preferences` القديمة إلى قاعدة Drift
/// المشفّرة. الهدف: **لا يفقد أي طالب تقدّمه** عند التحديث للنسخة المشفّرة.
///
/// المبدأ (idempotent — آمن للتكرار):
///   • علم `migrated_from_prefs_v1` في جدول الإعدادات يمنع التكرار.
///   • يُقرأ كل مصدر KV القديم مرة واحدة (progress_v1 / training_v1 /
///     xpledger_v1) ويُكتب في مخازن Drift المقابلة، ثم يُرفع العلم.
///   • **لا يمسح** بيانات KV القديمة (تبقى احتياطاً صامتاً — لا ضرر منها).
///   • أي مصدر فارغ أو تالف يُتجاوز بأمان (المخازن القديمة أصلاً ترجع فارغاً
///     عند التلف) — الترحيل لا ينهار أبداً.
///
/// يُستدعى مرة عند الإقلاع قبل استعمال مخازن Drift (main.dart).
library;

import '../progress/progress_store.dart';
import '../training/training_store.dart';
import '../xp/xp_store.dart';
import 'app_database.dart';
import 'drift_stores.dart';

/// مفتاح علم اكتمال الترحيل في جدول الإعدادات.
const String kMigratedFlagKey = 'migrated_from_prefs_v1';

/// ينفّذ الترحيل مرة واحدة. المصادر القديمة والوجهات تُحقن ليَسهُل الاختبار
/// (الإنتاج يمرّر SharedPrefs* للمصادر ومخازن Drift للوجهات).
class LegacyMigration {
  LegacyMigration({
    required this.db,
    required this.legacyProgress,
    required this.legacyTraining,
    required this.legacyXp,
    DriftProgressStore? driftProgress,
    DriftTrainingStore? driftTraining,
    DriftXpEventStore? driftXp,
  })  : driftProgress = driftProgress ?? DriftProgressStore(db),
        driftTraining = driftTraining ?? DriftTrainingStore(db),
        driftXp = driftXp ?? DriftXpEventStore(db);

  final AppDatabase db;

  /// المصادر القديمة (shared_preferences في الإنتاج).
  final ProgressStore legacyProgress;
  final TrainingStore legacyTraining;
  final XpEventStore legacyXp;

  /// الوجهات (Drift).
  final DriftProgressStore driftProgress;
  final DriftTrainingStore driftTraining;
  final DriftXpEventStore driftXp;

  /// هل اكتمل الترحيل سابقاً؟
  Future<bool> alreadyMigrated() async {
    final row = await (db.select(db.settingsRows)
          ..where((t) => t.key.equals(kMigratedFlagKey)))
        .getSingleOrNull();
    return row?.value == 'true';
  }

  /// ينفّذ الترحيل إن لم يكن قد اكتمل. يعيد true لو نُفّذ الآن، false لو
  /// كان قد اكتمل مسبقاً (لا عمل).
  Future<bool> runIfNeeded() async {
    if (await alreadyMigrated()) return false;

    // (1) تقدّم القراءة — انسخ فقط إن كان فيه فصول (لا تدُس بيانات Drift موجودة).
    final prog = await legacyProgress.load();
    if (prog.chapters.isNotEmpty) {
      await driftProgress.save(prog);
    }

    // (2) التدريب — انسخ فقط إن كان فيه محتوى فعلي.
    final training = await legacyTraining.load();
    if (_trainingHasData(training)) {
      await driftTraining.save(training);
    }

    // (3) دفتر XP — انسخ فقط إن كان فيه أحداث.
    final events = await legacyXp.loadEvents();
    if (events.isNotEmpty) {
      await driftXp.saveEvents(events);
    }

    // (4) ارفع العلم — يمنع أي تكرار لاحق.
    await db.into(db.settingsRows).insertOnConflictUpdate(
          SettingsRowsCompanion.insert(key: kMigratedFlagKey, value: 'true'),
        );
    return true;
  }

  static bool _trainingHasData(TrainingData t) =>
      t.daily != null ||
      t.mistakes.isNotEmpty ||
      t.cardStates.isNotEmpty ||
      t.cardDay != null ||
      t.labChallengeDoneDateKey != null ||
      t.labChallengeDays.isNotEmpty;
}
