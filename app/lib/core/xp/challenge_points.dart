/// A5 — نقاط التحدي التناقصية (قرار ٦٠).
///
/// القاعدة: «مؤقّت لكل سؤال + نقاط تناقصية مع الزمن داخل المهلة».
/// هذه الدالة **حتمية وصحيحة عدد صحيح**، وهي المنسوخة حرفياً في
/// `supabase/functions/verify_xp_events/index.ts` — أي اختلاف بين
/// النسختين ⇒ السيرفر يرفض الدفعة كلها (`POINTS_MISMATCH:challengeQ`).
///
/// الصيغة (عدد صحيح — لا فواصل عائمة حتى لا تختلف Dart عن TS):
/// ```
///   elapsed >= budget   ⇒  0            (انتهى الوقت بلا إجابة = بلا نقاط)
///   غير ذلك             ⇒  min + (base − min) × (budget − elapsed) ÷ budget
/// ```
/// القسمة مقطوعة نحو الصفر في الطرفين (`~/` في Dart · `Math.trunc` في TS)
/// والقيم موجبة دائماً ⇒ النتيجة متطابقة بتّياً.
library;

/// صنف سؤال داخل التحدي — المهلة والنقاط بحسب نوع السؤال (قرار ٦٠/٦١).
class ChallengeKind {
  const ChallengeKind({
    required this.id,
    required this.base,
    required this.minPoints,
    required this.budgetMs,
  });

  final String id;

  /// النقاط عند إجابة فورية (الزمن = صفر).
  final int base;

  /// أقل نقاط تُمنح عند الإجابة في آخر لحظة من المهلة.
  final int minPoints;

  /// المهلة بالميلي ثانية.
  final int budgetMs;
}

/// اختياري من متعدد — ٢٢ ثانية (النطاق الذي حدّده المالك: ٢٠–٢٥ ث).
const ChallengeKind kChallengeMcq =
    ChallengeKind(id: 'mcq', base: 12, minPoints: 4, budgetMs: 22000);

/// خطوة من مسألة مقطّعة على سلم التصحيح (علاقة/تعويض/نتيجة/وحدة — قرار ٦١/أ).
const ChallengeKind kChallengeStep =
    ChallengeKind(id: 'step', base: 18, minPoints: 6, budgetMs: 40000);

/// مسألة رقمية بمعطيات متغيرة لكل طالب — ٩٠ ثانية (قرار ٦١/ب).
const ChallengeKind kChallengeNumeric =
    ChallengeKind(id: 'numeric', base: 30, minPoints: 10, budgetMs: 90000);

/// الأصناف الثلاثة بالترتيب — نفس الترتيب على السيرفر.
const List<ChallengeKind> challengeKinds = <ChallengeKind>[
  kChallengeMcq,
  kChallengeStep,
  kChallengeNumeric,
];

/// الصنف بمعرّفه — `null` إن كان مجهولاً (⇒ رفض).
ChallengeKind? challengeKindOf(String id) {
  for (final k in challengeKinds) {
    if (k.id == id) return k;
  }
  return null;
}

/// النقاط التناقصية لسؤال أُجيب بعد `elapsedMs` من بدء عرضه.
///
/// - `elapsedMs < 0` ⇒ ٠ (زمن غير منطقي).
/// - `elapsedMs >= budgetMs` ⇒ ٠ — «لا نقاط بلا إجابة صحيحة»: من انتهى
///   وقته بلا إجابة لا يأخذ شيئاً.
int challengePoints({required ChallengeKind kind, required int elapsedMs}) {
  if (elapsedMs < 0) return 0;
  if (elapsedMs >= kind.budgetMs) return 0;
  final span = kind.base - kind.minPoints;
  final remaining = kind.budgetMs - elapsedMs;
  return kind.minPoints + (span * remaining) ~/ kind.budgetMs;
}
