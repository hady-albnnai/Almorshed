// ═════════════════════════════════════════════════════════════════════
// F4.4 عميل — استدعاء license_activate وترجمة الأخطاء للعربية،
// مع تمييز «خطأ كود يُحسب ضد قفل الانتظار» من «عطل شبكة/خادم لا يُحسب»
// (عدالة قفل docs/11 §٩: يُعاقَب تخمين الأكواد لا انقطاع النت).
// ═════════════════════════════════════════════════════════════════════
import '../crypto/kc_provision.dart';
import '../license/license_core.dart';
import 'anonymous_auth.dart';
import 'supabase_transport.dart';

class ActivationAttempt {
  const ActivationAttempt({
    required this.ok,
    this.token,
    this.serverTimeMs = 0,
    this.expiresAtMs = 0,
    this.hardDeadlineMs = 0,
    this.devicesUsed = 0,
    this.errorAr = '',
    this.countsAsAttempt = false,
    this.contentKeyReceived = false,
  });

  final bool ok;
  final LicenseToken? token;
  final int serverTimeMs;
  final int expiresAtMs;
  final int hardDeadlineMs;
  final int devicesUsed;
  final String errorAr;
  final bool countsAsAttempt;

  /// F2.2-T2: حمل الرد `kc_wrapped` وفُكّ وحُفظ K_c (قرار ٣٠).
  final bool contentKeyReceived;
}

class ActivationApi {
  ActivationApi({
    required this.transport,
    required this.auth,
    this.contentKeys,
  });

  final SupabaseTransport transport;
  final AnonymousAuth auth;

  /// F2.2-T2 (اختياري): بوجوده يُرفع مفتاح X25519 ويُبتلع `kc_wrapped`.
  final ContentKeyProvisioner? contentKeys;

  /// أكواد منطقية من الخادم (العقد §٢.٤) — تُحسب محاولات فاشلة.
  static const Map<String, String> _codeErrors = <String, String>{
    'ACT_CODE_NOT_FOUND': 'الكود غير معروف — تأكد منه من بطاقة المكتب',
    'ACT_CODE_REVOKED': 'هذا الكود ملغى — راجع مكتب لورانيم',
    'ACT_DEVICE_LIMIT': 'الكود مستهلك على جهازين — الحد الأقصى (قرار ٢٨)',
    'ACT_RATE_LIMIT': 'محاولات كثيرة — انتظر ربع ساعة ثم أعد المحاولة',
    'CODE_FORMAT': 'صيغة الكود غير سليمة — ١٥ حرفاً بصيغة XXXXX-XXXXX-XXXXX',
    'PUBKEY_FORMAT': 'مشكلة بمفتاح الجهاز — أعد تثبيت التطبيق',
    'FP_FORMAT': 'مشكلة ببصمة الجهاز — أعد المحاولة',
    'X25519_PUBKEY_FORMAT': 'مشكلة بمفتاح المحتوى — أعد تثبيت التطبيق',
  };

  Future<ActivationAttempt> activate(
    String code,
    String pubkeyB64,
    String deviceFp,
  ) async {
    var session = await auth.session();
    final x25519B64 = await contentKeys?.devicePublicB64();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await transport.callFunction(
          'license_activate',
          <String, dynamic>{
            'code': code,
            'device_pubkey_b64': pubkeyB64,
            'device_fp': deviceFp,
            if (x25519B64 != null) 'device_x25519_pub_b64': x25519B64,
          },
          accessToken: session.accessToken,
        );
        final tokenJson =
            (r['token'] as Map<String, dynamic>?) ?? const {};
        final payload = tokenJson['payload'];
        final sig = tokenJson['sig'];
        if (payload is! String || sig is! String) {
          return const ActivationAttempt(
              ok: false, errorAr: 'رد خادم غير مكتمل', countsAsAttempt: false);
        }
        final gotKc = await contentKeys?.ingest(r) ?? false;
        return ActivationAttempt(
          ok: true,
          contentKeyReceived: gotKc,
          token: LicenseToken(payloadB64: payload, sigB64: sig),
          serverTimeMs: (r['server_time_ms'] as num?)?.toInt() ?? 0,
          expiresAtMs: (r['expires_at'] as num?)?.toInt() ?? 0,
          hardDeadlineMs: (r['hard_deadline'] as num?)?.toInt() ?? 0,
          devicesUsed: (r['devices_used'] as num?)?.toInt() ?? 0,
        );
      } on TransportException catch (e) {
        // جلسة انتهت أثناء الطريق؟ تجديد إجباري ومحاولة ثانية وحيدة
        if (e.status == 401 && attempt == 0) {
          session = await auth.session(forceNew: true);
          continue;
        }
        final ar = _codeErrors[e.message];
        if (ar != null) {
          return ActivationAttempt(
              ok: false, errorAr: ar, countsAsAttempt: true);
        }
        return ActivationAttempt(
          ok: false,
          errorAr: e.status >= 500 || e.status == 0
              ? 'الخادم مشغول حالياً — أعد المحاولة بعد قليل'
              : 'تعذر التفعيل (رمز ${e.status})',
          countsAsAttempt: false,
        );
      } catch (_) {
        return const ActivationAttempt(
            ok: false,
            errorAr: 'تعذر الوصول للخادم — تحقق من اتصال الإنترنت',
            countsAsAttempt: false);
      }
    }
    return const ActivationAttempt(
        ok: false, errorAr: 'تعذر التفعيل', countsAsAttempt: false);
  }
}
