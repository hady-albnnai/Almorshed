import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/progress/progress_store.dart';
import '../../core/xp/streak_service.dart';
import '../../core/util/arabic_number.dart';
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
  });

  final Unit unit;
  final ProgressStore progressStore;

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
  });

  final int index;
  final Chapter chapter;
  final bool completed;
  final ChapterProgress? progress;
  final ProgressStore progressStore;
  final VoidCallback onReturned;

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
                                  xpRecorder: widget.xpRecorder,
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
