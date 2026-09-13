import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';
import '../../core/xp/streak_service.dart';

/// F3.3/M4-جيب — أرشيف أخطائي + حلقة المراجعة (mistakesFive):
/// «فهمت ✓» لكل خطأ → وقتُه يتقدم فيرتّب لآخر الأرشيف (دوران)،
/// والخامسة اليوم ⇒ +١٠ تلقائياً (السقف اليومي بالدفتر يمنع التكرار).
class MistakesScreen extends StatefulWidget {
  const MistakesScreen({
    super.key,
    required this.pack,
    required this.trainingStore,
    this.xpRecorder,
  });

  final ContentPack pack;
  final TrainingStore trainingStore;

  /// مُسجّل XP — null بالاختبارات القديمة = بلا مكافأة مراجعة.
  final XpRecorder? xpRecorder;

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  TrainingData _data = const TrainingData();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final data = await widget.trainingStore.load();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  /// مراجعات اليوم — مشتقة من أزمنة السجلات نفسها (بلا مخطط جديد).
  int _reviewedTodayCount(DateTime now) {
    final today = studyDateKeyOf(now);
    return _data.mistakes
        .where((m) =>
            studyDateKeyOf(DateTime.fromMillisecondsSinceEpoch(m.atMs)) ==
            today)
        .length;
  }

  bool _isReviewedToday(MistakeRecord m, DateTime now) =>
      studyDateKeyOf(DateTime.fromMillisecondsSinceEpoch(m.atMs)) ==
      studyDateKeyOf(now);

  Future<void> _review(MistakeRecord m) async {
    if (_busy) return;
    setState(() => _busy = true);
    final now = DateTime.now();
    final before = _reviewedTodayCount(now);
    final updated = <MistakeRecord>[
      for (final x in _data.mistakes)
        if (x.questionId == m.questionId && x.atMs == m.atMs)
          MistakeRecord(
            questionId: x.questionId,
            chosenIndex: x.chosenIndex,
            correctIndex: x.correctIndex,
            atMs: now.millisecondsSinceEpoch, // للأرشيف الأخير — دوران
          )
        else
          x,
    ];
    await widget.trainingStore
        .save(TrainingData(daily: _data.daily, mistakes: updated));
    // الخامسة اليوم ⇒ +١٠ (السقف اليومي بالدفتر يحمي من أي تكرار)
    if (before == 4) {
      await widget.xpRecorder?.record('mistakesFive');
    }
    if (!mounted) return;
    if (before == 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أتممت مراجعة خمسة أخطاء اليوم — +١٠ نقاط! 🎯'),
      ));
    }
    await _reload();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final questions = {for (final q in widget.pack.questions) q.id: q};
    final now = DateTime.now();
    final reviewedToday = _reviewedTodayCount(now);

    return Scaffold(
      appBar: AppBar(title: const Text('أخطائي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data.mistakes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sentiment_satisfied_outlined, size: 52),
                      const SizedBox(height: 10),
                      Text('لا أخطاء محفوظة — واصل التدريب!',
                          style: txt.titleMedium),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // شريط تقدم المراجعة اليومية (خمسة ⇒ +١٠)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? AppColors.darkLine
                                : AppColors.lightLine),
                      ),
                      child: Text(
                        'راجعت ${ArabicNumber.from(reviewedToday)} من ٥ اليوم'
                        '${reviewedToday >= 5 ? ' — المكافأة صارت ✓' : ' — الخامسة تمنحك +١٠'}',
                        style: txt.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          for (final m in _data.mistakes)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      questions[m.questionId]?.stem ??
                                          'سؤال غير متوفر بالحزمة الحالية (#${m.questionId})',
                                      style: txt.titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    if (questions[m.questionId] != null) ...[
                                      Text(
                                        '✗ اخترت: ${questions[m.questionId]!.options[m.chosenIndex]}',
                                        style: txt.bodyMedium
                                            ?.copyWith(color: Colors.red),
                                      ),
                                      Text(
                                        '✓ الصحيح: ${questions[m.questionId]!.options[m.correctIndex]}',
                                        style: txt.bodyMedium?.copyWith(
                                            color: Colors.green),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    if (widget.xpRecorder != null)
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: _isReviewedToday(m, now)
                                            ? Text(
                                                'رُوجع اليوم ✓',
                                                style: txt.bodySmall?.copyWith(
                                                    color: Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? AppColors.darkTxt2
                                                        : AppColors
                                                            .lightTxt2),
                                              )
                                            : TextButton.icon(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _review(m),
                                                icon: const Icon(
                                                    Icons.check_circle_outline,
                                                    size: 18),
                                                label: const Text('فهمت ✓'),
                                              ),
                                      ),
                                  ],
                                ),
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
