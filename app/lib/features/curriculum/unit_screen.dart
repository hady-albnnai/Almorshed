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
    final unitNo = widget.unit.id.replaceAll(RegExp(r'[^0-9]'), '');
    final shortTitle = widget.unit.title
        .replaceFirst(RegExp(r'^الوحدة[^:：]*[:：]\s*'), '');
    return Scaffold(
      appBar: AppBar(title: Text(widget.unit.title)),
      body: widget.unit.chapters.isEmpty
          ? Center(
              child:
                  Text('لا فصول بعد — قيد الإعداد', style: txt.bodyMedium))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
              children: [
                Text('الوحدة ${ArabicNumber.from(int.tryParse(unitNo) ?? 1)}',
                    style: TextStyle(
                      fontFamily: 'Alexandria',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.3,
                      color: Theme.of(context).colorScheme.primary,
                    )),
                const SizedBox(height: 4),
                Text(shortTitle, style: txt.headlineSmall),
                const SizedBox(height: 4),
                Text(
                    '${ArabicNumber.from(widget.unit.chapters.length)} دروس • '
                    'اختر فصلًا للبدء',
                    style: txt.bodyMedium),
                const SizedBox(height: 18),
                for (var i = 0; i < widget.unit.chapters.length; i++)
                  _ChapterCard(
                    index: i,
                    unitNo: unitNo,
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
    required this.unitNo,
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
  final String unitNo;
  final Chapter chapter;
  final bool completed;
  final ChapterProgress? progress;
  final ProgressStore progressStore;
  final VoidCallback onReturned;
  final XpRecorder? xpRecorder;

  void _openLesson(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(
        builder: (_) => LessonScreen(
          chapter: chapter,
          progressStore: progressStore,
          xpRecorder: xpRecorder,
          trainingStore: trainingStore,
        ),
      ))
      .then((_) => onReturned());

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final started = !completed && (progress?.cursor ?? 0) > 0;
    final subtitle = chapter.paragraphs.isEmpty
        ? 'قيد الإعداد'
        : completed
            ? 'مكتمل ✓'
            : started
                ? 'متابعة القراءة'
                : 'شرح • أمثلة • تدريب';
    final experiments = _experimentsOf(chapter);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap:
                  chapter.paragraphs.isEmpty ? null : () => _openLesson(context),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: scheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // شارة الترقيم U.C — مثل «١.٢»
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: completed
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          completed
                              ? '✓'
                              : '${ArabicNumber.from(int.tryParse(unitNo) ?? 1)}'
                                  '.${ArabicNumber.from(index + 1)}',
                          style: TextStyle(
                            fontFamily: 'Alexandria',
                            fontWeight: FontWeight.w700,
                            fontSize: completed ? 22 : 17,
                            color: completed ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chapter.title,
                                style: txt.titleMedium, maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(subtitle, style: txt.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('←',
                          style: TextStyle(
                              fontSize: 22, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // شارات التجارب: تفتح التجربة مباشرة (قرار المالك ٢٠٢٦-٠٩-١٦، ٣٧)
          for (final exp in experiments)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
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
        ],
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
