/// F3.7 — تخزين أحداث الدفتر (Append-only منطقياً: الواجهة بلا تعديل/حذف).
/// مفتاح واحد JSON: xpledger_v1 — تلف البيانات يرجع قائمة فارغة بأمان
/// (السيرفر لاحقاً هو مرجع الاعتماد — docs/12 §٤.۲).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'xp_event.dart';

abstract class XpEventStore {
  Future<List<XpEvent>> loadEvents();
  Future<void> saveEvents(List<XpEvent> events);
}

class InMemoryXpEventStore implements XpEventStore {
  InMemoryXpEventStore([List<XpEvent>? seed]) : _events = seed ?? [];

  List<XpEvent> _events;

  @override
  Future<List<XpEvent>> loadEvents() async => List.of(_events);

  @override
  Future<void> saveEvents(List<XpEvent> events) async =>
      _events = List.of(events);
}

class SharedPrefsXpEventStore implements XpEventStore {
  static const _key = 'xpledger_v1';

  @override
  Future<List<XpEvent>> loadEvents() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => XpEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveEvents(List<XpEvent> events) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode([for (final e in events) e.toJson()]),
    );
  }
}
