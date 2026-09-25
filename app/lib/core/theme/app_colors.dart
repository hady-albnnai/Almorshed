import 'package:flutter/material.dart';

/// الهوية البصرية الدافئة (طراز «لُورانيم | مختبر الفيزياء»).
/// ورق كريمي + أخضر غابة (الحبر) + برتقالي طوبي (لمسة) + أخضر مريمية.
/// ملاحظة: قرار docs/13 (الانضباط اللوني لفيزيا كلاش) رُفع بأمر المالك 2026-09-25.
/// الأسماء القديمة (brand/gold/violet…) محفوظة كأسماء بديلة مُعاد ربطها
/// حتى لا تنكسر الشاشات التي لم تُحدَّث بعد.
abstract final class AppColors {
  // ═══ رموز الطراز الدافئ — فاتح ═══
  static const ink = Color(0xFF132722); // أخضر غابة — نص وأسطح داكنة
  static const paper = Color(0xFFF3F0E7); // خلفية كريمية
  static const card = Color(0xFFFFFDF7); // بطاقة شبه بيضاء
  static const accent = Color(0xFFDD6E42); // برتقالي طوبي — اللمسة
  static const sage = Color(0xFF9FBD9A); // أخضر مريمية
  static const sageTint = Color(0xFFE4EADC); // خلفية شارة/بطاقة متابعة
  static const muted = Color(0xFF66736E); // نص ثانوي
  static const line = Color(0xFFDCD8CC); // حدود خفيفة على الورق

  // ═══ رموز الطراز الدافئ — داكن ═══
  static const inkD = Color(0xFFE9EEE8); // النص بالداكن
  static const paperD = Color(0xFF13231F); // خلفية داكنة
  static const cardD = Color(0xFF1B2E28); // بطاقة داكنة
  static const card2D = Color(0xFF294038); // بطاقة/شارة داكنة أعمق
  static const mutedD = Color(0xFFA3B0AA);
  static const lineD = Color(0xFF2C3E38);

  // ألوان دلالية دافئة (نجاح/خطأ) — من مسحة الطراز نفسه
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
  static const brand2Light = Color(0xFF6F8F6A); // مريمية أغمق للفاتح
  static const goldDark = accent;
  static const goldLight = accent;
  static const violetDark = accent;
  static const violetLight = accent;

  static const dangerDark = errDarkC;
  static const dangerLight = errLightC;
  static const okDark = okDarkC;
  static const okLight = okLightC;

  // شارات الدوري (تبويب التحدي — يُبحث فيه لاحقاً؛ نُبقيها كما هي)
  static const leagueBronze = Color(0xFFB5764B);
  static const leagueSilver = Color(0xFFB9BEB2);
  static const leagueGold = accent;
  static const leagueDiamond = sage;

  /// نص زرّ CTA: الزرّ الأساسي أصبح حبريّاً (ink) فالنص عليه ورقيّ.
  static const onCta = paper;
  static const ctaGradient = LinearGradient(
    colors: [Color(0xFFE07E52), Color(0xFFDD6E42)],
  );
}
