import 'package:flutter/material.dart';

import '../../core/content/generated_items.dart';
import '../../core/grading/grading_engine.dart';
import '../../core/util/arabic_number.dart';
import '../review/review_widgets.dart';

/// نمط الإجابة الفعلي: البند الرقمي بلا مفتاح رقمي (زاوية/رمزي) و«علّل»
/// بلا مفاتيح والبرهان بلا خطوات يعودون إلى الخيارات الأربعة — لا تخمين.
ItemKind answerModeOf(GeneratedItem i) => switch (i.kind) {
      ItemKind.numeric when i.numericAnswer == null => ItemKind.mcq,
      ItemKind.why when i.keys.isEmpty => ItemKind.mcq,
      ItemKind.proof when i.proofSteps.isEmpty => ItemKind.mcq,
      _ => i.kind,
    };

/// المادة ١٢ — جلسة تدريب على البنود المولّدة (المادة ١٠) بمحرك التصحيح
/// (المادة ١١): أربعة أنماط إجابة، تصحيح فوري، وملاحظات السلم لكل مشتت.
///
/// • اختياري: أربع بطاقات — الصحيح أخضر، المختار الخاطئ أحمر، ولكل خيار
///   سبب خطئه من `solutionSteps` (قاعدة المشتت الموثّقة).
/// • رقمي: حقل قيمة + حقل وحدة ⇒ ±٢٪ والوحدة درجة مستقلة (قاعدة السلم ٢).
/// • «علّل»: حقل نصي حر ⇒ مفاتيح بتطبيع عربي + مفاتيح مضادة.
/// • برهان: بطاقات الخطوات مبعثرة يرتّبها الطالب بالنقر، ويشير قبل التصحيح
///   إن كتب المعادلة بلا إشارة سالبة أو التابع بلا φ (خصما السلم −٤/−١).
///
/// بلا حفظ وسيط وبلا XP (البنود غير معتمدة بعد — قرار ٢٤): جلسة عرض وتصحيح
/// فقط، والأستاذ يراها في وضع المراجعة كاملة.
class ItemSessionScreen extends StatefulWidget {
  const ItemSessionScreen({
    super.key,
    required this.items,
    this.title = 'تدريب الوحدة الأولى',
    this.initialIndex = 0,
  });

  final List<GeneratedItem> items;
  final String title;

  /// البدء من بند بعينه (فهرس مراجعة الأستاذ — المادة ١٣).
  final int initialIndex;

  @override
  State<ItemSessionScreen> createState() => _ItemSessionScreenState();
}

class _ItemSessionScreenState extends State<ItemSessionScreen> {
  late int _current = widget.items.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
  final Map<int, GradeResult> _results = {};
  final Map<int, int> _chosen = {};

  /// نصّ الإجابة المدخلة قبل التصحيح (رقمي/علّل) — يُعرض بعد التصحيح كما هو.
  final Map<int, String> _typed = {};

  bool _summary = false;

  int get _total => widget.items.length;
  GeneratedItem get _item => widget.items[_current];
  bool get _answered => _results.containsKey(_item.id);

  void _grade(GradeResult r, {int? chosen, String? typed}) {
    setState(() {
      _results[_item.id] = r;
      if (chosen != null) _chosen[_item.id] = chosen;
      if (typed != null) _typed[_item.id] = typed;
    });
  }

  double get _points =>
      _results.values.fold<double>(0, (s, r) => s + r.points);
  double get _maxPoints =>
      widget.items.fold<double>(0, (s, i) => s + _maxOf(i));

  double _maxOf(GeneratedItem i) {
    final r = _results[i.id];
    if (r != null) return r.maxPoints;
    if (answerModeOf(i) == ItemKind.proof) {
      return i.proofSteps
          .fold<double>(0, (s, st) => s + (st['points'] as num).toDouble());
    }
    return i.weight;
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لا بنود معتمدة بعد — بانتظار مصادقة الأستاذ.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_summary) return _buildSummary(context);

    final item = _item;
    final mode = answerModeOf(item);
    final txt = Theme.of(context).textTheme;
    final result = _results[item.id];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'بند ${ArabicNumber.from(_current + 1)} من ${ArabicNumber.from(_total)}',
        ),
        actions: [
          ReviewNoteButton(kind: 'g', itemId: '${item.id}', preview: item.stem),
        ],
      ),
      body: Column(
        children: [
          const ReviewBanner(),
          LinearProgressIndicator(value: _results.length / _total),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _KindChip(
                  kind: mode,
                  chapter: item.chapter,
                  pending: !item.approved && ReviewScope.enabledIn(context),
                ),
                const SizedBox(height: 8),
                Text(item.stem, style: txt.titleMedium),
                const SizedBox(height: 14),
                switch (mode) {
                  ItemKind.mcq => _McqBody(
                      key: ValueKey('mcq-${item.id}'),
                      item: item,
                      chosen: _chosen[item.id],
                      onChoose: _answered
                          ? null
                          : (k) => _grade(
                                gradeMcq(
                                  chosenIndex: k,
                                  correctIndex: item.correctIndex,
                                  weight: item.weight,
                                ),
                                chosen: k,
                              ),
                    ),
                  ItemKind.numeric => _NumericBody(
                      key: ValueKey('num-${item.id}'),
                      item: item,
                      result: result,
                      typed: _typed[item.id],
                      onSubmit: (raw) => _grade(
                        gradeItem(item.raw, raw), // ±٢٪ + الوحدة درجة مستقلة
                        typed: raw,
                      ),
                    ),
                  ItemKind.why => _WhyBody(
                      key: ValueKey('why-${item.id}'),
                      item: item,
                      result: result,
                      typed: _typed[item.id],
                      onSubmit: (text) => _grade(
                        gradeItem(item.raw, text),
                        typed: text,
                      ),
                    ),
                  ItemKind.proof => _ProofBody(
                      key: ValueKey('proof-${item.id}'),
                      item: item,
                      result: result,
                      onSubmit: (attempt) => _grade(gradeItem(item.raw, attempt)),
                    ),
                },
                if (result != null) ...[
                  const SizedBox(height: 16),
                  _ResultCard(item: item, result: result),
                ],
              ],
            ),
          ),
          if (_answered)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: FilledButton(
                  onPressed: () {
                    if (_current + 1 >= _total) {
                      setState(() => _summary = true);
                    } else {
                      setState(() => _current++);
                    }
                  },
                  child: Text(_current + 1 >= _total ? 'النتيجة' : 'التالي ←'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final ratio = _maxPoints == 0 ? 0.0 : _points / _maxPoints;
    final msg = ratio >= 0.999
        ? 'ما شاء الله — كامل!'
        : ratio >= 0.7
            ? 'قوي! راجع ملاحظات السلم على ما خُصم'
            : 'لا بأس — كل مشتت له سببه، اقرأ الملاحظات وأعد';
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة الجلسة')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_outlined, size: 64),
            const SizedBox(height: 12),
            Text('أنهيت الجلسة!', style: txt.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${_fmt(_points)} من ${_fmt(_maxPoints)} درجة',
              style: txt.displaySmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(msg, style: txt.bodyLarge, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }
}

/// درجة بأرقام عربية-هندية: الصحيحة بلا كسر، وإلا بمنزلة واحدة.
String _fmt(double v) {
  final tenths = (v * 10).round();
  if (tenths % 10 == 0) return ArabicNumber.from(tenths ~/ 10);
  return '${ArabicNumber.from(tenths ~/ 10)}٫${ArabicNumber.from(tenths % 10)}';
}

// ───────────────────────────── شارة النمط ─────────────────────────────

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.chapter,
    this.pending = false,
  });
  final ItemKind kind;
  final String chapter;

  /// وضع المراجعة: البند غير معتمد بعد ⇒ شارة «قيد المراجعة».
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      ItemKind.mcq => 'اختيار من متعدد',
      ItemKind.numeric => 'حساب — القيمة والوحدة',
      ItemKind.why => 'علّل',
      ItemKind.proof => 'برهان — رتّب الخطوات',
    };
    final ch = switch (chapter) {
      'U1C1' => 'النواس المرن',
      'U1C2' => 'نواس الفتل',
      'U1C3' => 'النواس الثقلي',
      _ => chapter,
    };
    return Wrap(
      spacing: 6,
      children: [
        Chip(label: Text(label), visualDensity: VisualDensity.compact),
        Chip(label: Text(ch), visualDensity: VisualDensity.compact),
        if (pending)
          const Chip(
            label: Text('قيد المراجعة'),
            visualDensity: VisualDensity.compact,
            backgroundColor: Color(0x40F5C518),
            side: BorderSide(color: Color(0xFFF5C518)),
          ),
      ],
    );
  }
}

// ───────────────────────────── اختياري ─────────────────────────────

enum _OptionState { idle, correct, wrong, dimmed }

class _McqBody extends StatelessWidget {
  const _McqBody({
    super.key,
    required this.item,
    required this.chosen,
    required this.onChoose,
  });

  final GeneratedItem item;
  final int? chosen;
  final ValueChanged<int>? onChoose;

  @override
  Widget build(BuildContext context) {
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
    final answered = chosen != null;
    return Column(
      children: [
        for (var k = 0; k < item.options.length; k++)
          _OptionTile(
            letter: letters[k],
            text: item.options[k],
            state: !answered
                ? _OptionState.idle
                : (k == item.correctIndex
                    ? _OptionState.correct
                    : (k == chosen ? _OptionState.wrong : _OptionState.dimmed)),
            onTap: onChoose == null ? null : () => onChoose!(k),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color? bg;
    Color? border;
    Icon? lead;
    switch (state) {
      case _OptionState.idle:
        break;
      case _OptionState.correct:
        bg = Colors.green.withValues(alpha: 0.15);
        border = Colors.green;
        lead = const Icon(Icons.check_circle_outline, color: Colors.green);
      case _OptionState.wrong:
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red;
        lead = const Icon(Icons.cancel_outlined, color: Colors.red);
      case _OptionState.dimmed:
        border = cs.outline.withValues(alpha: 0.3);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: bg ?? cs.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: ListTile(
          leading: lead ?? CircleAvatar(child: Text(letter)),
          title: Text(text),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ───────────────────────────── رقمي ─────────────────────────────

class _NumericBody extends StatefulWidget {
  const _NumericBody({
    super.key,
    required this.item,
    required this.result,
    required this.typed,
    required this.onSubmit,
  });

  final GeneratedItem item;
  final GradeResult? result;
  final String? typed;
  final ValueChanged<String> onSubmit;

  @override
  State<_NumericBody> createState() => _NumericBodyState();
}

class _NumericBodyState extends State<_NumericBody> {
  final _value = TextEditingController();
  final _unit = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.result != null;
    final txt = Theme.of(context).textTheme;
    if (done) {
      final item = widget.item;
      final a = item.numericAnswer;
      final key = item.correctIndex >= 0 && item.correctIndex < item.options.length
          ? item.options[item.correctIndex]
          : (a == null ? '' : '${a.value} ${a.unit}');
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إجابتك: ${widget.typed ?? ''}', style: txt.bodyLarge),
              Text(
                'المفتاح: $key',
                style: txt.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                key: const Key('numeric-value'),
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'القيمة',
                  hintText: 'مثال: −0.4 أو 8π/5 أو √10',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                key: const Key('numeric-unit'),
                controller: _unit,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الوحدة',
                  hintText: 'm·s⁻¹ أو m/s',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'الوحدة درجة مستقلة في السلم — لا تنسَها.',
          style: txt.bodySmall,
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          key: const Key('numeric-submit'),
          onPressed: () {
            final raw = '${_value.text.trim()} ${_unit.text.trim()}'.trim();
            if (raw.isEmpty) return;
            widget.onSubmit(raw);
          },
          child: const Text('صحّح'),
        ),
      ],
    );
  }
}

// ───────────────────────────── علّل ─────────────────────────────

class _WhyBody extends StatefulWidget {
  const _WhyBody({
    super.key,
    required this.item,
    required this.result,
    required this.typed,
    required this.onSubmit,
  });

  final GeneratedItem item;
  final GradeResult? result;
  final String? typed;
  final ValueChanged<String> onSubmit;

  @override
  State<_WhyBody> createState() => _WhyBodyState();
}

class _WhyBodyState extends State<_WhyBody> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    if (widget.result != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إجابتك: ${widget.typed ?? ''}', style: txt.bodyLarge),
              const SizedBox(height: 6),
              Text('مفاتيح السلم:', style: txt.titleSmall),
              for (final k in widget.item.keys) Text('• $k'),
              if (widget.item.options.isNotEmpty &&
                  widget.item.correctIndex >= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'الصياغة النموذجية: ${widget.item.options[widget.item.correctIndex]}',
                    style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('why-text'),
          controller: _text,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'اكتب التعليل بلغة الكتاب',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          key: const Key('why-submit'),
          onPressed: () {
            final t = _text.text.trim();
            if (t.isEmpty) return;
            widget.onSubmit(t);
          },
          child: const Text('صحّح'),
        ),
      ],
    );
  }
}

// ───────────────────────────── برهان ─────────────────────────────

class _ProofBody extends StatefulWidget {
  const _ProofBody({
    super.key,
    required this.item,
    required this.result,
    required this.onSubmit,
  });

  final GeneratedItem item;
  final GradeResult? result;
  final ValueChanged<ProofAttempt> onSubmit;

  @override
  State<_ProofBody> createState() => _ProofBodyState();
}

class _ProofBodyState extends State<_ProofBody> {
  late final List<Map<String, dynamic>> _steps;
  late final List<int> _shuffled;
  final List<int> _picked = [];
  final Map<int, Set<String>> _flags = {};

  @override
  void initState() {
    super.initState();
    _steps = widget.item.proofSteps;
    final ns = [for (final s in _steps) s['n'] as int];
    // بعثرة حتمية بالمعرف — نفس البند نفس الترتيب في كل فتح
    final seed = widget.item.id;
    _shuffled = List<int>.from(ns);
    for (var i = _shuffled.length - 1; i > 0; i--) {
      final j = (seed * 7919 + i * 104729) % (i + 1);
      final t = _shuffled[i];
      _shuffled[i] = _shuffled[j];
      _shuffled[j] = t;
    }
  }

  Map<String, dynamic> _stepOf(int n) => _steps.firstWhere((s) => s['n'] == n);

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final done = widget.result != null;
    final remaining = [for (final n in _shuffled) if (!_picked.contains(n)) n];
    final total = _steps.fold<num>(0, (s, st) => s + (st['points'] as num));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'رتّب خطوات البرهان بالنقر عليها بالتسلسل (المجموع ${ArabicNumber.from(total.toInt())} درجة):',
          style: txt.bodyMedium,
        ),
        const SizedBox(height: 8),
        if (_picked.isNotEmpty)
          Card(
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ترتيبك:', style: txt.titleSmall),
                  for (var i = 0; i < _picked.length; i++)
                    _PickedStep(
                      index: i,
                      step: _stepOf(_picked[i]),
                      flags: _flags[_picked[i]] ?? const {},
                      enabled: !done,
                      onRemove: () => setState(() {
                        _picked.removeAt(i);
                      }),
                      onFlag: (f, checked) => setState(() {
                        final set = _flags.putIfAbsent(_picked[i], () => {});
                        if (checked) {
                          set.add(f);
                        } else {
                          set.remove(f);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        if (!done)
          for (final n in remaining)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  key: Key('proof-step-$n'),
                  leading: const Icon(Icons.drag_indicator),
                  title: Text(_stepOf(n)['text'] as String),
                  onTap: () => setState(() => _picked.add(n)),
                ),
              ),
            ),
        if (!done) ...[
          const SizedBox(height: 10),
          FilledButton.tonal(
            key: const Key('proof-submit'),
            onPressed: _picked.isEmpty
                ? null
                : () => widget.onSubmit(
                      ProofAttempt(
                        orderedStepNumbers: List<int>.from(_picked),
                        flags: {
                          for (final e in _flags.entries)
                            if (e.value.isNotEmpty) e.key: Set.of(e.value),
                        },
                      ),
                    ),
            child: const Text('صحّح'),
          ),
        ],
        if (done) ...[
          const SizedBox(height: 8),
          Text('الترتيب المرجعي بعلامات السلم:', style: txt.titleSmall),
          for (final s in _steps)
            Text(
              '${ArabicNumber.from(s['n'] as int)}. ${s['text']} '
              '(${ArabicNumber.from((s['points'] as num).toInt())})',
            ),
        ],
      ],
    );
  }
}

class _PickedStep extends StatelessWidget {
  const _PickedStep({
    required this.index,
    required this.step,
    required this.flags,
    required this.enabled,
    required this.onRemove,
    required this.onFlag,
  });

  final int index;
  final Map<String, dynamic> step;
  final Set<String> flags;
  final bool enabled;
  final VoidCallback onRemove;
  final void Function(String flag, bool checked) onFlag;

  @override
  Widget build(BuildContext context) {
    final penalty = (step['penalty'] as Map<String, dynamic>?) ?? const {};
    String pen(Object? v) => ArabicNumber.from((v as num).abs().toInt());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 13,
            child: Text(ArabicNumber.from(index + 1)),
          ),
          title: Text(step['text'] as String),
          trailing: enabled
              ? IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'إرجاع',
                  onPressed: onRemove,
                )
              : null,
        ),
        // إعلانات الصدق: هل كتبتها بلا إشارة/بلا φ؟ (خصما السلم −٤/−١)
        for (final e in penalty.entries)
          // e.value سالب (−4/−1) ⇒ نعرضه «−٤»
          CheckboxListTile(
            key: Key('flag-${step['n']}-${e.key}'),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: flags.contains(e.key),
            onChanged: enabled ? (v) => onFlag(e.key, v ?? false) : null,
            title: Text(
              switch (e.key) {
                'missing_minus' => 'كتبتها بلا الإشارة السالبة (−${pen(e.value)})',
                'missing_phi' => 'كتبت التابع بلا الطور φ (−${pen(e.value)})',
                _ => '${e.key} (−${pen(e.value)})',
              },
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────── بطاقة النتيجة ─────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.result});
  final GeneratedItem item;
  final GradeResult result;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = result.correct
        ? Colors.green
        : (result.points > 0 ? Colors.orange : Colors.red);
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.correct ? Icons.check_circle : Icons.info_outline,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fmt(result.points)} / ${_fmt(result.maxPoints)}',
                  style: txt.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final n in result.notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text('▪ $n', style: txt.bodyMedium),
                ),
            ],
            if (answerModeOf(item) == ItemKind.mcq &&
                item.solutionSteps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('📌 لماذا كل خيار؟', style: txt.titleSmall),
              const SizedBox(height: 4),
              for (final s in item.solutionSteps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(s, style: txt.bodyMedium),
                ),
            ],
            if (item.answerBasis != null && item.answerBasis!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('المرجع: ${item.answerBasis}', style: txt.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
