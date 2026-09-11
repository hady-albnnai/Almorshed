import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const FizyaClashApp());

/// فيزيا كلاش — Clash of Physics
/// F0.2: هيكل البناء الأولي — الهوية مطبقة (docs/13) والشاشات الفعلية تبدأ في M3
/// وفق النموذج المرجعي ui-mockup/index.html.
class FizyaClashApp extends StatefulWidget {
  const FizyaClashApp({super.key});

  @override
  State<FizyaClashApp> createState() => _FizyaClashAppState();
}

class _FizyaClashAppState extends State<FizyaClashApp> {
  ThemeMode _mode = ThemeMode.dark; // docs/13: الداكن أولاً

  void _toggleTheme() => setState(() {
        _mode =
            _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فيزيا كلاش — Clash of Physics',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl, // التطبيق عربي بالكامل
        child: child ?? const SizedBox.shrink(),
      ),
      home: _BuildPlaceholder(onToggleTheme: _toggleTheme),
    );
  }
}

/// شاشة التحقق من أول بناء — تُستبدل بشاشات M3 عند بدئها.
class _BuildPlaceholder extends StatelessWidget {
  const _BuildPlaceholder({required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فيزيا كلاش', style: txt.titleLarge),
            Text('Clash of Physics · منهاج الثالث الثانوي العلمي',
                style: txt.bodyMedium),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تبديل الوضع الفاتح/الداكن',
            onPressed: onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.science_outlined,
                  size: 72, color: AppColors.brandDark),
              const SizedBox(height: 12),
              Text('أول بناء ناجح ✓', style: txt.titleLarge),
              const SizedBox(height: 8),
              Text(
                'F0.2 — الهيكل يعمل والهوية مطبقة.\n'
                'الشاشات الفعلية تبدأ في M3 (المنهاج أولاً) بمطابقة النموذج المرجعي.',
                textAlign: TextAlign.center,
                style: txt.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onToggleTheme,
                child: const Text('جرّب الوضع الفاتح/الداكن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
