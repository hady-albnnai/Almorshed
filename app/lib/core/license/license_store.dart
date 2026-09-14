/// F3.6 — تخزين حالة الترخيص (النموذج البسيط KV — قرار ٥٧).
/// التوكن وآخر زمن مرئي وعدّاد المحاولات — بيانات فاسدة لا تكسر أبداً.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'license_core.dart';

/// وضع الجهاز: بلا قرارتين (بوابة أول فتح) / تجربة (قرار ٢٦) / مفعّل.
enum LicenseMode { none, trial, licensed }

class LicenseData {
  const LicenseData({
    this.mode = LicenseMode.none,
    this.token,
    this.activatedAtMs,
    this.lastWallMs = 0,
    this.failures = 0,
    this.lockUntilMs = 0,
  });

  final LicenseMode mode;
  final LicenseToken? token; // يُحفظ عند التفعيل ويعاد فحصه محلياً دائماً
  final int? activatedAtMs;
  final int lastWallMs; // L4: آخر زمن مرئي — كشف رجوع الساعة
  final int failures; // محاولات تفعيل خاطئة (backoff)
  final int lockUntilMs;

  /// هل رخصة هذا الجهاز من كود مراجعة؟ (يقرأ العلم من الحمولة — بلا
  /// تحقق توقيع هنا؛ التحقق الكامل يجري في بوابة التفعيل. أسوأ أثر لتزوير
  /// محلي = فتح شاشة ملاحظات لا تكتب للسيرفر ⇒ لا قيمة له.)
  bool get isTeacher {
    final t = token;
    if (t == null) return false;
    try {
      final json = utf8.decode(t.payloadBytes);
      return LicensePayload.fromJson(jsonDecode(json) as Map<String, dynamic>)
          .isTeacher;
    } catch (_) {
      return false;
    }
  }

  LicenseData copyWith({
    LicenseMode? mode,
    LicenseToken? token,
    int? activatedAtMs,
    int? lastWallMs,
    int? failures,
    int? lockUntilMs,
  }) => LicenseData(
    mode: mode ?? this.mode,
    token: token ?? this.token,
    activatedAtMs: activatedAtMs ?? this.activatedAtMs,
    lastWallMs: lastWallMs ?? this.lastWallMs,
    failures: failures ?? this.failures,
    lockUntilMs: lockUntilMs ?? this.lockUntilMs,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode.name,
    'token': token?.encode(),
    'activated_at': activatedAtMs,
    'last_wall': lastWallMs,
    'failures': failures,
    'lock_until': lockUntilMs,
  };

  factory LicenseData.fromJson(Map<String, dynamic> json) {
    // byName أساسية بالدارت (تُلقي لو غير معروف — نأسف بأمان)
    LicenseMode mode = LicenseMode.none;
    final modeName = json['mode'] as String?;
    if (modeName != null) {
      try {
        mode = LicenseMode.values.byName(modeName);
      } catch (_) {
        mode = LicenseMode.none;
      }
    }
    final rawToken = json['token'] as String?;
    return LicenseData(
      mode: mode, // المحلي غير-nullable أولاً — لا حاجة لأي ??
      token: rawToken == null ? null : LicenseToken.tryDecode(rawToken),
      activatedAtMs: (json['activated_at'] as num?)?.toInt(),
      lastWallMs: (json['last_wall'] as num?)?.toInt() ?? 0,
      failures: (json['failures'] as num?)?.toInt() ?? 0,
      lockUntilMs: (json['lock_until'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class LicenseStore {
  Future<LicenseData> load();
  Future<void> save(LicenseData data);
}

class InMemoryLicenseStore implements LicenseStore {
  InMemoryLicenseStore([this._data = const LicenseData()]);

  /// وضع تجربة جاهز — لاختبارات الواجهة التي لا تخص البوابة.
  InMemoryLicenseStore.trial()
    : _data = const LicenseData(mode: LicenseMode.trial);

  LicenseData _data;

  @override
  Future<LicenseData> load() async => _data;

  @override
  Future<void> save(LicenseData data) async => _data = data;
}

/// مفتاح واحد JSON: license_v1 — تلف البيانات يرجع للوضع الابتدائي بأمان.
class SharedPrefsLicenseStore implements LicenseStore {
  static const _key = 'license_v1';

  @override
  Future<LicenseData> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return const LicenseData();
      return LicenseData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LicenseData();
    }
  }

  @override
  Future<void> save(LicenseData data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(data.toJson()));
  }
}
