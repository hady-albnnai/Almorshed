// ═══════════════════════════════════════════════════════════════════════
// review_widgets.dart — عناصر وضع المراجعة (F2.4/F6.2 المُبسّط):
//  • ReviewScope: يوفّر حالة الوضع لكل الشجرة (InheritedWidget — بلا حزم).
//  • ReviewBanner: شريط أصفر رفيع دائم أعلى الشاشات.
//  • ReviewNoteButton: زر ✏️ صغير يفتح نافذة الملاحظة على بند.
// كلها ترسم لا شيء عندما يكون الوضع مطفأً ⇒ صفر أثر على الطالب.
// ═══════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../core/review/review_mode.dart';

/// حالة وضع المراجعة المتاحة للشجرة كلها.
class ReviewScope extends InheritedWidget {
  const ReviewScope({
    super.key,
    required this.enabled,
    required this.unapprovedQuestionIds,
    required this.notes,
    required super.child,
  });

  final bool enabled;
  final Set<int> unapprovedQuestionIds;
  final ReviewNotesStore notes;

  static ReviewScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReviewScope>();

  static bool enabledIn(BuildContext context) =>
      maybeOf(context)?.enabled ?? false;

  @override
  bool updateShouldNotify(ReviewScope old) =>
      enabled != old.enabled ||
      unapprovedQuestionIds != old.unapprovedQuestionIds;
}

/// شريط «وضع المراجعة» — يُدرج أعلى body الشاشات الرئيسية.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ReviewScope.enabledIn(context)) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFF5C518),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: const [
            Icon(Icons.rate_review_outlined, size: 16, color: Colors.black87),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'وضع المراجعة — ملاحظاتك تُحفظ تلقائياً',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة صغيرة «قيد المراجعة» — للأسئلة غير المعتمدة أصلاً.
class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key, required this.questionId});
  final int questionId;

  @override
  Widget build(BuildContext context) {
    final s = ReviewScope.maybeOf(context);
    if (s == null ||
        !s.enabled ||
        !s.unapprovedQuestionIds.contains(questionId)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5C518).withValues(alpha: .25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5C518)),
      ),
      child: const Text(
        'قيد المراجعة',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// زر ملاحظة ✏️ على بند — يظهر بوضع المراجعة فقط.
class ReviewNoteButton extends StatelessWidget {
  const ReviewNoteButton({
    super.key,
    required this.kind, // q | c | p
    required this.itemId,
    this.preview = '',
  });

  final String kind;
  final String itemId;
  final String preview;

  @override
  Widget build(BuildContext context) {
    final s = ReviewScope.maybeOf(context);
    if (s == null || !s.enabled) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'ملاحظة للمطوّر',
      icon: const Icon(Icons.edit_note, color: Color(0xFFB8860B)),
      onPressed: () => showReviewNoteDialog(
        context,
        store: s.notes,
        kind: kind,
        itemId: itemId,
        preview: preview,
      ),
    );
  }
}

/// نافذة الملاحظة: ثلاثة أحكام سريعة + جملة اختيارية — حفظ فوري.
Future<void> showReviewNoteDialog(
  BuildContext context, {
  required ReviewNotesStore store,
  required String kind,
  required String itemId,
  String preview = '',
}) async {
  final key = '$kind:$itemId';
  final existing = (await store.load())[key];
  if (!context.mounted) return;
  var verdict = existing?.verdict ?? ReviewVerdict.ok;
  final ctrl = TextEditingController(text: existing?.text ?? '');
  final label = ReviewNote(
    kind: kind,
    itemId: itemId,
    verdict: verdict,
    updatedMs: 0,
  ).label;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text('ملاحظة — $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  preview.length > 90
                      ? '${preview.substring(0, 90)}…'
                      : preview,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 6,
              children: [
                for (final v in ReviewVerdict.values)
                  ChoiceChip(
                    label: Text('${v.emoji} ${v.ar}'),
                    selected: verdict == v,
                    onSelected: (_) => setD(() => verdict = v),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'ما الخطأ؟ (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await store.remove(key);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('حذف الملاحظة'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              await store.put(
                ReviewNote(
                  kind: kind,
                  itemId: itemId,
                  verdict: verdict,
                  text: ctrl.text.trim(),
                  updatedMs: DateTime.now().millisecondsSinceEpoch,
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
