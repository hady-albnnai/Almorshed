/// APP-NAWWASAT-1 — الفلاشات الجديدة (الوحدة 1) داخل الدروس بموضعها.
///
/// خلفية: تدفق الدرس يفتح التجارب من سجل `labExperiments` (4 تجارب عامة:
/// gravity/lc/string/photo). الفلاشات الموحّدة الجديدة (دفعة 29–37 على
/// dev/self-content) شاشات مستقلة تحتاج `TrainingData` — لا تصلح في سجل
/// التجارب العامة. هذا الملف يوفّر سجل موازٍ + غلاف يحمّل بيانات التدريب
/// ثم يفتح الشاشة الصحيحة، حتى تستمر بطاقة «جرّبها بنفسك» تعمل للفلاشات:
///
///   spring  ← SpringLabScreen  (النابض التوافقي — U1C1)
///   torsion ← TorsionScreen    (نواس الفتل: تمهيد + التجارب ١–٣ — U1C2)
///   simple  ← SimpleScreen     (النواس البسيط T ~ √l — U1C3)
///   syringe ← SyringeScreen    (المحقن والإبرة — U1C1/الموائع)
///
/// التركيب (انظر README.md): انسخ هذا الملف إلى `app/lib/features/lab/`
/// ثم طبّق `lesson_screen.dart.patch`.
library;

import 'package:flutter/material.dart';

import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import 'simple_screen.dart';
import 'spring_lab_screen.dart';
import 'syringe_screen.dart';
import 'torsion_screen.dart';

/// وصف مختصر لعرضه في بطاقة «جرّبها بنفسك».
class LessonUnifiedExperiment {
  const LessonUnifiedExperiment({required this.title});

  final String title;
}

/// experimentId في الحزمة ← الفلاشات الجديدة.
const Map<String, LessonUnifiedExperiment> lessonUnifiedExperiments = {
  'spring': LessonUnifiedExperiment(title: 'النابض التوافقي'),
  'torsion':
      LessonUnifiedExperiment(title: 'نواس الفتل المخبري (تمهيد + تج ١–٣)'),
  'simple': LessonUnifiedExperiment(title: 'النواس البسيط: T ~ √l'),
  'syringe': LessonUnifiedExperiment(title: 'المحقن والإبرة: التدفق'),
};

/// غلاف: يحمّل TrainingData من المخزن ثم يفتح شاشة الفلاش الموحّد.
class LessonUnifiedExperimentScreen extends StatefulWidget {
  const LessonUnifiedExperimentScreen({
    super.key,
    required this.id,
    required this.trainingStore,
    this.xpRecorder,
  });

  /// مفتاح الفلاش في `lessonUnifiedExperiments`.
  final String id;
  final TrainingStore trainingStore;
  final XpRecorder? xpRecorder;

  @override
  State<LessonUnifiedExperimentScreen> createState() =>
      _LessonUnifiedExperimentScreenState();
}

class _LessonUnifiedExperimentScreenState
    extends State<LessonUnifiedExperimentScreen> {
  late final Future<TrainingData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.trainingStore.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainingData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!;
        final store = widget.trainingStore;
        final xp = widget.xpRecorder;
        switch (widget.id) {
          case 'spring':
            return SpringLabScreen(
              trainingStore: store,
              initialData: data,
              xpRecorder: xp,
            );
          case 'torsion':
            return TorsionScreen(
              trainingStore: store,
              initialData: data,
              xpRecorder: xp,
            );
          case 'simple':
            return SimpleScreen(
              trainingStore: store,
              initialData: data,
              xpRecorder: xp,
            );
          case 'syringe':
            return SyringeScreen(
              trainingStore: store,
              initialData: data,
              xpRecorder: xp,
            );
          default:
            return const Scaffold(
              body: Center(child: Text('تجربة غير معروفة')),
            );
        }
      },
    );
  }
}
