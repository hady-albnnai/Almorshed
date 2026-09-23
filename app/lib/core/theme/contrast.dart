/// F7.2 — حاسبة تباين WCAG 2.x (خالصة، بلا اعتماد على منصّة).
/// تحوّل ضمانات التباين في docs/13 من تعليقات يدوية إلى قيمة **محسوبة**
/// قابلة للفرض في الاختبارات (لا نثق برقم مكتوب بيد — نحسبه).
///
/// المرجع: WCAG 2.1 — Relative Luminance + Contrast Ratio
///   L = 0.2126·R + 0.7152·G + 0.0722·B  (بعد تصحيح gamma لكل قناة)
///   ratio = (Lأفتح + 0.05) / (Lأغمق + 0.05)  ∈ [1, 21]
library;

import 'dart:math' as math;
import 'dart:ui';

/// الإضاءة النسبية لقناة واحدة (0..1) بعد تصحيح sRGB gamma.
double _linear(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// الإضاءة النسبية للون (0=أسود .. 1=أبيض) — WCAG.
/// نستخدم مكوّنات Flutter الحديثة (.r/.g/.b قيم 0..1) — لا واجهات مهمَلة.
double relativeLuminance(Color color) {
  final r = _linear(color.r);
  final g = _linear(color.g);
  final b = _linear(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// نسبة التباين بين لونين (متناظرة) — من 1:1 إلى 21:1.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// عتبات WCAG 2.1 المعتمدة في docs/13.
class WcagLevel {
  /// AA للنص العادي (< 18pt عادي / < 14pt عريض).
  static const double aaNormal = 4.5;

  /// AA للنص الكبير (≥ 18pt عادي / ≥ 14pt عريض) وعناصر الواجهة غير النصّية.
  static const double aaLarge = 3.0;

  /// AAA للنص العادي.
  static const double aaaNormal = 7.0;
}

/// هل يمرّ الزوج عتبة معيّنة؟
bool passesContrast(Color fg, Color bg, {double min = WcagLevel.aaNormal}) =>
    contrastRatio(fg, bg) >= min;
