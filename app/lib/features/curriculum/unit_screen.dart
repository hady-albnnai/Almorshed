import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/util/arabic_number.dart';
import 'lesson_screen.dart';

/// شاشة الوحدة — فصولها (F3.2 · قرارات ٢، ٣٧).
class UnitScreen extends StatelessWidget {
  const UnitScreen({super.key, required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      body: unit.chapters.isEmpty
          ? Center(
              child: Text('لا فصول بعد — قيد الإعداد', style: txt.bodyMedium))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (var i = 0; i < unit.chapters.length; i++)
                  _ChapterCard(index: i, chapter: unit.chapters[i]),
              ],
            ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.index, required this.chapter});

  final int index;
  final Chapter chapter;

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
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => LessonScreen(chapter: chapter)),
                      ),
              child: const Text('ابدأ القراءة'),
            ),
          ],
        ),
      ),
    );
  }
}
