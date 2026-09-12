/// F3.3 — بنّاء دفعة اليوم: بذرة يومية حتمية فوق محرك الجلسة (docs/12 §٢).
/// المعتمد حصراً (قرار ٢٤) + توازن الفصول round-robin + خلط خيارات حتمي.
library;

import '../content/models.dart';
import '../rng/session.dart';
import '../rng/splitmix64.dart';

/// نتيجة البناء: مفتاح اليوم + الجلسة المبنية (ترتيب الأسئلة وخياراتها).
class DailyBatch {
  const DailyBatch({required this.dateKey, required this.session});

  final String dateKey;
  final BuiltSession session;
}

/// مفتاح اليوم المحلي 'YYYY-MM-DD' — التناوب عند منتصف الليل المحلي.
String dateKeyOf(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// رقم اليوم المحلي → مفتاح اليوم (عكس dayNumberOf).
String dateKeyFromDayNumber(int dayNumber) {
  final d =
      DateTime.utc(1970).add(Duration(days: dayNumber));
  return dateKeyOf(d);
}

/// مفتاح اليوم بعد إزاحة أيام (موجبة = المستقبل).
String dateKeyAfter(String dateKey, int days) =>
    dateKeyFromDayNumber(dayNumberOf(dateKey) + days);

/// تحليل مفتاح اليوم إلى رقم اليوم المحلي (أيام منذ الإيبخ).
/// ⚠️ DateTime.utc إلزامي — DateTime العادي محلي فتنزيح الأيام بالمناطق
/// UTC+3 وتُكسر حتمية البذرة بين الأجهزة (docs/12: أيام الإيبخ = UTC).
int dayNumberOf(String dateKey) {
  final parts = dateKey.split('-');
  final d =
      DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  return d.millisecondsSinceEpoch ~/ 86400000;
}

/// بذرة اليوم — docs/12 §٢.١: mix64(deviceId ⊕ toDays).
/// ⇒ دفعة اليوم واحدة صباحاً ومساءً (إعادة الفتح لا تغيّر الأسئلة).
/// المعطيات غير سالبة دائماً (رقم اليوم ~20700 وجهاز صغير) فالـXOR آمن.
int dailySeed({required int deviceId, required String dateKey}) =>
    SplitMix64.mix64(deviceId ^ dayNumberOf(dateKey));

/// بناء دفعة اليوم من البنك المعتمد حصراً.
/// يرجع null إذا لا أسئلة معتمدة (شاشة الانتظار — قرار ٢٤).
/// الحتمية: نفس (dateKey, deviceId, بنك) ⇒ نفس الترتيب كلياً.
/// (الحزمة معامل موضعي أول — بقية المعاملات مسماة.)
DailyBatch? buildDailyBatch(
  ContentPack pack, {
  required String dateKey,
  int deviceId = 0,
  int count = 10,
}) {
  final approved = pack.approvedQuestions;
  if (approved.isEmpty) return null;
  final n = count < approved.length ? count : approved.length;

  // فهرس متتالٍ لكل فصل (للتوازن فقط — لا معنى رقمياً خارج الجلسة).
  final chapterIndex = <String, int>{};
  for (final u in pack.units) {
    for (final c in u.chapters) {
      if (!chapterIndex.containsKey(c.id)) chapterIndex[c.id] = chapterIndex.length;
    }
  }

  final chapterOf = <int, int>{};
  final optionsOf = <int, List<int>>{};
  for (final q in approved) {
    chapterOf[q.id] = chapterIndex[q.chapter] ?? 0;
    // «معرفات الخيارات» هنا فهارس أصلية — الخلط يعيد ترتيبها حتماً.
    optionsOf[q.id] = List<int>.generate(q.options.length, (i) => i);
  }

  final session = buildSession(SessionSpec(
    seed: dailySeed(deviceId: deviceId, dateKey: dateKey),
    count: n,
    bankIds: approved.map((q) => q.id).toList(),
    chapterOf: chapterOf,
    optionsOf: optionsOf,
  ));

  return DailyBatch(dateKey: dateKey, session: session);
}

/// فهرس الإجابة الصحيحة بالعرض بعد خلط الخيارات.
int displayCorrectIndex(Question q, List<int> optionOrder) =>
    optionOrder.indexOf(q.correctIndex);
