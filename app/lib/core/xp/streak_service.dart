/// F3.8 — السلسلة اليومية (docs/12 §٥ حرفياً) + مُسجِّل الأحداث الموحد.
/// اليوم الدراسي = من ٤:٠٠ فجراً إلى ٤:٠٠ فجر اليوم التالي (توقيت الجهاز)
/// — سماحية ليلة السهر الدراسية. السلسلة تُحتسب من أحداث الدفتر ذاتها،
/// وأول نشاط باليوم يمنح «سلسلة اليوم» +١٠ تلقائياً (قرار الجسر F3.7→F3.8).
library;

import '../../core/training/batch_builder.dart';
import '../../core/xp/xp_event.dart';
import '../../core/xp/xp_ledger.dart';
import '../../core/xp/xp_store.dart';
import '../../core/xp/xp_signer.dart';

/// مفتاح اليوم الدراسي: لحظة الزمن نُنزلها ٤ ساعات ثم مفتاح اليوم —
/// فأي لحظة قبل ٤ فجر تعود لليوم السابق (نفس دالة المفاتيح القائمة
/// ⇒ اتساق كامل مع بقية الخدمات).
String studyDateKeyOf(DateTime dt) =>
    dateKeyOf(dt.subtract(const Duration(hours: 4)));

/// لقطة السلسلة للعرض.
class StreakInfo {
  const StreakInfo(this.days, {this.todayDone = false});
  final int days; // الأيام المتتالية النشطة حتى أمس أو اليوم
  final bool todayDone; // هل سُجّل نشاط اليوم الدراسي الحالي؟
}

/// حساب السلسلة من أحداث الدفتر (بأطوابها الزمنية حصراً):
/// اليوم نشط ⇒ نعدّ رجوعاً من اليوم؛ غير نشط ⇒ نعدّ من أمس
/// (السلسلة تبقى حية حتى يُنجز شيئاً اليوم — لا تنكسر بفراغ صباح).
StreakInfo computeStreak(List<XpEvent> events, DateTime now) {
  final keys = <String>{
    for (final e in events) studyDateKeyOf(DateTime.fromMillisecondsSinceEpoch(e.tsMs)),
  };
  final todayKey = studyDateKeyOf(now);
  final todayNum = dayNumberOf(todayKey);
  var cursor = todayNum;
  if (!keys.contains(todayKey)) {
    final yesterday = dateKeyFromDayNumber(todayNum - 1);
    if (!keys.contains(yesterday)) return StreakInfo(0, todayDone: false);
    cursor = todayNum - 1;
  }
  var days = 0;
  while (keys.contains(dateKeyFromDayNumber(cursor))) {
    days++;
    cursor--;
  }
  return StreakInfo(days, todayDone: keys.contains(todayKey));
}

/// أفكار اليوم — تدور حتماً بمفتاح اليوم الدراسي (مادة المنهاج نفسها).
const List<String> dailyFacts = [
  'في الاهتزاز التوافقي البسيط، القوة راجعة ومتناسبة مع الإزاحة: F = −k·x',
  'دور النواس البسيط يعتمد على طوله فقط: T = 2π·√(L/g) — الكتلة لا تدخل',
  'عند الرنين يتساوى تردد القوة الدافعة مع التردد الطبيعي فتتضخم السعة',
  'الموجة تنقل الطاقة دون انتقال المادة — الجزيئات تهتز حول مواضع توازنها',
  'سرعة الموجة على الحبل تزداد بازدياد الشد: v = √(F/μ)',
  'الصوت أسرع في الماء من الهواء — والضوء أسرع في الفراغ من كل الأوساط',
  'التيار المستمر ثابت الاتجاه، والمتناوب يقلب اتجاهه دورياً بتردد الشبكة',
  'المحوّل يرفع أو يخفض الجهد المتناوب — والقدرة الداخلة تساوي الخارجة عملياً',
  'الديود يمرر التيار باتجاه واحد — قلب الراديو والشواحن',
  'المقاومة النوعية لمادة السلك لا تعتمد على طوله ولا على سماكته',
];

/// فكرة اليوم الحتماً من مفتاح اليوم الدراسي.
String factForDay(String studyDateKey) =>
    dailyFacts[dayNumberOf(studyDateKey) % dailyFacts.length];

/// واجهة مريحة للمنتجات: تسجّل الحدث وتشعل «سلسلة اليوم» تلقائياً
/// بأول نشاط (السقف اليومي يحمي من التكرار — الجسر F3.7→F3.8).
class XpRecorder {
  XpRecorder({required XpEventStore store, required XpKeyVault vault})
      : ledger = XpLedgerService(store: store, vault: vault);

  /// الإنتاج: تخزين مشترك + خزنة آمنة.
  XpRecorder.shared()
      : ledger = XpLedgerService(
            store: SharedPrefsXpEventStore(), vault: SecureXpKeyVault());

  /// اختبارات: كل شيء بالذاكرة.
  XpRecorder.inMemory()
      : ledger = XpLedgerService(
            store: InMemoryXpEventStore(), vault: InMemoryXpKeyVault());

  final XpLedgerService ledger;

  Future<bool> record(
    String typeId, {
    Map<String, dynamic>? extra,
    int? pointsOverride,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final key = studyDateKeyOf(ts);
    final r = await ledger.append(
      typeId: typeId,
      dateKey: key,
      extra: extra,
      pointsOverride: pointsOverride,
      tsMsOverride: ts.millisecondsSinceEpoch,
    );
    if (!r.ok) return false;
    if (typeId != xpStreakDay.id) {
      // أول نشاط باليوم يشعل السلسلة — والسقف اليومي يمنع التكرار
      await ledger.append(
        typeId: xpStreakDay.id,
        dateKey: key,
        tsMsOverride: ts.millisecondsSinceEpoch,
      );
    }
    return true;
  }
}
