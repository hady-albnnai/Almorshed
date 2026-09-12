import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/training/training_store.dart';

/// F3.3 — أرشيف أخطائي: كل خطأ بنصه وإجابته والصحيح (الأحدث أولاً).
class MistakesScreen extends StatefulWidget {
  const MistakesScreen({
    super.key,
    required this.pack,
    required this.trainingStore,
  });

  final ContentPack pack;
  final TrainingStore trainingStore;

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
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

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final questions = {for (final q in widget.pack.questions) q.id: q};

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
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    for (final m in _data.mistakes)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  style: txt.bodyMedium
                                      ?.copyWith(color: Colors.green),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
