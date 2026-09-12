import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'progress_store.dart';

/// التخزين الفعلي لتقدم القراءة عبر shared_preferences (F3.1 — قرار ٥٧).
/// مفتاح واحد JSON: progress_v1 — وتلف البيانات لا يكسر التطبيق أبداً.
class SharedPrefsProgressStore implements ProgressStore {
  static const _key = 'progress_v1';

  @override
  Future<ReadProgress> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return const ReadProgress();
      return ReadProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReadProgress();
    }
  }

  @override
  Future<void> save(ReadProgress progress) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(progress.toJson()));
  }
}
