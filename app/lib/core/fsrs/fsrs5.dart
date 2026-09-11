import 'dart:math' as math;

/// FSRS-5 — خوارزمية التكرار المتباعد لبطاقات الملخصات (قرار ٤٢ · docs/12 §٣).
///
/// الصيغ من التنفيذ المرجعي الموثق (jakob.space FSRS-5 — docs/12 §٩) — الأوزان
/// الافتراضية W مدرَّبة على ملايين المراجعات (Anki). كل الأرقام double حتمية.
///
/// أزرارنا الثلاثة ← Grades: 😅 ما عرفتها=1 (again) · 😔 بصعوبة=2 (hard) ·
/// 😎 أعرفها=3 (good) — استبعاد easy=4 عمداً (قرار ٤٢).
library;

/// حالة الذاكرة لبطاقة واحدة (نموذج DSR).
class CardMemory {
  CardMemory.newCard()
      : difficulty = 5.0, // الافتراضي المرجعي
        stability = 0,
        reviews = 0,
        lapses = 0;

  /// الصعوبة D ∈ [1,10].
  double difficulty;

  /// الثبات S: الأيام حتى هبوط الاسترجاع إلى ٩٠٪ (0 = بطاقة جديدة).
  double stability;

  int reviews;
  int lapses;

  bool get isNew => stability <= 0;
}

/// التقدير الذاتي — مطابق لأزرار الواجهة الثلاثة.
enum Grade { again, hard, good }

abstract final class Fsrs5 {
  /// الأوزان الافتراضية الـ19 (المرجع الموثق — docs/12 §٩).
  static const List<double> w = [
    0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
    1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
    2.9898, 0.51655, 0.6621,
  ];

  static const double _f = 19.0 / 81.0;
  static const double _c = -0.5;

  /// سقف تطبيقي للفترة (أيام) — الموسم ينتهي قبل الامتحان؛ يُراجع في F3.4.
  static const double maxIntervalDays = 180;

  /// قابلية الاسترجاع بعد t يوماً لبطاقة ثباتها S.
  static double retrievability(double tDays, double stability) =>
      math.pow(1.0 + _f * (tDays / stability), _c).toDouble();

  /// الثبات الأولي حسب التقدير (again→W0 · hard→W1 · good→W2).
  static double initialStability(Grade g) => w[g.index];

  static double _stabilitySuccess(double d, double s, double r, Grade g) {
    final tD = 11.0 - d;
    final tS = math.pow(s, -w[9]).toDouble();
    final tR = math.exp(w[10] * (1.0 - r)) - 1.0;
    final h = g == Grade.hard ? w[15] : 1.0;
    final c = math.exp(w[8]);
    return s * (1.0 + tD * tS * tR * h * c);
  }

  static double _stabilityFail(double d, double s, double r) {
    final dF = math.pow(d, -w[12]).toDouble();
    final sF = math.pow(s + 1.0, w[13]).toDouble() - 1.0;
    final rF = math.exp(w[14] * (1.0 - r));
    final result = dF * sF * rF * w[11];
    return result < s ? result : s;
  }

  static double _d0(int g) =>
      _clampD(w[4] - math.exp(w[5] * (g - 1)) + 1.0);

  static double _difficultyNext(double d, Grade g) {
    final delta = -w[6] * (g.index + 1 - 3.0);
    final dp = d + delta * ((10.0 - d) / 9.0);
    return _clampD(w[7] * _d0(4) + (1.0 - w[7]) * dp);
  }

  /// الفترة القادمة (أيام) عند هدف استبقاء R.
  static double intervalAt(double targetR, double stability) =>
      (stability / _f) *
      (math.pow(targetR, 1.0 / _c).toDouble() - 1.0);

  /// التطبيق الكامل: مراجعة بطاقة — elapsedDays أيام منذ آخر مراجعة
  /// (0 للبطاقة الجديدة) — يعيد الحالة الجديدة (الحالة القديمة لا تُعدَّل).
  static CardMemory review(CardMemory card, Grade g, {double elapsedDays = 0}) {
    final next = CardMemory.newCard()
      ..reviews = card.reviews + 1
      ..lapses = card.lapses;

    if (card.isNew) {
      next.stability = initialStability(g);
      next.difficulty = _difficultyNext(card.difficulty, g);
      if (g == Grade.again) next.lapses++;
      return next;
    }

    final r = retrievability(elapsedDays, card.stability);
    if (g == Grade.again) {
      next.stability = _stabilityFail(card.difficulty, card.stability, r);
      next.difficulty = _difficultyNext(card.difficulty, g);
      next.lapses = card.lapses + 1;
    } else {
      next.stability = _stabilitySuccess(card.difficulty, card.stability, r, g);
      next.difficulty = _difficultyNext(card.difficulty, g);
    }
    return next;
  }

  /// الفترة الموصى بها بالأيام بعد مراجعة (مقيدة بالسقف التطبيقي، ≥ 1).
  static double nextIntervalDays(CardMemory reviewed) {
    final i = intervalAt(0.90, reviewed.stability);
    if (i < 1.0) return 1.0;
    return i > maxIntervalDays ? maxIntervalDays : i;
  }

  static double _clampD(double d) => d < 1.0 ? 1.0 : (d > 10.0 ? 10.0 : d);
}
