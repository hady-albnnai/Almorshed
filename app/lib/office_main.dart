// ═══════════════════════════════════════════════════════════════════════
// office_main.dart — نقطة دخول «أداة مكتب لورانيم» المستقلّة (خطوة ٢).
//
// تطبيق منفصل عن تطبيق الطالب، يشارك الشيفرة فقط (OfficeApi/OfficeKeyVault).
// البناء:
//   flutter build apk --release -t lib/office_main.dart
// التشغيل للتجربة:
//   flutter run -t lib/office_main.dart
//
// يحمل OFFICE_KEY وحده (خزنة آمنة على الجهاز) — لا SIGNING_SEED.
// ═══════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/office_tool/office_console_screen.dart';

void main() => runApp(const OfficeToolApp());

class OfficeToolApp extends StatelessWidget {
  const OfficeToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مكتب لورانيم — مولّد الأكواد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const OfficeConsoleScreen(),
    );
  }
}
