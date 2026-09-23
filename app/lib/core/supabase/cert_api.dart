// ═══════════════════════════════════════════════════════════════════════
// cert_api.dart — F6.5 عميل: طلب شهادة الموسم من دالة cert_issue.
//
// المصادقة (F6.3-أمن): إثبات حيازة مفتاح الجهاز — العميل يوقّع تحدّي
// certChallenge(season, pubkey) بمفتاح XpSigner (نفس مفتاح أحداث XP) ويرسله
// حقلاً challenge_sig. الخادم يتحقق Ed25519 ضد المفتاح المخزّن. بلا توقيع ⇒
// يرفض الخادم (400/403). التوقيع محلي دائمًا؛ لا سرّ يمرّ بالشبكة.
//
// التحقق: الشهادة العائدة تُتحقَّق **محليًّا** بالمفتاح العام المضمّن
// (Certificate.verifyEmbedded) قبل قبولها — فلا ثقة عمياء بردّ الشبكة.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';

import '../cert/certificate.dart';
import '../xp/xp_signer.dart';
import 'anonymous_auth.dart';
import 'supabase_transport.dart';

/// خطأ طلب الشهادة — الرمز والرسالة من عقد cert_issue (§F6.3).
class CertApiException implements Exception {
  const CertApiException(this.code, {this.status = 0});

  /// رمز الخطأ الحرفي من الخادم (SEASON_OPEN · NOT_PARTICIPATED · …).
  final String code;
  final int status;

  /// الموسم لم يُغلق بعد — لا شهادة قبل نهايته.
  bool get seasonOpen => code == 'SEASON_OPEN';

  /// الجهاز لم يشارك في أي موسم — لا استحقاق.
  bool get notParticipated => code == 'NOT_PARTICIPATED';

  /// الشهادة رُفضت محليًّا (توقيع لا يتحقق بالمفتاح المضمّن) — لا نثق بالردّ.
  bool get badSignature => code == 'BAD_LOCAL_SIGNATURE';

  @override
  String toString() => 'CertApiException($status): $code';
}

/// عقد إصدار شهادة الموسم — تجريد يسمح بحقن بديل في الاختبارات/المعاينة.
abstract class CertIssuer {
  /// يطلب (أو يعيد — idempotent) شهادة الموسم [season]؛ يرمي [CertApiException].
  Future<Certificate> issue(String season);
}

/// عميل شهادة الموسم فوق دالة cert_issue.
class CertApi implements CertIssuer {
  CertApi({required this.transport, required this.auth, required this.signer});

  final SupabaseTransport transport;
  final AnonymousAuth auth;
  final XpSigner signer;

  /// يطلب (أو يعيد — idempotent) شهادة الموسم [season] للجهاز الحالي.
  ///
  /// يرمي [CertApiException] عند رفض الخادم أو فشل التحقق المحلي.
  @override
  Future<Certificate> issue(String season) async {
    final pubkeyB64 = base64Encode(signer.publicKey.bytes);
    // توقيع التحدّي بمفتاح الجهاز (بايتات نصّ التحدّي — كما يبنيه الخادم).
    final challenge = certChallenge(season: season, devicePubkeyB64: pubkeyB64);
    final challengeSig =
        signer.signHash(Uint8List.fromList(utf8.encode(challenge)));

    final session = await auth.session();
    late final Map<String, dynamic> r;
    try {
      r = await transport.callFunction(
        'cert_issue',
        <String, dynamic>{
          'season': season,
          'device_pubkey_b64': pubkeyB64,
          'challenge_sig': challengeSig,
        },
        accessToken: session.accessToken,
      );
    } on TransportException catch (e) {
      // الخادم يردّ {ok:false,error:CODE} برمز حالة ≥400 ⇒ الرسالة = الرمز.
      throw CertApiException(e.message, status: e.status);
    }

    if (r['ok'] != true || r['certificate'] is! Map) {
      throw CertApiException(
          (r['error'] ?? 'UNKNOWN').toString(), status: 200);
    }
    final cert = Certificate.fromJson(
        (r['certificate'] as Map).cast<String, dynamic>());

    // التحقق المحلي الإلزامي — لا نقبل شهادة لا يتحقق توقيعها بالمفتاح المضمّن.
    if (!Certificate.verifyEmbedded(cert)) {
      throw const CertApiException('BAD_LOCAL_SIGNATURE', status: 200);
    }
    return cert;
  }
}

/// مُصدِر كسول: يبني [CertApi] عند أول طلب — يؤجّل تحميل [XpSigner] من الخزنة
/// الآمنة (غير متزامن) حتى لحظة الحاجة، فلا يُثقَل بناء الشاشة/التركيب.
///
/// يسمح بتوصيل مدخل الشهادة في `main.dart` دون كسر أي بناء متزامن.
class LazyCertApi implements CertIssuer {
  LazyCertApi({
    required this.transport,
    required this.auth,
    required this.signerLoader,
  });

  final SupabaseTransport transport;
  final AnonymousAuth auth;
  final Future<XpSigner> Function() signerLoader;

  CertApi? _delegate;

  @override
  Future<Certificate> issue(String season) async {
    final api = _delegate ??= CertApi(
      transport: transport,
      auth: auth,
      signer: await signerLoader(),
    );
    return api.issue(season);
  }
}
