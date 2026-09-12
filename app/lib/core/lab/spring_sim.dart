/// F3.5 — نواة محاكاة النابض التوافقي (docs/12 §٦ · قرار ٤٣ PhET/POE).
/// كل شيء خالص وحتمي: RK4 بخطوة ثابتة dt = 1/240 ث — نفس المدخلات ⇒
/// نفس المسار بتّاً على كل الأجهزة. بلا شبكة، بلا حالة Flutter.
library;

import 'dart:math' as math;

/// خطوة التكامل الثابتة — docs/12 §٦ حرفياً.
const double simDt = 1.0 / 240.0;

/// حالة النابض اللحظية: الإزاحة x (متر) والسرعة v (م/ث).
class SpringState {
  const SpringState(this.x, this.v);
  final double x;
  final double v;

  /// الشروط الابتدائية من سحب المستخدم: يُترك من إزاحة x0 بسرعة معدومة
  /// (بداية من أقصى إزاحة ⇒ x(t) = x0·cos(ωt)).
  /// ⚠️ دالة ساكنة عادية — static const على الدوال خطأ تصريف بالدارت.
  static SpringState released(double x0) => SpringState(x0, 0.0);
}

/// الدور النظري T = 2π√(m/k) — الثواني.
double periodOf(double massKg, double stiffness) =>
    2.0 * math.pi * math.sqrt(massKg / stiffness);

/// خطوة RK4 واحدة للمعادلة x″ = −(k/m)·x — حتمية تماماً.
SpringState rk4Step(SpringState s, double massKg, double stiffness) {
  double acc(double x) => -(stiffness / massKg) * x;

  final k1x = s.v;
  final k1v = acc(s.x);
  final k2x = s.v + simDt / 2.0 * k1v;
  final k2v = acc(s.x + simDt / 2.0 * k1x);
  final k3x = s.v + simDt / 2.0 * k2v;
  final k3v = acc(s.x + simDt / 2.0 * k2x);
  final k4x = s.v + simDt * k3v;
  final k4v = acc(s.x + simDt * k3x);

  return SpringState(
    s.x + simDt / 6.0 * (k1x + 2.0 * k2x + 2.0 * k3x + k4x),
    s.v + simDt / 6.0 * (k1v + 2.0 * k2v + 2.0 * k3v + k4v),
  );
}

/// فحص تحدي «اجعل T = ٢ث» — docs/12 §٦: |T − 2| ≤ 0.05 (على النظري).
bool challengeT2Ok(double massKg, double stiffness) =>
    (periodOf(massKg, stiffness) - 2.0).abs() <= 0.05;

/// قياس الدور من مسار المحاكاة — مرحلة «لاحظ» في منهجية POE.
/// يُغذى بكل خطوة فيزيائية (t, x) ويكشف العبور الصاعد عبر الصفر؛
/// بعد دورتين كاملتين يعطي متوسط الفترة المقيسة.
class PeriodMeter {
  double? _lastCrossT;
  final List<double> _periods = [];

  /// عدد الأدوار المكتملة المقيسة.
  int get measuredCount => _periods.length;

  /// متوسط الفترة المقيسة (null حتى دورتين مكتملتين).
  double? get averagePeriod {
    if (_periods.length < 2) return null;
    var sum = 0.0;
    for (final p in _periods) {
      sum += p;
    }
    return sum / _periods.length;
  }

  /// تغذية بقراءة خطوة (خالصة — تحدّث الحالة الداخلية حصراً).
  void feed(double t, double x) {
    final prev = _lastCrossT;
    final prevX = _prevX;
    if (prevX != null && prevX <= 0.0 && x > 0.0) {
      if (prev != null) _periods.add(t - prev);
      _lastCrossT = t;
    }
    _prevX = x;
  }

  double? _prevX;

  /// تصفير للقياس من جديد (بعد تغيير m/k أو إعادة السحب).
  void reset() {
    _lastCrossT = null;
    _prevX = null;
    _periods.clear();
  }
}
