/// F6.3 — شهادة الموسم الموقّعة («بطل دوري فيزيا كلاش» — docs/13 §٦ · docs/14 F6.3).
///
/// الشهادة تُصدر نهاية الموسم المُغلق حصراً وتُوقَّع Ed25519 على **حمولة
/// canonical** بترتيب حقول ثابت (مطابق حرفيًّا لبقية `cert_issue`)، والتحقق
/// محلي بالمفتاح العام فقط — بلا سرّ بالتطبيق (نفس منطق الترخيص F3.6).
///
/// الطبقتان: 🥇 سنتا مشاركة (`gold_two`) · 🥇/🥈 سنة مشاركة واحدة (`silver_one`)
/// — «سنتان/سنة» كما في سطر F6.3 حرفياً: عدد المواسم التي ظهر فيها الجهاز
/// في `weekly_totals` عند إصدار شهادة موسم مُغلق.
///
/// ⚠️ **تنويه المرونة (قرار ٤٠):** النصّ الحرفيّ غير متوفر في المستودع —
/// [kFlexibilityNotice40] تبقى فارغة حتى يُسلّمها المالك؛ ولا تُخمَّن أبداً
/// (قاعدة عدم التخمين). والشهادة لا تُطبع تنويهاً ما لم يكن حرفيًّا.
library;

import 'dart:convert';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// عنوان الشهادة — حرفي من docs/13 §٦.
const String certTitle = 'بطل دوري فيزيا كلاش';

/// نسخة الحمولة الـcanonical (F6.3-أمن 2026-09-22). أول حقل في التوقيع؛ أي
/// تغيير مستقبلي على شكل الحمولة يرفع هذا الرقم فلا تُقبل التواقيع القديمة
/// بصمت — والتطبيق يعرف أي مخطط يبني. يجب أن يطابق `CERT_PAYLOAD_V` في
/// `cert_issue`.
const int kCertPayloadVersion = 1;

/// نصّ قرار ٤٠ (تنويه المرونة) **حرفيًّا** — بانتظار المالك. فارغ ⇒ لا يُعرض
/// أي تنويه (لا نصّ بديل ولا صياغة من عندنا).
const String kFlexibilityNotice40 = '';

/// طبقة الشهادة.
enum CertTier {
  /// 🥇 مشاركتان (سنتان).
  goldTwoYears('gold_two', '🥇 سنتان'),

  /// 🥈 مشاركة واحدة (سنة).
  silverOneYear('silver_one', '🥈 سنة');

  const CertTier(this.machine, this.label);

  /// القيمة في القاعدة وفي الحمولة (`gold_two`/`silver_one`).
  final String machine;

  /// النصّ المعروض على الشهادة.
  final String label;

  static CertTier fromMachine(String raw) => CertTier.values.firstWhere(
        (t) => t.machine == raw,
        orElse: () => CertTier.silverOneYear,
      );
}

/// شهادة موقّعة قابلة للتحقق محليًّا.
class Certificate {
  const Certificate({
    this.version = kCertPayloadVersion,
    required this.id,
    required this.season,
    required this.tier,
    required this.years,
    required this.xp,
    required this.devicePubkeyB64,
    required this.issuedAtMs,
    required this.notice,
    required this.signatureB64,
  });

  /// نسخة مخطط الحمولة (أول حقل موقّع) — انظر [kCertPayloadVersion].
  final int version;

  final String id;
  final String season;
  final CertTier tier;
  final int years;
  final int xp;

  /// مفتاح الجهة الحاملة (الجهاز) — هوية بلا اسم؛ نفس بذرة الجهاز المعلنة.
  final String devicePubkeyB64;
  final int issuedAtMs;

  /// تنويه قرار ٤٠ — نصّ حرفي أو سلسلة فارغة (انظر [kFlexibilityNotice40]).
  final String notice;
  final String signatureB64;

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        version: (j['v'] as num?)?.toInt() ?? kCertPayloadVersion,
        id: j['id'] as String,
        season: j['season'] as String,
        tier: CertTier.fromMachine(j['tier'] as String),
        years: (j['years'] as num).toInt(),
        xp: (j['xp'] as num).toInt(),
        devicePubkeyB64: j['device_pubkey_b64'] as String,
        issuedAtMs: (j['issued_at_ms'] as num).toInt(),
        notice: j['notice'] as String? ?? '',
        signatureB64: j['signature'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': version,
        'id': id,
        'season': season,
        'tier': tier.machine,
        'years': years,
        'xp': xp,
        'device_pubkey_b64': devicePubkeyB64,
        'issued_at_ms': issuedAtMs,
        'notice': notice,
        'signature': signatureB64,
      };

  /// الحمولة الموقّعة: نفس المفاتيح بالترتيب نفسه وبدون حقل `signature`
  /// — يبنيه الطرفان (هنا و`cert_issue`) بالترتيب الحصري أدناه. `v` أولاً.
  String get canonicalJson => jsonEncode(<String, dynamic>{
        'v': version,
        'id': id,
        'season': season,
        'tier': tier.machine,
        'years': years,
        'xp': xp,
        'device_pubkey_b64': devicePubkeyB64,
        'issued_at_ms': issuedAtMs,
        'notice': notice,
      });

  /// التحقق المحلي: توقيع Ed25519 على [canonicalJson].
  static bool verify(Certificate cert, {required ed.PublicKey publicKey}) {
    if (cert.signatureB64.isEmpty) return false;
    try {
      final sig = base64Decode(cert.signatureB64);
      return ed.verify(
        publicKey,
        utf8.encode(cert.canonicalJson),
        sig,
      );
    } catch (_) {
      return false;
    }
  }

  /// توقيع الحمولة بمفتاح خاص — للتوليد وللاختبارات فقط (الإنتاج يوقّع الخادم).
  static String signCanonical(Certificate cert, ed.PrivateKey privateKey) =>
      base64Encode(
        ed.sign(privateKey, utf8.encode(cert.canonicalJson)),
      );
}

/// F6.3-أمن (2026-09-22): تحدٍّ يثبت أن نداء `cert_issue` صادر عن **حامل**
/// مفتاح الجهاز الخاص لا مجرد من يعرف مفتاحه العام (المفتاح العام يُرفع في كل
/// نداء XP/heartbeat فهو ليس سرّاً). العميل يبني هذه السلسلة ويوقّعها بمفتاح
/// `XpSigner` (نفس مفتاح أحداث XP)، والخادم يعيد بناءها ويتحقق بـEd25519 ضد
/// `devices.pubkey_b64` — نفس مسار `verify_xp_events` المُبرهَن. يجب أن يطابق
/// `certChallenge()` في `cert_issue/index.ts` حرفيًّا.
///
/// الربط بالموسم والمفتاح يمنع استعمال توقيعٍ لموسم/جهاز آخر؛ وإعادة الإرسال
/// لا تضرّ (الإصدار idempotent ومقيّد بالجهاز نفسه).
String certChallenge({required String season, required String devicePubkeyB64}) =>
    'cert-issue-v1|$season|$devicePubkeyB64';
