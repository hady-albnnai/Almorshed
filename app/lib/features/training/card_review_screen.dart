import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/fsrs/fsrs5.dart';
import '../../core/theme/app_colors.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/cards_service.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../../core/xp/xp_ledger.dart';
import '../../core/util/arabic_number.dart';

/// F3.4 — جلسة مراجعة البطاقات: كشف/استرجاع + ٣ أزرار تقييم (قرار ٤٢)
/// + شاشة الإتمام (+١٥). التصفح صريح — نفس درس بق القفز الموثق F3.3.
class CardReviewScreen extends StatefulWidget {
  const CardReviewScreen({
    super.key,
    required this.pack,
    required this.trainingStore,
    required this.data,
    this.xpRecorder, // F3.8
  });

  final ContentPack pack;
  final TrainingStore trainingStore;
  final TrainingData data;

  /// F3.8 — اختياري: تسجيل تقييمات البطاقات وإتمام الطابور.
  final XpRecorder? xpRecorder;

  @override
  State<CardReviewScreen> createState() => _CardReviewScreenState();
}

class _CardReviewScreenState extends State<CardReviewScreen> {
  late TrainingData _data;
  late CardDayState _day;
  late final Map<int, CardItem> _cards;
  int _current = 0;
  bool _revealed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _day = _data.cardDay!; // البوابة لا تفتح الجلسة بلا يوم مجمد
    _cards = {for (final c in widget.pack.cards) c.id: c};
    // الاستئناف: أول بطاقة غير منتهية — عند الفتح حصراً (بق القفز موثق)
    _current = _day.doneCount >= _day.queue.length
        ? _day.queue.length - 1
        : _day.doneCount;
  }

  Future<void> _rate(Grade grade) async {
    if (_revealed == false) return; // لا تقييم قبل الكشف
    final cardId = _day.queue[_current];
    final todayKey = dateKeyOf(DateTime.now());
    final wasFinished = _day.finished;
    final updated = applyCardReview(
      _data,
      cardId: cardId,
      grade: grade,
      todayKey: todayKey,
    );
    await widget.trainingStore.save(updated);
    // F3.8: بطاقة مراجعة +١ (بلا سقف) — وإتمام الطابور +١٥ مرة/يوم
    // (ثوابت الأنواع من xp_ledger — لا نصوص حرفية تفقد الاستيراد)
    await widget.xpRecorder?.record(xpCardReview.id);
    if (!wasFinished && updated.cardDay!.finished) {
      await widget.xpRecorder?.record(xpQueueDone.id);
    }
    if (!mounted) return;
    setState(() {
      _data = updated;
      _day = updated.cardDay!;
      _done = _day.finished;
      if (!_done) {
        _current++;
        _revealed = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? AppColors.goldDark
        : AppColors.goldLight;

    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('اكتملت المراجعة')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style_outlined, size: 64),
              const SizedBox(height: 12),
              Text('أنهيت بطاقات اليوم!', style: txt.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '+١٥ نقطة لدوري فيزيا كلاش ✓',
                style: txt.titleMedium?.copyWith(color: gold),
              ),
              const SizedBox(height: 8),
              Text(
                'المراجعة القادمة غداً — نذكّرك بكل بطاقة في وقتها',
                style: txt.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('رجوع للبطاقات'),
              ),
            ],
          ),
        ),
      );
    }

    final card = _cards[_day.queue[_current]];
    if (card == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('بطاقة غير متوفرة بالحزمة الحالية')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'بطاقة ${ArabicNumber.from(_current + 1)} من ${ArabicNumber.from(_day.queue.length)}',
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _day.doneCount / _day.queue.length),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // وجه البطاقة — الكشف بالضغط (قرار ٤٢)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: gold.withValues(alpha: .45)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _revealed
                        ? null
                        : () => setState(() => _revealed = true),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            card.front,
                            style: txt.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          if (!_revealed)
                            Text(
                              'اضغط لكشف الجواب',
                              style: txt.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_revealed) ...[
                  const SizedBox(height: 14),
                  Text(
                    card.back,
                    style: txt.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (card.formula != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      card.formula!,
                      style: txt.headlineSmall?.copyWith(color: gold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'كيف كانت استرجاعك؟',
                    style: txt.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rate(Grade.again),
                          child: const Text('😅 ما عرفتها'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rate(Grade.hard),
                          child: const Text('😔 بصعوبة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _rate(Grade.good),
                          child: const Text('😎 أعرفها'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
