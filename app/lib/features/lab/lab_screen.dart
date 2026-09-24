import 'package:flutter/material.dart';

import '../../core/lab/experiments.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import 'experiment_screen.dart';
import 'spring_lab_screen.dart';

/// F3.5 + المادة ١٤ — فهرس المختبر (قرار ٣٧: عرض بديل لنفس تجارب الدروس):
/// النابض التوافقي + التجارب الخمس بقالب توقّع/لاحظ/اشرح ومحاكاة حتمية.
class LabScreen extends StatefulWidget {
  /// F3.8 — اختياري: null = بلا تسجيل (اختبارات قديمة سليمة).
  final XpRecorder? xpRecorder;

  const LabScreen({
    super.key,
    required this.trainingStore,
    this.xpRecorder, // F3.8
  });

  final TrainingStore trainingStore;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  TrainingData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.trainingStore.load();
    if (!mounted) return;
    setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final data = _data;

    return Scaffold(
      appBar: AppBar(title: const Text('المختبر')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 4, left: 4),
                  child: Text(
                    'تجارب تفاعلية بمحاكاة فيزيائية حقيقية — غيّر الوسائط، '
                    'توقّع، شغّل، ولاحظ الحركة بنفسك.',
                    style: txt.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('النابض التوافقي'),
                    subtitle: const Text(
                        'محاكاة RK4 حتماً · منهجية توقع/لاحظ/اشرح · تحدي T=٢ث'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      // data محلية نهائية مفحوصة بالثلاثي — الترقية تسري للإغلاق
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SpringLabScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load(); // تحديث حالة التحدي عند العودة
                    },
                  ),
                ),
                for (final exp in labExperiments.values)
                  Card(
                    key: Key('lab-${exp.id}'),
                    child: ListTile(
                      leading: Text(
                        data.labChallengeDays[exp.id] ==
                                dateKeyOf(DateTime.now())
                            ? '✓'
                            : '🧪',
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(exp.title),
                      subtitle: Text(
                          '${_chapterLabel(exp.chapterId)} · ${exp.challenge?.title ?? ''}'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ExperimentScreen(
                            experiment: exp,
                            trainingStore: widget.trainingStore,
                            xpRecorder: widget.xpRecorder,
                          ),
                        ));
                        _load(); // تحديث علامة ✓ عند العودة
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'كل التجارب تعمل محلياً بلا شبكة — خطوة تكامل ١/٢٤٠ ث '
                  'ونفس السحب ⇒ نفس المسار على كل الأجهزة',
                  style: txt.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

/// «الوحدة ١ · الفصل ٢» من معرّف الفصل `U1C2` (للعنوان الفرعي فقط).
String _chapterLabel(String chapterId) {
  final m = RegExp(r'^U(\d+)C(\d+)$').firstMatch(chapterId);
  if (m == null) return chapterId;
  return 'الوحدة ${m.group(1)} · الفصل ${m.group(2)}';
}
