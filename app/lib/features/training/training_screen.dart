import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../../core/util/arabic_number.dart';
import 'cards_screen.dart';
import 'batch_session_screen.dart';
import 'mistakes_screen.dart';

/// F3.3 — بوابة التدريب: دفعة اليوم (بذرة يومية حتمية) + أرشيف أخطائي.
/// البنك المعتمد حصراً (قرار ٢٤): قبل مصادقة الأستاذ تظهر شاشة الانتظار.
class TrainingScreen extends StatefulWidget {
  /// F3.8 — اختياري: null = بلا تسجيل (اختبارات قديمة سليمة).
  final XpRecorder? xpRecorder;

  const TrainingScreen({
    super.key,
    required this.pack,
    required this.trainingStore,
    this.deviceId = 0,
      this.xpRecorder, // F3.8
  });

  final ContentPack pack;
  final TrainingStore trainingStore;

  /// يُربط بمعرف الجهاز الحقيقي في F3.6/F3.7 — صفر مؤقتاً.
  final int deviceId;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  TrainingData _data = const TrainingData();
  bool _loading = true;

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

  DailyBatchState? _todayState(String todayKey) {
    final d = _data.daily;
    return (d != null && d.dateKey == todayKey) ? d : null;
  }

  Future<void> _openSession(DailyBatchState state) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BatchSessionScreen(
        pack: widget.pack,
        trainingStore: widget.trainingStore,
          xpRecorder: widget.xpRecorder,
        // الحالة الفعلية + الأرشيف الحالي — لا حالة قديمة أبداً
        data: TrainingData(daily: state, mistakes: _data.mistakes),
        deviceId: widget.deviceId,
      ),
    ));
    _reload(); // تحديث البوابة عند العودة (نمط F3.1)
  }

  Future<void> _startToday() async {
    final todayKey = dateKeyOf(DateTime.now());
    final batch = buildDailyBatch(
      widget.pack,
      dateKey: todayKey,
      deviceId: widget.deviceId,
    );
    if (batch == null) return; // نظرياً: الزر معطل حين لا بنك
    final state = DailyBatchState(
        dateKey: todayKey, order: batch.session.questionIds);
    await widget.trainingStore.save(
        TrainingData(daily: state, mistakes: _data.mistakes));
    if (!mounted) return; // فجوة غير متزامنة قبل استخدام context
    await _openSession(state);
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final todayKey = dateKeyOf(DateTime.now());
    final pool = widget.pack.approvedQuestions.length;
    final state = _todayState(todayKey);
    final planned = pool < 10 ? pool : 10;

    return Scaffold(
      appBar: AppBar(title: const Text('التدريب')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Text('دفعة اليوم', style: txt.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (pool == 0) ...[
                          const Icon(Icons.lock_outline, size: 42),
                          const SizedBox(height: 10),
                          Text('بانتظار مصادقة الأستاذ',
                              style: txt.titleMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          Text(
                            'بانك الأسئلة (${ArabicNumber.from(widget.pack.questions.length)} سؤالاً) '
                            'محجوب عن التدريب حتى الإقرار بها — قرار ٢٤',
                            style: txt.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const FilledButton(
                            onPressed: null,
                            child: Text('الأسئلة لم تُفتح بعد'),
                          ),
                        ] else if (state == null) ...[
                          Text(
                            'دفعة اليوم: ${ArabicNumber.from(planned)} أسئلة — '
                            'نفسها صباحاً ومساءً بالبذرة اليومية',
                            style: txt.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _startToday,
                            child: const Text('ابدأ دفعة اليوم'),
                          ),
                        ] else if (!state.isFinished) ...[
                          Text(
                            'تقدّمك اليوم: ${ArabicNumber.from(state.answeredCount)} '
                            'من ${ArabicNumber.from(state.order.length)}',
                            style: txt.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                              value: state.order.isEmpty
                                  ? 0
                                  : state.answeredCount / state.order.length),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _openSession(state),
                            child: const Text('أكمل دفعة اليوم'),
                          ),
                        ] else ...[
                          const Icon(Icons.emoji_events_outlined, size: 42),
                          const SizedBox(height: 10),
                          Text(
                            '✓ أنهيت دفعة اليوم — النتيجة: '
                            '${ArabicNumber.from(state.score)} من '
                            '${ArabicNumber.from(state.order.length)}',
                            style: txt.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text('دفعة جديدة غداً بنفس العدالة للجميع',
                              style: txt.bodyMedium,
                              textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('بطاقات اليوم', style: txt.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.style_outlined),
                    title: const Text('مراجعة البطاقات'),
                    subtitle: const Text(
                        'طابور FSRS — سقف ٢٠ يومياً + ٦ جديدة'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => CardsScreen(
                          pack: widget.pack,
                          trainingStore: widget.trainingStore,
          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _reload();
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Text('أخطائي', style: txt.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(
                        'الأرشيف: ${ArabicNumber.from(_data.mistakes.length)} خطأ'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => MistakesScreen(
                          pack: widget.pack,
                          trainingStore: widget.trainingStore,
                        ),
                      ));
                      _reload();
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
