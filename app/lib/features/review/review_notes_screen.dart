// ═══════════════════════════════════════════════════════════════════════
// review_notes_screen.dart — «ملاحظاتي» (وضع المراجعة): عدّاد التقدم +
// قائمة الملاحظات (تعديل/حذف) + إرسال بواتساب/نسخ (قرار ١٩).
// تظهر من الرئيسية بوضع المراجعة فقط.
// ═══════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content/models.dart';
import '../../core/review/review_mode.dart';
import '../../core/util/arabic_number.dart';
import 'review_widgets.dart';

/// رقم المكتب لاستقبال الملاحظات — بصيغة دولية بلا + (يضبطه المالك).
const String kOfficeWhatsApp = '963000000000';

class ReviewNotesScreen extends StatefulWidget {
  const ReviewNotesScreen({super.key, required this.pack, required this.notes});

  final ContentPack pack;
  final ReviewNotesStore notes;

  @override
  State<ReviewNotesScreen> createState() => _ReviewNotesScreenState();
}

class _ReviewNotesScreenState extends State<ReviewNotesScreen> {
  Map<String, ReviewNote> _all = {};
  bool _loading = true;

  int get _totalItems =>
      widget.pack.questions.length + widget.pack.cards.length;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final m = await widget.notes.load();
    if (!mounted) return;
    setState(() {
      _all = m;
      _loading = false;
    });
  }

  String get _report => formatReviewReport(_all.values, now: DateTime.now());

  Future<void> _sendWhatsApp() async {
    if (_all.isEmpty) return;
    final uri = Uri.parse(
      'https://wa.me/$kOfficeWhatsApp?text=${Uri.encodeComponent(_report)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      await _copy();
      _toast('تعذر فتح واتساب — نُسخ التقرير، ألصقه في أي محادثة');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    _toast('نُسخ التقرير');
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _previewFor(ReviewNote n) {
    if (n.kind == 'q') {
      final id = int.tryParse(n.itemId);
      for (final q in widget.pack.questions) {
        if (q.id == id) return q.stem;
      }
    } else if (n.kind == 'c') {
      final id = int.tryParse(n.itemId);
      for (final c in widget.pack.cards) {
        if (c.id == id) return c.front;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final notes = _all.values.toList()
      ..sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
    final okN = notes.where((n) => n.verdict == ReviewVerdict.ok).length;
    final editN = notes.where((n) => n.verdict == ReviewVerdict.edit).length;
    final rmN = notes.where((n) => n.verdict == ReviewVerdict.remove).length;

    return Scaffold(
      appBar: AppBar(title: const Text('ملاحظاتي 📝')),
      body: Column(
        children: [
          const ReviewBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('راجعتَ', style: txt.titleMedium),
                        Text(
                          '${ArabicNumber.from(notes.length)} من '
                          '${ArabicNumber.from(_totalItems)}',
                          style: txt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _totalItems == 0
                              ? 0
                              : notes.length / _totalItems,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: [
                            Text('✅ ${ArabicNumber.from(okN)}'),
                            Text('✏️ ${ArabicNumber.from(editN)}'),
                            Text('❌ ${ArabicNumber.from(rmN)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: notes.isEmpty ? null : _sendWhatsApp,
                        icon: const Icon(Icons.send),
                        label: const Text('إرسال بواتساب'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: notes.isEmpty ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'لا ملاحظات بعد.\nتصفّح الدروس والتدريب والمبارزة، '
                      'واضغط ✏️ على أي بند لتسجيل رأيك.',
                      textAlign: TextAlign.center,
                      style: txt.bodyMedium,
                    ),
                  )
                else
                  for (final n in notes)
                    Card(
                      child: ListTile(
                        leading: Text(
                          n.verdict.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text('${n.label} — ${n.verdict.ar}'),
                        subtitle: Text(
                          n.text.isNotEmpty ? n.text : _previewFor(n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await widget.notes.remove(n.key);
                            await _reload();
                          },
                        ),
                        onTap: () async {
                          await showReviewNoteDialog(
                            context,
                            store: widget.notes,
                            kind: n.kind,
                            itemId: n.itemId,
                            preview: _previewFor(n),
                          );
                          await _reload();
                        },
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
