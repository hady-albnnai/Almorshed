import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/lab/experiments.dart';
import '../../core/progress/progress_store.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../../core/util/arabic_number.dart';
import '../lab/experiment_screen.dart';
import 'lesson_screen.dart';

/// شاشة الوحدة — فصولها (F3.2 · قرارات ٢، ٣٧).
/// F3.1: علامة ✓ للفصول المكتملة، وتحديث عند العودة من الدرس.
class UnitScreen extends StatefulWidget {
  /// F3.8 — اختياري: null = بلا تسجيل (اختبارات قديمة سليمة).
  final XpRecorder? xpRecorder;

  const UnitScreen({
    super.key,
    required this.unit,
    required this.progressStore,
      this.xpRecorder, // F3.8
    this.trainingStore, // المادة ١٤: تجارب الدرس بموضعها
  });

  final Unit unit;
  final ProgressStore progressStore;
  final TrainingStore? trainingStore;

  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  ReadProgress _progress = const ReadProgress();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await widget.progressStore.load();
    if (!mounted) return;
    setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final done = _progress.completedIds;
    return Scaffold(
      appBar: AppBar(title: Text(widget.unit.title)),
      body: widget.unit.chapters.isEmpty
          ? Center(
              child:
                  Text('لا فصول بعد — قيد الإعداد', style: txt.bodyMedium))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (var i = 0; i < widget.unit.chapters.length; i++)
                  _ChapterCard(
                    index: i,
                    xpRecorder: widget.xpRecorder,
                    trainingStore: widget.trainingStore,
                    chapter: widget.unit.chapters[i],
                    completed: done.contains(widget.unit.chapters[i].id),
                    progress: _progress.chapters[widget.unit.chapters[i].id],
                    progressStore: widget.progressStore,
                    onReturned: _reload,
                  ),
              ],
            ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.index,
    required this.chapter,
    required this.completed,
    required this.progress,
    required this.progressStore,
    required this.onReturned,
    required this.xpRecorder,
    this.trainingStore,
  });

  final TrainingStore? trainingStore;
  final int index;
  final Chapter chapter;
  final bool completed;
  final ChapterProgress? progress;
  final ProgressStore progressStore;
  final VoidCallback onReturned;
  final XpRecorder? xpRecorder;


  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${completed ? '✓ ' : ''}'
              'الفصل ${ArabicNumber.from(index + 1)}: ${chapter.title} · '
              'ص${ArabicNumber.from(chapter.page)}',
              style: txt.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${ArabicNumber.from(chapter.paragraphs.length)} فقرات',
                style: txt.bodyMedium),
            // شارات التجارب (قرار المالك ٢٠٢٦-٠٩-١٦): تفتح التجربة مباشرة —
            // نفس الشاشة التي تظهر بموضعها داخل الدرس (لا تكرار محتوى، قرار ٣٧)
            for (final exp in _experimentsOf(chapter))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ActionChip(
                  key: Key('unit-exp-${exp.id}'),
                  avatar: const Text('🧪'),
                  label: Text('تجربة: ${exp.title}'),
                  onPressed: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExperimentScreen(
                            experiment: exp,
                            trainingStore:
                                trainingStore ?? InMemoryTrainingStore(),
                            xpRecorder: xpRecorder,
                          ),
                        ),
                      )
                      .then((_) => onReturned()),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: chapter.paragraphs.isEmpty
                  ? null
                  : () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                            builder: (_) => LessonScreen(
                                  chapter: chapter,
                                  progressStore: progressStore,
                                  xpRecorder: xpRecorder,
                                  trainingStore: trainingStore,
                                )),
                      )
                      .then((_) => onReturned()),
              // F3.1: متابعة إن لم يكتمل وله موضع محفوظ — وإلا «ابدأ القراءة»
              child: Text(!completed && (progress?.cursor ?? 0) > 0
                  ? 'متابعة القراءة'
                  : 'ابدأ القراءة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// تجارب الفصل بترتيب ورودها في الفقرات (عادة واحدة؛ قد تكون صفراً).
List<LabExperiment> _experimentsOf(Chapter chapter) => [
      for (final p in chapter.paragraphs)
        if (p.experimentId != null && labExperiments.containsKey(p.experimentId))
          labExperiments[p.experimentId]!,
    ];
