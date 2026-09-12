import 'package:flutter/material.dart';

import '../../core/training/training_store.dart';
import 'spring_lab_screen.dart';

/// F3.5 — بوابة المختبر: تجربة النابض التوافقي جاهزة (قرار ٤٣)،
/// وبقية التجارب الخمس تُبنى بنفس القالب (POE + محاكاة حتمية).
class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.trainingStore});

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
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('النابض التوافقي'),
                    subtitle: const Text(
                        'محاكاة RK4 حتماً · منهجية توقع/لاحظ/اشرح · تحدي T=٢ث'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () {}, // BISECT: الإغلاق الحقيقي خارجاً مؤقتاً
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
