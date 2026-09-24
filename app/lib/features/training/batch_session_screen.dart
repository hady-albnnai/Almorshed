import 'package:flutter/material.dart';

import '../../core/content/math_text.dart';
import '../../core/content/models.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../../core/util/arabic_number.dart';

/// F3.3 — جلسة دفعة اليوم: سؤال/خيارات + تصحيح فوري بخطوات الحل + النتيجة.
/// الحتمية: الجلسة تعيد بناء الخلط من dateKey المحفوظ — أي فتح يعرض نفسه.
/// الحفظ الوسيط يحفظ الأرشيف معه — لا يمسح أخطائي أبداً.
class BatchSessionScreen extends StatefulWidget {
  const BatchSessionScreen({
    super.key,
    required this.pack,
    required this.trainingStore,
    required this.data,
    this.deviceId = 0,
    this.xpRecorder, // F3.8
  });

  final ContentPack pack;
  final TrainingStore trainingStore;

  /// بيانات التدريب الكاملة (daily + أرشيف) — البوابة تمررها بعد التحميل.
  final TrainingData data;
  final int deviceId;

  /// F3.8 — اختياري: إتمام دفعة اليوم +١٥.
  final XpRecorder? xpRecorder;

  @override
  State<BatchSessionScreen> createState() => _BatchSessionScreenState();
}

class _BatchSessionScreenState extends State<BatchSessionScreen> {
  late final TrainingData _initial;
  late DailyBatchState _state;
  late final Map<int, Question> _questions;
  late final DailyBatch? _batch;

  /// فهرس التصفح الصريح — لا قفز تلقائي قبل عرض التصحيح (بق موثق F3.3:
  /// «أول غير مجاب» كان ينتقل للسؤال التالي فور الإجابة فتختفي
  /// بطاقة الخطوات وزر التالي — انكشف ببلصة فحص المالك ٥٦/٦١).
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _initial = widget.data;
    _state = _initial.daily!; // البوابة لا تفتح الجلسة بلا حالة يوم
    _questions = {for (final q in widget.pack.questions) q.id: q};
    _batch = buildDailyBatch(
      widget.pack,
      dateKey: _state.dateKey,
      deviceId: widget.deviceId,
    );
    _current = _firstUnanswered();
  }

  int get _total => _state.order.length;
  int get _answered => _state.answeredCount;

  /// أول سؤال غير مجاب — موضع الاستئناف عند فتح الجلسة حصراً.
  int _firstUnanswered() {
    for (var i = 0; i < _total; i++) {
      if (!_state.answers.containsKey(_state.order[i])) return i;
    }
    return _total - 1; // الكل مجاب (زر النتيجة)
  }

  Question? _questionAt(int i) => _questions[_state.order[i]];
  List<int>? _optionOrderOf(int qid) => _batch?.session.optionOrders[qid];

  Future<void> _choose(int qid, int displayIndex) async {
    if (_state.answers.containsKey(qid)) return;
    setState(() => _state = _state.withAnswer(qid, displayIndex));
    // حفظ فوري مع الأرشيف كما هو — الاستئناف يعمل ولا يمسح أخطائي
    await widget.trainingStore.save(_initial.copyWith(daily: _state));
  }

  Future<void> _finish() async {
    final batch = _batch;
    if (batch == null) return;
    var score = 0;
    final mistakes = <MistakeRecord>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _total; i++) {
      final q = _questionAt(i);
      final order = _optionOrderOf(_state.order[i]);
      if (q == null || order == null) continue;
      final correct = displayCorrectIndex(q, order);
      final chosen = _state.answers[q.id];
      if (chosen == correct) {
        score++;
      } else if (chosen != null) {
        mistakes.add(
          MistakeRecord(
            questionId: q.id,
            chosenIndex: chosen,
            correctIndex: correct,
            atMs: now + i, // ترتيب زمني حتمي داخل الدفعة
          ),
        );
      }
    }
    final finished = _state.finish(score);
    final data = withNewMistakes(_initial.copyWith(daily: finished), mistakes);
    await widget.trainingStore.save(data);
    // F3.8: إتمام دفعة التدريب +١٥ مرة/يوم (موثقة بدفتر XP)
    await widget.xpRecorder?.record('batchDone');
    if (!mounted) return;
    setState(
      () => _result = (finished: finished, mistakesCount: mistakes.length),
    );
  }

  ({DailyBatchState finished, int mistakesCount})? _result;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    if (_batch == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('لا بنك معتمد — أعد الفتح من بوابة التدريب'),
        ),
      );
    }

    // شاشة النتيجة
    final r = _result;
    if (r != null) {
      final ratio = _total == 0 ? 0.0 : r.finished.score / _total;
      final msg = ratio == 1
          ? 'ما شاء الله — كامل صحيح!'
          : ratio >= 0.7
          ? 'قوي! راجع أخطاءك في الأرشيف'
          : 'لا بأس — أرشيف أخطائي يحفظ لك المرات القادمة';
      return Scaffold(
        appBar: AppBar(title: const Text('نتيجة الدفعة')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_outlined, size: 64),
              const SizedBox(height: 12),
              Text('أنهيت دفعة اليوم!', style: txt.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${ArabicNumber.from(r.finished.score)} من ${ArabicNumber.from(_total)}',
                style: txt.displaySmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  msg,
                  style: txt.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('رجوع للتدريب'),
              ),
            ],
          ),
        ),
      );
    }

    // شاشة السؤال
    final i = _current;
    final q = _questionAt(i);
    final order = _optionOrderOf(_state.order[i]);
    if (q == null || order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('سؤال غير متوفر بالحزمة الحالية')),
      );
    }
    final chosen = _state.answers[q.id];
    final correct = displayCorrectIndex(q, order);
    final answered = chosen != null;
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'سؤال ${ArabicNumber.from(i + 1)} من ${ArabicNumber.from(_total)}',
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _answered / _total),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MathText(q.stem, style: txt.titleMedium),
                const SizedBox(height: 14),
                for (var k = 0; k < order.length; k++)
                  _OptionTile(
                    letter: letters[k],
                    text: q.options[order[k]],
                    state: !answered
                        ? _OptionState.idle
                        : (k == correct
                              ? _OptionState.correct
                              : (k == chosen
                                    ? _OptionState.wrong
                                    : _OptionState.dimmed)),
                    onTap: answered ? null : () => _choose(q.id, k),
                  ),
                if (answered && q.solutionSteps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📌 خطوات الحل', style: txt.titleSmall),
                          const SizedBox(height: 6),
                          for (var s = 0; s < q.solutionSteps.length; s++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${ArabicNumber.from(s + 1)}. ${q.solutionSteps[s]}',
                                style: txt.bodyMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (answered)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: FilledButton(
                  onPressed: () {
                    if (i + 1 >= _total) {
                      _finish();
                    } else {
                      setState(() => _current = i + 1); // تصفح صريح
                    }
                  },
                  child: Text(i + 1 >= _total ? 'النتيجة' : 'التالي ←'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

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
          title: MathText(text),
          onTap: onTap,
          enabled: onTap != null,
        ),
      ),
    );
  }
}
