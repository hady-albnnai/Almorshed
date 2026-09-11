import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/arabic_number.dart';

/// شاشة القراءة — فقرة واحدة لكل شاشة (قرار نمط القراءة · F3.2):
/// «التالي» + «📌 خلاصة الفقرة» + فهرس حر قابل للطي + «انتهى الدرس».
/// TTS «اسمعني»: يُضاف مع حزمة flutter_tts (إخفاء عند غياب المحرك العربي) — متبقٍّ لإغلاق F3.2.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.chapter});

  final Chapter chapter;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _idx = 0;
  bool _finished = false;
  bool _indexOpen = false;

  Chapter get _chapter => widget.chapter;
  int get _total => _chapter.paragraphs.length;
  Paragraph get _paragraph => _chapter.paragraphs[_idx];

  Color _gold(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? AppColors.goldDark
          : AppColors.goldLight;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _finished ? 'انتهى الدرس' : _chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_finished)
            IconButton(
              tooltip: 'الفهرس — تنقّل حر',
              onPressed: () => setState(() => _indexOpen = !_indexOpen),
              icon: const Icon(Icons.menu_book_outlined),
            ),
        ],
      ),
      body: _finished
          ? _EndView(onReplay: () => setState(() { _finished = false; _idx = 0; }))
          : Column(
              children: [
                if (_indexOpen) _IndexPanel(
                  chapter: _chapter,
                  current: _idx,
                  onPick: (i) => setState(() { _idx = i; _indexOpen = false; }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'فقرة ${ArabicNumber.from(_idx + 1)} من '
                      '${ArabicNumber.from(_total)}',
                      style: txt.bodyMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(_paragraph.text, style: txt.bodyLarge),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _gold(context).withValues(alpha: .45)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📌 خلاصة الفقرة',
                            style: txt.titleMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary)),
                        const SizedBox(height: 4),
                        Text(_paragraph.summary, style: txt.bodyMedium),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (_idx > 0)
                          OutlinedButton(
                            onPressed: () => setState(() => _idx--),
                            child: const Text('→ السابق'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => setState(() {
                            if (_idx == _total - 1) {
                              _finished = true;
                            } else {
                              _idx++;
                            }
                          }),
                          child: Text(_idx == _total - 1
                              ? 'انتهى الدرس ✓'
                              : 'التالي ←'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// الفهرس الحر — تنقّل مباشر للفقرات (قرار قابلية الطي بالنموذج).
class _IndexPanel extends StatelessWidget {
  const _IndexPanel({
    required this.chapter,
    required this.current,
    required this.onPick,
  });

  final Chapter chapter;
  final int current;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < chapter.paragraphs.length; i++)
            ListTile(
              dense: true,
              leading: i == current
                  ? const Icon(Icons.check_circle_outline, size: 18)
                  : const Icon(Icons.radio_button_unchecked, size: 18),
              title: Text(
                'الفقرة ${ArabicNumber.from(i + 1)} — '
                '${_short(chapter.paragraphs[i].summary)}',
                style: txt.bodyMedium?.copyWith(
                  fontWeight: i == current ? FontWeight.w800 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onPick(i),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  String _short(String s) => s.length <= 42 ? s : '${s.substring(0, 42)}…';
}

/// «انتهى الدرس» — شاشة الإتمام (قرار نمط القراءة) — النقاط تُسجَّل فعلياً في F3.7.
class _EndView extends StatelessWidget {
  const _EndView({required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_outlined, size: 64, color: AppColors.brandDark),
            const SizedBox(height: 12),
            Text('أنهيت الفصل!', style: txt.titleLarge),
            const SizedBox(height: 6),
            Text('+١٠ نقطة لدوري فيزيا كلاش ✓',
                style: txt.titleMedium?.copyWith(color: _gold(context))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع للوحدة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onReplay, child: const Text('أعد القراءة')),
          ],
        ),
      ),
    );
  }

  Color _gold(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? AppColors.goldDark
          : AppColors.goldLight;
}
