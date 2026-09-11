/// SplitMix64 — المرجع البتّي لمحرك docs/12 §٢.٢.
///
/// قاعدة الحتمية: نفس البذرة ⇒ نفس المخرجات على كل الأجهزة (Kotlin/Dart).
/// الأعداد هنا int أصلي = 64 بت على Android/Windows/Linux/macOS.
/// ⚠️ ممنوع تجميع هذا الملف لمستهدف ويب (int هناك 53 بت).
class SplitMix64 {
  int _state;

  SplitMix64(this._state);

  /// القيمة التالية من التيار (uint64 ملفوم بـ int Dart).
  int next() {
    _state = (_state + _gamma) & _mask;
    return _mix(_state);
  }

  /// الدالة الخالصة mix64 — تُستعمل لاشتقاق بذور الخيارات والحالات الفرعية.
  static int mix64(int seed) => _mix(seed);

  static const int _mask = 0xFFFFFFFFFFFFFFFF;
  static const int _gamma = 0x9E3779B97F4A7C15;
  static const int _m1 = 0xBF58476D1CE4E5B9;
  static const int _m2 = 0x94D049BB133111EB;

  static int _mix(int s) {
    var z = s;
    z = ((z ^ (z.ushr(30))) * _m1) & _mask;
    z = ((z ^ (z.ushr(27))) * _m2) & _mask;
    return (z ^ (z.ushr(31))) & _mask;
  }
}
