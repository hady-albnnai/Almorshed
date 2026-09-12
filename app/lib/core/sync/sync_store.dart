/// F4.5 — حالة المزامنة (آخر حدث مقبول + مرساة زمن السيرفر L4 + backoff).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// حالة محرك المزامنة — تُحفظ محلياً وتُقرأ عند كل محاولة.
class SyncState {
  const SyncState({
    this.lastSyncedSeq = 0,
    this.lastServerWallMs = 0,
    this.failCount = 0,
    this.nextRetryMs = 0,
  });

  /// آخر seq قَبِله السيرفر — الرفع يبدأ بعده دائماً.
  final int lastSyncedSeq;

  /// مرساة L4: آخر زمن سيرفر موقّع (كشف رجوع الساعة — docs/11 §٨).
  final int lastServerWallMs;

  /// إخفاقات متتالية (للانتظار الأسي).
  final int failCount;

  /// أقرب محاولة مسموحة (ميلي ثانية إيبخ) — 0 = الآن.
  final int nextRetryMs;

  SyncState copyWith({
    int? lastSyncedSeq,
    int? lastServerWallMs,
    int? failCount,
    int? nextRetryMs,
  }) =>
      SyncState(
        lastSyncedSeq: lastSyncedSeq ?? this.lastSyncedSeq,
        lastServerWallMs: lastServerWallMs ?? this.lastServerWallMs,
        failCount: failCount ?? this.failCount,
        nextRetryMs: nextRetryMs ?? this.nextRetryMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'last_synced': lastSyncedSeq,
        'server_wall': lastServerWallMs,
        'fails': failCount,
        'next_retry': nextRetryMs,
      };

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
        lastSyncedSeq: (json['last_synced'] as num?)?.toInt() ?? 0,
        lastServerWallMs: (json['server_wall'] as num?)?.toInt() ?? 0,
        failCount: (json['fails'] as num?)?.toInt() ?? 0,
        nextRetryMs: (json['next_retry'] as num?)?.toInt() ?? 0,
      );
}

abstract class SyncStateStore {
  Future<SyncState> load();
  Future<void> save(SyncState state);
}

class InMemorySyncStateStore implements SyncStateStore {
  InMemorySyncStateStore([this._state = const SyncState()]);
  SyncState _state;

  @override
  Future<SyncState> load() async => _state;

  @override
  Future<void> save(SyncState state) async => _state = state;
}

/// تخزين فعلي: sync_v1 — تلف البيانات يرجع حالة صفرية بأمان
/// (المزامنة تبدأ من الصفر والسيرفر هو المرجع).
class SharedPrefsSyncStateStore implements SyncStateStore {
  static const _key = 'sync_v1';

  @override
  Future<SyncState> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return const SyncState();
      return SyncState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SyncState();
    }
  }

  @override
  Future<void> save(SyncState state) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(state.toJson()));
  }
}
