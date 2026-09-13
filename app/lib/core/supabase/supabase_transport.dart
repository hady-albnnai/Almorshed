// ═════════════════════════════════════════════════════════════════════
// F4.3/F4.4 — نقلية Supabase الخالصة (dart:io حصراً — بلا حزم خارجية).
// العقد: docs/16-SERVER-CONTRACT.md. المفتاح anon عامّ آمن بالتصميم —
// الحماية كاملة بـRLS (docs/11 §١٢.١) والكتابة عبر الدوال المحصنة فقط.
// ═════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';

/// ثوابت المشروع — عامة بالتصميم (قرار ٣٣ + العقد §١).
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://xdkdgetmztapumcxflop.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6'
      'Inhka2RnZXRtenRhcHVtY3hmbG9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyMzI5'
      'MDAsImV4cCI6MjEwNDgwODkwMH0.5FUZhGgtIDQrVomevvCfDV3scuIu-xUGGoqGjS0ZISI';
}

/// جلسة الدخول المجهول — تُخزَّن وتُجدَّد بـrefresh_token (F4.3).
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtMs,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final int expiresAtMs;

  /// صالحة بهامش دقيقة (تفادي إرسال توكن يلفوق في الطريق).
  bool usableAt(int nowMs) => nowMs < expiresAtMs - 60000;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAtMs,
      };

  static AuthSession fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['user_id'] as String,
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAtMs: (json['expires_at'] as num).toInt(),
      );
}

/// خطأ نقلية موصوف — الجسم يُحفظ كاملاً (رفض 422 يحمل accepted/reason).
class TransportException implements Exception {
  const TransportException(this.status, this.message, {this.body = const {}});

  final int status;
  final String message;
  final Map<String, dynamic> body;

  @override
  String toString() => 'TransportException($status, $message)';
}

/// نقلة HTTP واحدة: POST + JSON + مهلة ١٥ ثانية.
class SupabaseTransport {
  SupabaseTransport({
    String? baseUrl,
    String? anonKey,
    Duration timeout = const Duration(seconds: 15),
  })  : _base = (baseUrl ?? SupabaseConfig.url).replaceAll(RegExp(r'/+$'), ''),
        _anonKey = anonKey ?? SupabaseConfig.anonKey,
        _timeout = timeout;

  final String _base;
  final String _anonKey;
  final Duration _timeout;
  final HttpClient _client = HttpClient();

  Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) async {
    final request = await _client.postUrl(Uri.parse(url)).timeout(_timeout);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    headers.forEach(request.headers.set);
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close().timeout(_timeout);
    final text = await response.transform(utf8.decoder).join();

    Map<String, dynamic> json = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // جسم غير JSON — يُرسل نصاً في الرسالة
    }
    if (response.statusCode >= 400) {
      final msg = (json['error'] ?? json['msg'] ?? json['message'] ?? text)
          .toString();
      throw TransportException(response.statusCode, msg, body: json);
    }
    return json;
  }

  /// الدخول المجهول (GoTrue): بريد فارغ = تسجيل مجهول — العقد §١.
  Future<AuthSession> signUpAnonymously() async {
    final r = await postJson('$_base/auth/v1/signup',
        <String, dynamic>{'email': '', 'password': '', 'data': const {}},
        <String, String>{'apikey': _anonKey});
    return _sessionFrom(r);
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    final r = await postJson(
        '$_base/auth/v1/token?grant_type=refresh_token',
        <String, dynamic>{'refresh_token': refreshToken},
        <String, String>{'apikey': _anonKey});
    return _sessionFrom(r);
  }

  /// استدعاء دالة Edge — العقد §٢-§٤.
  Future<Map<String, dynamic>> callFunction(
    String name,
    Map<String, dynamic> body, {
    required String accessToken,
  }) =>
      postJson(
        '$_base/functions/v1/$name',
        body,
        <String, String>{
          'apikey': _anonKey,
          'Authorization': 'Bearer $accessToken',
        },
      );

  AuthSession _sessionFrom(Map<String, dynamic> r) {
    final user = (r['user'] as Map<String, dynamic>?) ?? const {};
    final access = r['access_token'];
    final refresh = r['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const TransportException(0, 'رد مصادقة غير متوقع');
    }
    // زمن الانتهاء الرسمي من GoTrue (expires_at — ثوانٍ unix) حصراً؛
    // الاشتقاق المحلي fallback حصراً (توقيت الساعة المحلية قد ينحرف — L4)
    final official = (r['expires_at'] as num?)?.toInt();
    final expiresAtMs = official != null
        ? official * 1000
        : DateTime.now().millisecondsSinceEpoch +
            ((r['expires_in'] as num?)?.toInt() ?? 3600) * 1000;
    return AuthSession(
      userId: (user['id'] as String?) ?? '',
      accessToken: access,
      refreshToken: refresh,
      expiresAtMs: expiresAtMs,
    );
  }
}
