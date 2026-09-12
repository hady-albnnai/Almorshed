import 'package:flutter/material.dart';

import '../../core/training/training_store.dart';
import 'spring_lab_screen.dart';

/// STUMP تشخيصي مؤقت — الأصل محفوظ بجولة فك الأعطال F3.5.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.trainingStore});

  final TrainingStore trainingStore;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المختبر')),
      body: const Center(child: Text('STUMP')),
    );
  }
}
