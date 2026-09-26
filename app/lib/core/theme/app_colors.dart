import 'package:flutter/material.dart';

/// الهوية البصرية الدافئة (طراز «لُورانيم | مختبر الفيزياء»).
/// ورق كريمي + بنّي حبري دافئ (الحبر) + برتقالي طوبي (الهوية) + رملي دافئ (ثانوي).
/// ملاحظة: قرار docs/13 (الانضباط اللوني لفيزيا كلاش) رُفع بأمر المالك 2026-09-25،
/// وأمر 2026-09-26: استبدال الأخضر بالطوبي ⇒ أُزيلت الخُضرة من الهوية والأسطح
/// (بقيت خُضرة النجاح الدلالية فقط لأنها عُرف عالمي في واجهات الاستخدام).
/// الأسماء القديمة (brand/gold/violet/sage…) محفوظة كأسماء بديلة مُعاد ربطها
/// حتى لا تنكسر الشاشات التي لم تُحدَّث بعد.
abstract final class AppColors {
  // ═══ رموز الطراز الدافئ — فاتح ═══
  static const ink = Color(0xFF2A211C); // بنّي حبري دافئ — نص وأسطح داكنة
  static const paper = Color(0xFFF3F0E7); // خلفية كريمية
  static const card = Color(0xFFFFFDF7); // بطاقة شبه بيضاء
  static const accent = Color(0xFFDD6E42); // برتقالي طوبي — الهوية
  static const sage = Color(0xFFCBB79E); // رملي دافئ (كان مريمية)
  static const sageTint = Color(0xFFF0E6D8); // خلفية شارة/بطاقة متابعة (كريمي دافئ)
  static const muted = Color(0xFF7A6E64); // نص ثانوي دافئ
  static const line = Color(0xFFDCD8CC); // حدود خفيفة على الورق

  // ═══ رموز الطراز الدافئ — داكن ═══
  static const inkD = Color(0xFFEEE7DE); // النص بالداكن (دافئ)
  static const paperD = Color(0xFF201A16); // خلفية داكنة دافئة
  static const cardD = Color(0xFF2B231D); // بطاقة داكنة دافئة
  static const card2D = Color(0xFF3A2F27); // بطاقة/شارة داكنة أعمق دافئة
  static const mutedD = Color(0xFFB3A79B);
  static const lineD = Color(0xFF3C332B);

  // ألوان دلالية (نجاح/خطأ) — النجاح أخضر (عُرف عالمي)، الخطأ طوبي دافئ
  static const okLightC = Color(0xFF538065);
  static const okBgLight = Color(0xFFE2EFE4);
  static const okDarkC = Color(0xFF7FB08D);
  static const errLightC = Color(0xFFBB5A45);
  static const errBgLight = Color(0xFFF6E3DE);
  static const errDarkC = Color(0xFFD98266);

  // ═══════════════════════════════════════════════════════════════
  // أسماء متوافقة مع الكود القديم (مُعاد ربطها للطراز الدافئ)
  // ═══════════════════════════════════════════════════════════════
  static const darkBg = paperD;
  static const darkCard = cardD;
  static const darkCard2 = card2D;
  static const darkTxt = inkD;
  static const darkTxt2 = mutedD;
  static const darkLine = lineD;

  static const lightBg = paper;
  static const lightCard = card;
  static const lightTxt = ink;
  static const lightTxt2 = muted;
  static const lightLine = line;

  // اللمسة (كانت brand/gold/violet…) → البرتقالي الطوبي
  static const brandDark = accent;
  static const brandLight = accent;
  static const brand2Dark = sage;
  static const brand2Light = Color(0xFFB08768); // رملي أغمق دافئ للفاتح
  static const goldDark = accent;
  static const goldLight = accent;
  static const violetDark = accent;
  static const violetLight = accent;

  static const dangerDark = errDarkC;
  static const dangerLight = errLightC;
  static const okDark = okDarkC;
  static const okLight = okLightC;

  // شارات الدوري (تبويب التحدي) — نطاق نحاسي/رملي دافئ بلا خُضرة
  static const leagueBronze = Color(0xFFB5764B);
  static const leagueSilver = Color(0xFFC3BBAF);
  static const leagueGold = accent;
  static const leagueDiamond = Color(0xFFCBB79E);

  /// نص زرّ CTA: الزرّ الأساسي أصبح حبريّاً (ink) فالنص عليه ورقيّ.
  static const onCta = paper;
  static const ctaGradient = LinearGradient(
    colors: [Color(0xFFE07E52), Color(0xFFDD6E42)],
  );
}
