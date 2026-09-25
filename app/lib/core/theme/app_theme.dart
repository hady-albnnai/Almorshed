import 'package:flutter/material.dart';

import 'app_colors.dart';

/// الثيم الدافئ (طراز «لُورانيم | مختبر الفيزياء»).
/// العناوين بخط Alexandria، والنص بخط IBM Plex Sans Arabic.
/// اللمسة برتقالي طوبي، الأسطح كريمية/خضراء، والزرّ الأساسي حبريّ.
abstract final class AppTheme {
  static const _display = 'Alexandria';
  static const _body = 'IBMPlexSansArabic';

  static ThemeData get light => _base(
        brightness: Brightness.light,
        bg: AppColors.paper,
        surface: AppColors.card,
        ink: AppColors.ink,
        muted: AppColors.muted,
        line: AppColors.line,
        onInk: AppColors.paper,
        error: AppColors.errLightC,
        sage: AppColors.brand2Light,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        bg: AppColors.paperD,
        surface: AppColors.cardD,
        ink: AppColors.inkD,
        muted: AppColors.mutedD,
        line: AppColors.lineD,
        onInk: AppColors.paperD,
        error: AppColors.errDarkC,
        sage: AppColors.sage,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color ink,
    required Color muted,
    required Color line,
    required Color onInk,
    required Color error,
    required Color sage,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent, // اللمسة — الطوبي
      onPrimary: Colors.white,
      secondary: ink, // الحبر — للأزرار الأساسية والأسطح الداكنة
      onSecondary: onInk,
      tertiary: sage,
      onTertiary: ink,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: brightness == Brightness.dark
          ? AppColors.card2D
          : AppColors.sageTint,
      onSurfaceVariant: muted,
      error: error,
      onError: Colors.white,
      outline: line,
      outlineVariant: line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _body,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _display,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.5,
          color: ink,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: _display,
            color: ink,
            fontWeight: FontWeight.w800,
            fontSize: 46,
            height: 1.12,
            letterSpacing: -1.8),
        displaySmall: TextStyle(
            fontFamily: _display,
            color: ink,
            fontWeight: FontWeight.w800,
            fontSize: 32,
            height: 1.15,
            letterSpacing: -1.0),
        headlineSmall: TextStyle(
            fontFamily: _display,
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.4),
        titleLarge: TextStyle(
            fontFamily: _display,
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.2),
        titleMedium: TextStyle(
            fontFamily: _display,
            color: ink,
            fontWeight: FontWeight.w600,
            fontSize: 16),
        bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.95),
        bodyMedium: TextStyle(color: muted, fontSize: 14, height: 1.8),
        bodySmall: TextStyle(color: muted, fontSize: 12.5, height: 1.6),
        labelLarge: TextStyle(
            fontFamily: _display,
            color: ink,
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink, // الزرّ الأساسي حبريّ (كما الويب)
          foregroundColor: onInk,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: _display, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: _display, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: line),
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: _display, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: line),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.accent,
        side: BorderSide(color: line),
        shape:
            const StadiumBorder(),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.16),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
          fontFamily: _display,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: ink,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : muted,
            )),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(TextStyle(
              fontFamily: _display,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
          side: WidgetStatePropertyAll(BorderSide(color: line)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.accent
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : ink),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: onInk),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
