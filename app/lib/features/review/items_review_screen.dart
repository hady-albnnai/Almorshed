// ═══════════════════════════════════════════════════════════════════════
// items_review_screen.dart — المادة ١٣: فهرس مراجعة البنود المولّدة
// (جهاز الأستاذ — وضع المراجعة فقط).
//
// • قائمة الـ١٠٠ بند بعدّاد «راجعتَ ن من م» وفلاتر: الفصل، النمط، غير المراجَع.
// • كل صف: المعرّف + النمط + مطلع السؤال + حكم الأستاذ إن وُجد (✅/✏️/❌).
// • نقرة على الصف ⇒ يفتح الجلسة على هذا البند بعينه (يحلّه ويرى التصحيح
//   وسبب كل مشتت) ومن هناك ✏️ في الشريط العلوي تسجّل الحكم.
// • ✏️ في الصف نفسه للحكم السريع بلا حلّ.
// • الملاحظات تُحفظ في ReviewNotesStore نفسه (kind 'g') ⇒ تدخل تقرير واتساب
//   القائم «ملاحظاتي» بصيغة «بند20001: …» — لا مسار إرسال جديد.
// • لا يكتب شيئاً في items_u1.json ولا يرفع علم approved — ذاك قرار المطوّر
//   بعد التقرير (قرار ٢٤: لا أختام مسبقة).
// ═══════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../core/content/generated_items.dart';
import '../../core/review/review_mode.dart';
import '../../core/util/arabic_number.dart';
import '../training/item_session_screen.dart';
import 'review_widgets.dart';

class ItemsReviewScreen extends StatefulWidget {
  const ItemsReviewScreen({
    super.key,
    required this.pack,
    required this.notes,
  });

  final GeneratedItemsPack pack;
  final ReviewNotesStore notes;

  @override
  State<ItemsReviewScreen> createState() => _ItemsReviewScreenState();
}

class _ItemsReviewScreenState extends State<ItemsReviewScreen> {
  Map<String, ReviewNote> _notes = {};
  bool _loading = true;

  String? _chapter; // null = الكل
  ItemKind? _kind; // null = الكل
  bool _onlyUnreviewed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final m = await widget.notes.load();
    if (!mounted) return;
    setState(() {
      _notes = m;
      _loading = false;
    });
  }

  ReviewNote? _noteOf(GeneratedItem i) => _notes['g:${i.id}'];

  List<GeneratedItem> get _filtered => [
        for (final i in widget.pack.items)
          if ((_chapter == null || i.chapter == _chapter) &&
              (_kind == null || answerModeOf(i) == _kind) &&
              (!_onlyUnreviewed || _noteOf(i) == null))
            i,
      ];

  int get _reviewed =>
      widget.pack.items.where((i) => _noteOf(i) != null).length;

  Future<void> _openAt(GeneratedItem item) async {
    final all = widget.pack.items;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ItemSessionScreen(
        items: all,
        initialIndex: all.indexOf(item),
        title: 'مراجعة البنود',
      ),
    ));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final total = widget.pack.items.length;
    final list = _filtered;
    final chapters = widget.pack.items.map((i) => i.chapter).toSet().toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة البنود المولّدة')),
      body: Column(
        children: [
          const ReviewBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Text('راجعتَ من البنود', style: txt.titleMedium),
                        Text(
                          '${ArabicNumber.from(_reviewed)} من ${ArabicNumber.from(total)}',
                          key: const Key('items-review-counter'),
                          style: txt.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: total == 0 ? 0 : _reviewed / total,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'انقر البند لتحلّه وترى التصحيح وسبب كل مشتت، '
                          'ثم ✏️ لتسجيل حكمك. الأحكام تُرسل من «ملاحظاتي».',
                          style: txt.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('كل الفصول'),
                      selected: _chapter == null,
                      onSelected: (_) => setState(() => _chapter = null),
                    ),
                    for (final c in chapters)
                      ChoiceChip(
                        key: Key('filter-$c'),
                        label: Text(chapterTitleOf(c)),
                        selected: _chapter == c,
                        onSelected: (_) => setState(() => _chapter = c),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('كل الأنماط'),
                      selected: _kind == null,
                      onSelected: (_) => setState(() => _kind = null),
                    ),
                    for (final k in ItemKind.values)
                      ChoiceChip(
                        key: Key('filter-${k.name}'),
                        label: Text(kindTitleOf(k)),
                        selected: _kind == k,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                    FilterChip(
                      key: const Key('filter-unreviewed'),
                      label: const Text('غير المراجَع فقط'),
                      selected: _onlyUnreviewed,
                      onSelected: (v) => setState(() => _onlyUnreviewed = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'المعروض: ${ArabicNumber.from(list.length)} بند',
                  style: txt.bodySmall,
                ),
                const SizedBox(height: 4),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا بنود بهذا الفلتر.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final i in list)
                    _ItemRow(
                      key: Key('item-row-${i.id}'),
                      item: i,
                      note: _noteOf(i),
                      onOpen: () => _openAt(i),
                      onNote: () async {
                        await showReviewNoteDialog(
                          context,
                          store: widget.notes,
                          kind: 'g',
                          itemId: '${i.id}',
                          preview: i.stem,
                        );
                        await _reload();
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.note,
    required this.onOpen,
    required this.onNote,
  });

  final GeneratedItem item;
  final ReviewNote? note;
  final VoidCallback onOpen;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final n = note;
    return Card(
      child: ListTile(
        leading: Text(
          n?.verdict.emoji ?? '⬜',
          style: const TextStyle(fontSize: 20),
        ),
        title: Text(
          item.stem,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${ArabicNumber.from(item.id)} · ${kindTitleOf(answerModeOf(item))}'
          ' · ${chapterTitleOf(item.chapter)}'
          '${n == null ? '' : ' · ${n.verdict.ar}'}'
          '${n != null && n.text.isNotEmpty ? ' — ${n.text}' : ''}',
          style: txt.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          key: Key('note-${item.id}'),
          tooltip: 'حكم سريع',
          icon: const Icon(Icons.edit_note, color: Color(0xFFB8860B)),
          onPressed: onNote,
        ),
        onTap: onOpen,
      ),
    );
  }
}

/// أسماء الفصول والأنماط — تُشارَك مع شاشة الجلسة.
String chapterTitleOf(String chapter) => switch (chapter) {
      'U1C1' => 'النواس المرن',
      'U1C2' => 'نواس الفتل',
      'U1C3' => 'النواس الثقلي',
      _ => chapter,
    };

String kindTitleOf(ItemKind k) => switch (k) {
      ItemKind.mcq => 'اختياري',
      ItemKind.numeric => 'حساب',
      ItemKind.why => 'علّل',
      ItemKind.proof => 'برهان',
    };
