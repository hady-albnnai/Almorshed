// ═══════════════════════════════════════════════════════════════════════
// office_api.dart — عميل أداة المكتب للوحة الإدارة المخفية (F6.1-إدارة).
// يتكلم مع دالة office_codes حصراً عبر ترويسة x-office-key (المفتاح يدخله
// المالك مرة واحدة ويعيش في الخزنة الآمنة بجهازه فقط — لا يُطبع ولا يُرسل
// إلا كترويسة). نقلية dart:io خالصة — بلا حزم خارجية (قرار ٥١).
// ═══════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_transport.dart';

/// خطأ استدعاء أداة المكتب — الرسالة والرمز مباشرة.
class OfficeApiException implements Exception {
  const OfficeApiException(this.message, this.status);

  final String message;
  final int status;

  bool get forbidden => status == 403;

  @override
  String toString() => 'OfficeApiException($status): $message';
}

/// مشترك واحد — من فعل stats.
class Subscriber {
  const Subscriber({
    required this.code,
    required this.status,
    required this.distributor,
    required this.releaseId,
    required this.devicesUsed,
    this.createdAt,
    this.activatedAt,
    this.customer,
    this.review = false,
  });

  final String code; // مشكّل ٥-٥-٥
  final String status; // issued | activated | revoked
  final String distributor;
  final String releaseId;
  final int devicesUsed;
  final String? createdAt;
  final String? activatedAt;

  /// اسم الزبون كما كتبه المكتب عند البيع (0013 — POS). null = بلا اسم.
  final String? customer;

  /// كود مراجعة للأستاذ (قرار ٥٥) — لا يُحسب زبوناً.
  final bool review;

  bool get active => status == 'activated';

  /// بحث حر بالكود (بلا شرطات، بأي حالة) أو باسم الزبون.
  bool matches(String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    final qc = q.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final cc = code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (qc.isNotEmpty && cc.contains(qc)) return true;
    return (customer ?? '').contains(q);
  }

  static Subscriber fromJson(Map<String, dynamic> json) => Subscriber(
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? '',
        distributor: json['distributor'] as String? ?? '',
        releaseId: json['release_id'] as String? ?? '',
        devicesUsed: (json['devices_used'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] as String?,
        activatedAt: json['activated_at'] as String?,
        customer: (json['customer'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['customer'] as String).trim(),
        review: json['review'] == true,
      );
}

/// عدادات المكتب — من فعل stats.
class OfficeStats {
  const OfficeStats({
    required this.issued,
    required this.activated,
    required this.revoked,
    required this.activeLicenses,
  });

  final int issued;
  final int activated;
  final int revoked;
  final int activeLicenses;

  static OfficeStats fromJson(Map<String, dynamic> json) => OfficeStats(
        issued: (json['issued'] as num?)?.toInt() ?? 0,
        activated: (json['activated'] as num?)?.toInt() ?? 0,
        revoked: (json['revoked'] as num?)?.toInt() ?? 0,
        activeLicenses: (json['activeLicenses'] as num?)?.toInt() ?? 0,
      );
}

/// خزنة مفتاح المكتب — flutter_secure_storage على جهاز المالك حصراً.
class OfficeKeyVault {
  OfficeKeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'office_admin_key_v1';

  Future<String?> read() async {
    final v = await _storage.read(key: _key);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> write(String value) => _storage.write(key: _key, value: value);

  Future<void> clear() => _storage.delete(key: _key);
}

/// عميل دالة office_codes.
class OfficeApi {
  OfficeApi({String? baseUrl}) : _baseUrl = baseUrl ?? SupabaseConfig.url;

  final String _baseUrl;

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> body,
    String key,
  ) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client
          .postUrl(Uri.parse('$_baseUrl/functions/v1/office_codes'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('x-office-key', key);
      request.add(
        utf8.encode(jsonEncode(<String, dynamic>{...body, 'action': action})),
      );
      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join();
      Map<String, dynamic> json = const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // جسم غير JSON — الرسالة نصية
      }
      if (response.statusCode >= 400) {
        throw OfficeApiException(
          (json['error'] ?? json['detail'] ?? text).toString(),
          response.statusCode,
        );
      }
      return json;
    } finally {
      client.close(force: true);
    }
  }

  /// عدادات + لائحة المشتركين.
  Future<(OfficeStats, List<Subscriber>)> stats(String key) async {
    final json = await _call('stats', const <String, dynamic>{}, key);
    final stats = OfficeStats.fromJson(
      (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final subs = <Subscriber>[
      for (final e in (json['subscribers'] as List<dynamic>?) ?? const [])
        if (e is Map<String, dynamic>) Subscriber.fromJson(e),
    ];
    return (stats, subs);
  }

  /// توليد أكواد — تعيدها مشكّلة ٥-٥-٥.
  Future<List<String>> generate(
    String key, {
    int count = 1,
    bool review = false,
    String? customer,
  }) async {
    final json = await _call(
        'generate',
        <String, dynamic>{
          'count': count,
          if (review) 'review': true,
          if (review) 'distributor': 'مراجعة — الأستاذ',
          if (customer != null && customer.trim().isNotEmpty)
            'customer': customer.trim(),
        },
        key);
    return [
      for (final e in (json['codes'] as List<dynamic>?) ?? const [])
        e.toString(),
    ];
  }

  /// إلغاء كود/اشتراك.
  Future<void> revoke(String key, String code) async {
    await _call('revoke', <String, dynamic>{'code': code}, key);
  }

  /// تحديث اسم الزبون على كود قائم (POS — فعل note).
  Future<void> note(String key, String code, String customer) async {
    await _call(
        'note',
        <String, dynamic>{
          'code': code,
          'customer': customer.trim(),
        },
        key);
  }
}
