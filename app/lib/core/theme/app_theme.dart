import 'package:flutter/material.dart';

import 'app_colors.dart';

/// الثيمات — docs/13: الداكن أولاً، والفاتح برموزه المقيسة.
/// الخطوط Cairo (هوية/عناوين) وTajawal (نص) تُربَط هنا في F0.3 بعد وضع ملفاتها.
abstract final class AppTheme {
  static ThemeData get dark => _base(
        scheme: const ColorScheme.dark(
          primary: AppColors.brandDark,
          secondary: AppColors.brand2Dark,
          surface: AppColors.darkCard,
          error: AppColors.dangerDark,
        ),
        bg: AppColors.darkBg,
        txt: AppColors.darkTxt,
        txt2: AppColors.darkTxt2,
        line: AppColors.darkLine,
      );

  static ThemeData get light => _base(
        scheme: const ColorScheme.light(
          primary: AppColors.brandLight,
          secondary: AppColors.brand2Light,
          surface: AppColors.lightCard,
          error: AppColors.dangerLight,
        ),
        bg: AppColors.lightBg,
        txt: AppColors.lightTxt,
        txt2: AppColors.lightTxt2,
        line: AppColors.lightLine,
      );

  static ThemeData _base({
    required ColorScheme scheme,
    required Color bg,
    required Color txt,
    required Color txt2,
    required Color line,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: txt,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: txt, fontSize: 16, height: 1.9),
        bodyMedium: TextStyle(color: txt2, fontSize: 14, height: 1.8),
        titleLarge: TextStyle(
            color: txt, fontWeight: FontWeight.w800, fontSize: 20),
        titleMedium: TextStyle(
            color: txt, fontWeight: FontWeight.w700, fontSize: 16),
        labelLarge: TextStyle(color: txt2, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: AppColors.onCta, // قاعدة الداكن-على-الأخضر
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txt2,
          side: BorderSide(color: line),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: line),
        ),
      ),
    );
  }
}
