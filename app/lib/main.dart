import 'package:flutter/material.dart';

import 'core/content/content_loader.dart';
import 'core/content/models.dart';
import 'core/progress/progress_store.dart';
import 'core/progress/shared_prefs_store.dart';
import 'core/theme/app_theme.dart';
import 'core/training/shared_prefs_training_store.dart';
import 'core/training/training_store.dart';
import 'features/curriculum/curriculum_screen.dart';

void main() => runApp(const FizyaClashApp());

/// فيزيا كلاش — Clash of Physics
/// المهمة الحالية F3.1: التقدم الحقيقي المحفوظ.
class FizyaClashApp extends StatefulWidget {
  const FizyaClashApp({
    super.key,
    this.packLoader,
    this.progressStore,
    this.trainingStore,
  });

  /// حقن للاختبارات؛ الافتراضي يحمّل حزمة assets الحقيقية.
  final Future<ContentPack> Function()? packLoader;

  /// حقن مخزن التقدم؛ الافتراضي shared_preferences (قرار ٥٧).
  final ProgressStore? progressStore;

  /// حقن مخزن التدريب (F3.3)؛ الافتراضي shared_preferences.
  final TrainingStore? trainingStore;

  @override
  State<FizyaClashApp> createState() => _FizyaClashAppState();
}

class _FizyaClashAppState extends State<FizyaClashApp> {
  ThemeMode _mode = ThemeMode.dark; // docs/13: الداكن أولاً

  late final Future<ContentPack> _packFuture =
      (widget.packLoader ?? _defaultLoadPack)();

  static Future<ContentPack> _defaultLoadPack() => ContentLoader().loadPack();

  void _toggleTheme() => setState(() {
        _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
      home: FutureBuilder<ContentPack>(
        future: _packFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _Splash();
          }
          if (snap.hasError || !snap.hasData) {
            return _ErrorView(error: snap.error);
          }
          return CurriculumScreen(
            pack: snap.data!,
            onToggleTheme: _toggleTheme,
            progressStore:
                widget.progressStore ?? SharedPrefsProgressStore(),
            trainingStore:
                widget.trainingStore ?? SharedPrefsTrainingStore(),
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 12),
              Text('تعذر تحميل المحتوى', style: txt.titleLarge),
              const SizedBox(height: 8),
              Text('$error',
                  textAlign: TextAlign.center, style: txt.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
