import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'training_store.dart';

/// تنفيذ SharedPrefs — مفتاح واحد training_v1 بJSON، تحميل آمن:
/// أي خلل (تلف/إصدار قديم) ⇒ بيانات فارغة ولا انهيار (نمط F3.1).
class SharedPrefsTrainingStore implements TrainingStore {
  static const _key = 'training_v1';

  @override
  Future<TrainingData> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return const TrainingData();
      return TrainingData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TrainingData();
    }
  }

  @override
  Future<void> save(TrainingData data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(data.toJson()));
  }
}
