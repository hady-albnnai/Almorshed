import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/cards_service.dart';
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';
import 'card_review_screen.dart';

/// F3.4 — بوابة البطاقات: طابور اليوم (سقف ٢٠ + ٦ جديدة) بجدول FSRS.
/// الطابور يُجمَّد عند أول بدء — عدالة «مهام اليوم» (نمط التدريب).
class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.pack,
    required this.trainingStore,
  });

  final ContentPack pack;
  final TrainingStore trainingStore;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
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

  Future<void> _startOrResume(CardDayState day) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CardReviewScreen(
        pack: widget.pack,
        trainingStore: widget.trainingStore,
        data: TrainingData(
          daily: _data.daily,
          mistakes: _data.mistakes,
          cardStates: _data.cardStates,
          cardDay: day,
        ),
      ),
    ));
    _reload(); // تحديث البوابة عند العودة (نمط F3.1)
  }

  Future<void> _startToday() async {
    final todayKey = dateKeyOf(DateTime.now());
    final prepared = startCardDay(
      _data,
      cards: widget.pack.cards,
      todayKey: todayKey,
    );
    if (prepared.cardDay == null) return; // لا بطاقات
    await widget.trainingStore.save(prepared);
    if (!mounted) return; // فجوة غير متزامنة قبل استخدام context
    await _startOrResume(prepared.cardDay!);
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final todayKey = dateKeyOf(DateTime.now());
    final total = widget.pack.cards.length;

    return Scaffold(
      appBar: AppBar(title: const Text('البطاقات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Text('بطاقات اليوم', style: txt.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (total == 0) ...[
                          const Icon(Icons.style_outlined, size: 42),
                          const SizedBox(height: 10),
                          Text('لا بطاقات بعد — قيد الإعداد',
                              style: txt.titleMedium,
                              textAlign: TextAlign.center),
                        ] else ...[
                          _buildDaySection(todayKey, txt),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('الجدول', style: txt.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: Text(
                        'مجموع البطاقات: ${ArabicNumber.from(total)}'),
                    subtitle: const Text(
                        'تكرار متباعد FSRS — كل بطاقة تُستدعى وقت نسيانها '
                        'تقريباً (سقف ٢٠ يومياً · ٦ جديدة)'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDaySection(String todayKey, TextTheme txt) {
    final frozen = _data.cardDay;

    // ⚠️ فحص null مباشر — دارت لا تروّج عبر متغير وسيط (isToday كان
    // يكسر الترويج فيصير frozen.finished خطأ تصريف — علّة F3.4)
    if (frozen != null && frozen.dateKey == todayKey) {
      if (frozen.finished) {
        return Column(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 42),
            const SizedBox(height: 10),
            Text('✓ أنهيت بطاقات اليوم! +١٥ نقطة',
                style: txt.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('المراجعة القادمة غداً حسب جدول FSRS',
                style: txt.bodyMedium, textAlign: TextAlign.center),
          ],
        );
      }
      return Column(
        children: [
          Text(
              'تقدّمك: ${ArabicNumber.from(frozen.doneCount)} من '
              '${ArabicNumber.from(frozen.queue.length)}',
              style: txt.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: frozen.queue.isEmpty
                  ? 0
                  : frozen.doneCount / frozen.queue.length),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _startOrResume(frozen),
            child: const Text('أكمل المراجعة'),
          ),
        ],
      );
    }

    // لا يوم مجمد — عرض استباقي للطابور المتوقع
    final preview = todayCardQueue(_data, widget.pack.cards, todayKey);
    final dueCount = preview
        .where((id) => _data.cardStates[id]?.isDueOnOrAfter(todayKey) ?? false)
        .length;
    final freshCount = preview.length - dueCount;
    return Column(
      children: [
        Text('طابور اليوم: ${ArabicNumber.from(preview.length)} بطاقات',
            style: txt.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
            '${ArabicNumber.from(dueCount)} مراجعة + ${ArabicNumber.from(freshCount)} جديدة',
            style: txt.bodyMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: preview.isEmpty ? null : _startToday,
          child: const Text('ابدأ مراجعة البطاقات'),
        ),
      ],
    );
  }
}
