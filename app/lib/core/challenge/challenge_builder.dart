/// A5 — تحدي اليوم (قرار ٦٠): جلسة حتمية + معرّف ثابت يُتحقَّق خادمياً.
///
/// لماذا المعرّف حتمي؟ السيرفر يمنح النقاط مرة واحدة لكل
/// (جهاز · challengeId · qIndex). لو كان المعرّف عشوائياً لاستطاع الطالب
/// إعادة التحدي مراتٍ بلا حصر. الحتمية من (معرّف الجهاز ⊕ مفتاح اليوم)
/// ⇒ نفس التحدي صباحاً ومساءً، وتكراره لا يفتح باباً جديداً للنقاط.
library;

import '../content/models.dart';
import '../rng/session.dart';
import '../rng/splitmix64.dart';
import '../training/batch_builder.dart' show dayNumberOf; // مفتاح اليوم ← رقمه

/// عدد أسئلة تحدي اليوم.
const int kChallengeLength = 10;

/// نتيجة البناء: المفتاح + المعرّف + الجلسة (الترتيب وخيارات كل سؤال).
class DailyChallenge {
  const DailyChallenge({
    required this.dateKey,
    required this.id,
    required this.session,
  });

  final String dateKey;

  /// معرّف التحدي بصيغة UUID — حتمي من (deviceId ⊕ مفتاح اليوم).
  final String id;

  final BuiltSession session;
}

/// معرّف تحدي بصيغة UUID (8-4-4-4-12) — حتمي كلياً.
///
/// ⚠️ `BigInt.from(x).toUnsigned(64)` إلزامي: `int.toUnsigned(64)` على
/// `int` هو NO-OP (موقّع 64بت لا يمثّل ≥2⁶³) — درس مثبّت في `rng/session.dart`.
String challengeIdFor({required int deviceId, required String dateKey}) {
  final rng = SplitMix64(SplitMix64.mix64(
    deviceId ^ dayNumberOf(dateKey) ^ 0xC7A11E, // تيار مستقل عن دفعة اليوم
  ));
  final a = BigInt.from(rng.next()).toUnsigned(64).toRadixString(16).padLeft(16, '0');
  final b = BigInt.from(rng.next()).toUnsigned(64).toRadixString(16).padLeft(16, '0');
  return '${a.substring(0, 8)}-${a.substring(8, 12)}-'
      '${a.substring(12, 16)}-${b.substring(0, 4)}-${b.substring(4, 16)}';
}

/// بناء تحدي اليوم من البنك **المعتمد** حصراً (قرار ٢٤).
///
/// يرجع `null` إن لم يوجد بنك معتمد — الشاشة تعرض رسالة انتظار.
/// البذرة Different من دفعة التدريب (`0xC7A11E`) حتى لا يتطابق التحدي
/// مع دفعة اليوم سؤالاً بسؤال.
DailyChallenge? buildDailyChallenge(
  ContentPack pack, {
  required String dateKey,
  int deviceId = 0,
  int count = kChallengeLength,
}) {
  final approved = pack.approvedQuestions;
  if (approved.isEmpty) return null;
  final n = count < approved.length ? count : approved.length;

  final chapterIndex = <String, int>{};
  for (final u in pack.units) {
    for (final c in u.chapters) {
      if (!chapterIndex.containsKey(c.id)) {
        chapterIndex[c.id] = chapterIndex.length;
      }
    }
  }

  final chapterOf = <int, int>{};
  final optionsOf = <int, List<int>>{};
  for (final q in approved) {
    chapterOf[q.id] = chapterIndex[q.chapter] ?? 0;
    optionsOf[q.id] = List<int>.generate(q.options.length, (i) => i);
  }

  final seed = SplitMix64.mix64(
    deviceId ^ dayNumberOf(dateKey) ^ 0xC7A11E,
  );

  final session = buildSession(SessionSpec(
    seed: seed,
    count: n,
    bankIds: approved.map((q) => q.id).toList(),
    chapterOf: chapterOf,
    optionsOf: optionsOf,
  ));

  return DailyChallenge(
    dateKey: dateKey,
    id: challengeIdFor(deviceId: deviceId, dateKey: dateKey),
    session: session,
  );
}
