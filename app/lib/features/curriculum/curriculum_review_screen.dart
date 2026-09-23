/// شاشة مراجعة الوحدة — تجمع لكل فصل أقسام المراجعة السريعة الموجودة أصلاً في
/// فقرات المنهاج: 🔑 قبل أن تبدأ (متطلّبات) · 🧾 الخلاصة · ⚖️ خصومات السلم.
///
/// تُبنى بالكامل من `pack.json` (لا محتوى جديد) — كل فصل من الـ١٧ يحمل هذه
/// الأقسام الثلاثة. جزء من توصيل تبويب «المراجعة» (كان placeholder «قريباً»).
library;

import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/util/arabic_number.dart';

/// بادئات أقسام المراجعة كما تظهر في `Paragraph.summary`.
const _reviewMarkers = <String>['🔑', '🧾', '⚖️'];

/// هل هذه الفقرة قسمُ مراجعة (تبدأ خلاصتها بأحد الرموز)؟
bool _isReviewParagraph(Paragraph p) {
  final s = p.summary.trimLeft();
  return _reviewMarkers.any(s.startsWith);
}

/// عنوان مختصر للقسم من الخلاصة (قبل أول « — »).
String _sectionTitle(String summary) {
  final s = summary.trim();
  final dash = s.indexOf(' — ');
  return dash > 0 ? s.substring(0, dash).trim() : s;
}

class CurriculumReviewScreen extends StatelessWidget {
  const CurriculumReviewScreen({super.key, required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('مراجعة: ${unit.title}')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (final chapter in unit.chapters)
            _ChapterReviewCard(chapter: chapter, txt: txt),
        ],
      ),
    );
  }
}

class _ChapterReviewCard extends StatelessWidget {
  const _ChapterReviewCard({required this.chapter, required this.txt});

  final Chapter chapter;
  final TextTheme txt;

  @override
  Widget build(BuildContext context) {
    final sections =
        chapter.paragraphs.where(_isReviewParagraph).toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: Key('review-${chapter.id}'),
        leading: const Icon(Icons.auto_stories_outlined),
        title: Text(chapter.title, style: txt.titleSmall),
        subtitle: sections.isEmpty
            ? Text('لا أقسام مراجعة', style: txt.bodySmall)
            : Text('${ArabicNumber.from(sections.length)} أقسام مراجعة',
                style: txt.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('لا توجد أقسام مراجعة لهذا الفصل.',
                  style: txt.bodyMedium),
            )
          else
            for (final p in sections) ...[
              Text(_sectionTitle(p.summary),
                  style:
                      txt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(p.text, style: txt.bodyMedium),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
