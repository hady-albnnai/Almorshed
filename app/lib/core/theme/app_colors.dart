import 'package:flutter/material.dart';

/// رموز الهوية البصرية — docs/13-DESIGN-IDENTITY.md (كل القيم مقيسة WCAG).
/// ⚠️ ممنوع أي لون خارج هذا الملف (قرار ٤٧ — انضباط دلالي):
/// ذهبي=نقاط XP حصراً · بنفسجي=دوري فيزيا كلاش حصراً · أحمر=خطأ حصراً · أخضر نجاح=توثيق حصراً.
abstract final class AppColors {
  // ═══ الوضع الداكن (الافتراضي — docs/13 §٢) ═══
  static const darkBg = Color(0xFF0B1220); // بحري عميق — ليس أسود
  static const darkCard = Color(0xFF16223A);
  static const darkCard2 = Color(0xFF1C2B47);
  static const darkTxt = Color(0xFFE8EEF7); // 13.60:1 على البطاقة ✓
  static const darkTxt2 = Color(0xFF9DB0C9); // 7.17:1 ✓
  static const darkLine = Color(0xFF243350);

  // ═══ الوضع الفاتح (docs/13 §٣ — مقيس على #FFFFFF) ═══
  static const lightBg = Color(0xFFEEF3F9);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTxt = Color(0xFF17233A); // 15.70:1 ✓
  static const lightTxt2 = Color(0xFF44546E); // 7.67:1 ✓
  static const lightLine = Color(0xFFD5E0EC);

  // ═══ رموز الهوية: نسخة الداكن / نسخة الفاتح ═══
  static const brandDark = Color(0xFF2DD4A7); // 8.37:1 ✓
  static const brandLight = Color(0xFF0A8063); // 4.91:1 ✓
  static const brand2Dark = Color(0xFF38BDF8); // 7.40:1 ✓
  static const brand2Light = Color(0xFF0369A1); // 5.93:1 ✓
  static const goldDark = Color(0xFFFBBF24); // نقاط XP — 9.50:1 ✓
  static const goldLight = Color(0xFFA16207); // 4.92:1 ✓
  static const violetDark = Color(0xFFA78BFA); // الدوري — 5.83:1 ✓
  static const violetLight = Color(0xFF6D28D9); // 7.10:1 ✓
  static const dangerDark = Color(0xFFF87171); // 5.73:1 ✓
  static const dangerLight = Color(0xFFDC2626); // 4.83:1 ✓
  static const okDark = Color(0xFF34D399); // 8.25:1 ✓
  static const okLight = Color(0xFF047857); // 5.48:1 ✓

  // شارات دوري فيزيا كلاش (docs/13 §٤)
  static const leagueBronze = Color(0xFFD97706);
  static const leagueSilver = Color(0xFFCBD5E1);
  static const leagueGold = Color(0xFFFBBF24);
  static const leagueDiamond = Color(0xFF38BDF8);

  /// ⚡ قاعدة docs/13 الصارمة: نص زر CTA داكن على الأخضر دائماً وبالوضعين
  /// (الأبيض على الأخضر يفشل 1.89:1 — الداكن 8.33:1 ✓)
  static const onCta = Color(0xFF04222B);
  static const ctaGradient = LinearGradient(
    colors: [Color(0xFF2DD4A7), Color(0xFF22B8CF)],
  );
}
