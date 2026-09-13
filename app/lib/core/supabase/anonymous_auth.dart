// ═════════════════════════════════════════════════════════════════════
// F4.3 — مدير الجلسة المجهولة: كاش → تجديد → تسجيل جديد (سقوط آمن).
// التوكن مجهول الهوية وقيمته منخفضة — SharedPrefs كافية له (التراخيص
// في license_v1 وXP في دفتر موقّع — لا شيء حساس هنا).
// ═════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_transport.dart';

abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String json);
  Future<void> clear();
}

class InMemorySessionStore implements SessionStore {
  String? _json;
  @override
  Future<String?> read() async => _json;
  @override
  Future<void> write(String json) async => _json = json;
  @override
  Future<void> clear() async => _json = null;
}

class SharedPrefsSessionStore implements SessionStore {
  static const _key = 'supabase_session_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  @override
  Future<void> write(String json) async =>
      (await SharedPreferences.getInstance()).setString(_key, json);
  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

class AnonymousAuth {
  AnonymousAuth({
    required this.transport,
    required this.store,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SupabaseTransport transport;
  final SessionStore store;
  final int Function() _nowMs;

  AuthSession? _cached;

  /// جلسة صالحة — كاش ← تجديد ← تسجيل مجهول جديد (أول ما ينجح يعود).
  Future<AuthSession> session({bool forceNew = false}) async {
    final now = _nowMs();
    if (!forceNew) {
      final cached = _cached ?? await _fromStore();
      if (cached != null && cached.usableAt(now)) return cached;
      if (cached != null) {
        try {
          final fresh = await transport.refreshSession(cached.refreshToken);
          await _persist(fresh);
          return fresh;
        } catch (_) {
          // تجديد فاشل — سقوط آمن لتسجيل جديد أدناه
        }
      }
    }
    final fresh = await transport.signUpAnonymously();
    // جلسة وليدة قريبة من الانتهاء أصلاً (انحراف ساعة سيرفر/هامش صفر)؟
    // تُجدد فوراً — لا نسلّم المتصل جلسة يرفضها هامش الأمان (L4).
    if (!fresh.usableAt(now)) {
      try {
        final renewed = await transport.refreshSession(fresh.refreshToken);
        await _persist(renewed);
        return renewed;
      } catch (_) {
        // تعذر التجديد — نسلّم الوليدة كما هي (أفضل من لا شيء)
      }
    }
    await _persist(fresh);
    return fresh;
  }

  Future<AuthSession?> _fromStore() async {
    final raw = await store.read();
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(AuthSession s) async {
    _cached = s;
    await store.write(jsonEncode(s.toJson()));
  }
}
