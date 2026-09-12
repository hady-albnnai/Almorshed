import 'package:flutter/material.dart';

import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';

/// STUMP تشخيصي مؤقت — الأصل محفوظ بجولة فك الأعطال F3.5.
class SpringLabScreen extends StatefulWidget {
  const SpringLabScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;

  @override
  State<SpringLabScreen> createState() => _SpringLabScreenState();
}

class _SpringLabScreenState extends State<SpringLabScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المختبر: النابض التوافقي')),
      body: const Center(child: Text('STUMP')),
    );
  }
}
