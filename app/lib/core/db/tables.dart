/// F3.1 — مخطط Drift الكامل للقاعدة المحلية المشفّرة (قرار ٣٠: قاعدة محلية
/// مشفّرة SQLCipher). هذا الملف يعرّف **الجداول فقط** — تعريفات خالصة بلا
/// منطق، ليُولّد `drift_dev` منها `app_database.g.dart`.
///
/// نطاق البند (docs/14 §١٢ — F3.1): منهاج/تقدم · أخطائي · بطاقات + حالة FSRS ·
/// دفتر XP · سلسلة · إعدادات. الجداول أدناه تُغطّي هذه المجالات بحيث تحلّ محل
/// مفاتيح `shared_preferences` المسلسلة (progress_v1 · training_v1 · xpledger_v1
/// …) خلف **نفس الواجهات المجرّدة** (ProgressStore/TrainingStore/XpEventStore)
/// دون كسر أي عقد قائم.
///
/// ⚠️ لا يُشغَّل هنا: توليد الكود (`build_runner`) يتم على جهاز المالك (قرار ٥١).
library;

import 'package:drift/drift.dart';

// ── تقدّم القراءة (يحلّ محل progress_v1) ─────────────────────────────
/// صف لكل فصل: الموضع المحفوظ (cursor) وهل اكتمل.
/// المفتاح الأولي = معرّف الفصل (chapterId) النصّي من الحزمة.
class ChapterProgressRows extends Table {
  TextColumn get chapterId => text()();
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {chapterId};
}

// ── دفعة التدريب اليومية (يحلّ محل الجزء daily من training_v1) ────────
/// صفّ واحد فقط (id ثابت = 1) يحمل حالة دفعة اليوم القابلة للاستئناف.
/// الحقول المركّبة (order/answers) تُخزَّن JSON نصّياً — دفعة اليوم كيان واحد
/// يُقرأ/يُكتب ذرّياً، فلا فائدة من تطبيعه لصفوف.
class DailyBatchRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get dateKey => text()();
  TextColumn get orderJson => text()(); // List<int> مُسلسل
  TextColumn get answersJson => text().withDefault(const Constant('{}'))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get score => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── أرشيف الأخطاء «أخطائي» (يحلّ محل mistakes من training_v1) ─────────
/// صف لكل سؤال أخطأ فيه الطالب — الأحدث محل الأقدم لنفس السؤال
/// (المفتاح الأولي questionId يضمن ذلك عبر upsert).
class MistakeRows extends Table {
  IntColumn get questionId => integer()();
  IntColumn get chosenIndex => integer()();
  IntColumn get correctIndex => integer()();
  IntColumn get atMs => integer()(); // للترتيب الزمني التنازلي

  @override
  Set<Column<Object>> get primaryKey => {questionId};
}

// ── حالة ذاكرة البطاقات FSRS (يحلّ محل cardStates من training_v1) ─────
/// صف لكل بطاقة: نموذج DSR (صعوبة/ثبات) + عدّادات + يوم الاستحقاق.
class CardStateRows extends Table {
  IntColumn get cardId => integer()();
  RealColumn get difficulty => real()(); // D ∈ [1,10]
  RealColumn get stability => real()(); // S بالأيام
  IntColumn get reviews => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  TextColumn get dueDateKey => text()(); // 'YYYY-MM-DD'

  @override
  Set<Column<Object>> get primaryKey => {cardId};
}

// ── طابور بطاقات اليوم (يحلّ محل cardDay من training_v1) ──────────────
/// صفّ واحد (id=1) — الطابور مجمّد عند أول بناء لعدالة مهام اليوم.
class CardDayRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get dateKey => text()();
  TextColumn get queueJson => text()(); // List<int> مُسلسل
  IntColumn get doneCount => integer().withDefault(const Constant(0))();
  BoolColumn get finished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── أيام تحدّي المختبر (يحلّ محل labChallengeDays من training_v1) ─────
/// صف لكل تجربة: آخر يوم أُنجز فيه تحدّيها (+١٠ بسقف يومي).
class LabChallengeRows extends Table {
  TextColumn get experimentId => text()();
  TextColumn get dateKey => text()();

  @override
  Set<Column<Object>> get primaryKey => {experimentId};
}

// ── دفتر XP الموقّع (يحلّ محل xpledger_v1) ───────────────────────────
/// Append-only منطقياً: صف لكل حدث بترتيب seq بلا فجوات (docs/12 §٤.٢).
/// سلسلة الهاش والتوقيع تُحفظ حرفياً كما تُنتجها النواة — Drift مجرّد ناقل.
class XpEventRows extends Table {
  IntColumn get seq => integer()(); // تسلسل من 1
  TextColumn get type => text()();
  IntColumn get tsMs => integer()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  TextColumn get prevHash => text()();
  TextColumn get hash => text()();
  TextColumn get sigB64 => text()();

  @override
  Set<Column<Object>> get primaryKey => {seq};
}

// ── إعدادات عامة key/value (settings — البند يذكر «إعدادات») ──────────
/// جدول مفتاح/قيمة نصّي عام لأي إعداد مفرد لا يستحق جدولاً (الثيم، أعلام،
/// مفاتيح يوم مفردة مثل labChallengeDoneDateKey للنابض). يبقى مرناً للترحيل.
class SettingsRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
