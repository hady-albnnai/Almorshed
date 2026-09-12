/// F3.6 — نواة الترخيص «الإيجار الموقّع» (docs/11 §٥ · قرارات ٢٦/٢٧).
/// التوكن = حمولة JSON قاعدية-64 + توقيع Ed25519 — التحقق محلي بالمفتاح
/// العام فقط، بلا أي سر بالـAPK (docs/11 §٥: يُغلق باب «استخراج السر»).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// المفتاح العام للتحقق المحلي — ⚠️ placeholder مؤقت (F3.6) ويُستبدل بمفتاح
/// الإنتاج الحقيقي عند F4.4 (يولَّد عند المالك ويُضمَّن 32 بايتاً حصراً).
/// مفتاح عام ليس سراً أبداً — ضبطه هنا مشروع بلا خطر.
final ed.PublicKey licensePublicKey =
    ed.PublicKey(Uint8List.fromList(List<int>.filled(32, 0x42)));

/// موعد امتحان البكالوريا 2027 — الحد الأقصى الصلب لأي إيجار (docs/11 §٥).
/// 2027-05-01T00:00:00Z
const int hardDeadlineMsDefault = 1835904000000;

/// حمولة عقد الإيجار — الحقول بأسمائها الثابتة والترتيب ثابت (canonical).
class LicensePayload {
  const LicensePayload({
    required this.codeId,
    required this.deviceKeyHash,
    required this.releaseId,
    required this.expiresAtMs,
    required this.hardDeadlineMs,
    required this.flags,
  });

  final String codeId; // معرّف الكود — لا يُحمل الرمز نفسه (docs/11 §٥)
  final String deviceKeyHash; // hash مفتاح الجهاز — فارغ مؤقتاً حتى F4.4
  final String releaseId; // إصدار المنهاج (سنة + طبعة)
  final int expiresAtMs; // نهاية الإيجار (≤ ٣٠ يوماً من الإصدار)
  final int hardDeadlineMs; // امتحان الفيزياء 2027 — سقف صلب
  final Set<String> flags; // demo / full / teacher ...

  String get canonicalJson => jsonEncode(<String, dynamic>{
        'code_id': codeId,
        'device_key_hash': deviceKeyHash,
        'release_id': releaseId,
        'expires_at': expiresAtMs,
        'hard_deadline': hardDeadlineMs,
        'flags': flags.toList()..sort(),
      });

  Uint8List get canonicalBytes =>
      Uint8List.fromList(utf8.encode(canonicalJson));

  static LicensePayload fromJson(Map<String, dynamic> json) => LicensePayload(
        codeId: json['code_id'] as String,
        deviceKeyHash: json['device_key_hash'] as String? ?? '',
        releaseId: json['release_id'] as String? ?? '',
        expiresAtMs: (json['expires_at'] as num).toInt(),
        hardDeadlineMs: (json['hard_deadline'] as num).toInt(),
        flags:
            ((json['flags'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => e.toString())
                .toSet(),
      );
}

/// التوكن المادي: حمولة قاعدية-64 + توقيع 64 بايت قاعدية-64.
class LicenseToken {
  const LicenseToken({required this.payloadB64, required this.sigB64});

  final String payloadB64;
  final String sigB64;

  Uint8List get payloadBytes => base64Decode(payloadB64);
  Uint8List get sigBytes => base64Decode(sigB64);

  String encode() => jsonEncode(<String, dynamic>{
        'payload': payloadB64,
        'sig': sigB64,
      });

  /// فك تسامحي — أي فساد يرجع null ولا يكسر التطبيق أبداً.
  static LicenseToken? tryDecode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final p = json['payload'];
      final s = json['sig'];
      if (p is! String || s is! String) return null;
      return LicenseToken(payloadB64: p, sigB64: s);
    } catch (_) {
      return null;
    }
  }

  /// توقيع حمولة جاهزة — أداة إصدار (للاختبارات والأداة المحلية الآن،
  /// ولسيرفر التفعيل F4.4 لاحقاً).
  static LicenseToken issue(
      LicensePayload payload, ed.PrivateKey serverKey) {
    final bytes = payload.canonicalBytes;
    final sig = ed.sign(serverKey, bytes);
    return LicenseToken(
      payloadB64: base64Encode(bytes),
      sigB64: base64Encode(sig),
    );
  }
}

/// حكم التحقق المحلي الكامل — docs/11 §٥ + §٨.
enum LicenseVerdict {
  valid, // إيجار ساري كامل
  demo, // صالح بعلم demo (حزمة تجريبية — قرار ٢٦)
  expired, // تجاوز expires_at — يلزم تجديد (اتصال دقيقة واحدة)
  hardPassed, // تجاوز يوم الامتحان — لا إصدار بعده أبداً
  badSignature, // التوقيع لا يطابق — تزوير أو نقل توكن
  wrongDevice, // hash الجهاز لا يطابق (يُفعَّل كلياً مع F4.4)
  malformed, // بنية فاسدة — ليس توكناً أصلاً
}

class LicenseCheck {
  const LicenseCheck(this.verdict, {this.payload});
  final LicenseVerdict verdict;
  final LicensePayload? payload;
  bool get ok => verdict == valid || verdict == demo;
}

/// الفحص المحلي الظاهر (قرار ٣٨): فك ← توقيع ← بنية ← أجهزة ← زمن.
LicenseCheck checkLicense(
  LicenseToken token, {
  required int nowMs,
  ed.PublicKey? key,
}) {
  final publicKey = key ?? licensePublicKey;
  Uint8List payloadBytes;
  Uint8List sigBytes;
  try {
    payloadBytes = token.payloadBytes;
    sigBytes = token.sigBytes; // فك التوقيع ضمن المحاولة نفسها
  } catch (_) {
    return const LicenseCheck(LicenseVerdict.malformed);
  }
  bool ok;
  try {
    ok = ed.verify(publicKey, payloadBytes, sigBytes);
  } catch (_) {
    return const LicenseCheck(LicenseVerdict.malformed);
  }
  if (!ok) return const LicenseCheck(LicenseVerdict.badSignature);

  final LicensePayload payload;
  try {
    payload = LicensePayload.fromJson(
        jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>);
  } catch (_) {
    return const LicenseCheck(LicenseVerdict.malformed);
  }
  // ربط الجهاز — يُفعَّل كلياً مع Keystore في F4.4؛ الآن hash فارغ دائماً
  // وأي قيمة غير فارغة تعني توكناً لجهاز آخر (docs/11 §٥).
  if (payload.deviceKeyHash.isNotEmpty) {
    return LicenseCheck(LicenseVerdict.wrongDevice, payload: payload);
  }
  if (nowMs > payload.hardDeadlineMs) {
    return LicenseCheck(LicenseVerdict.hardPassed, payload: payload);
  }
  if (nowMs > payload.expiresAtMs) {
    return LicenseCheck(LicenseVerdict.expired, payload: payload);
  }
  return payload.flags.contains('demo')
      ? LicenseCheck(LicenseVerdict.demo, payload: payload)
      : LicenseCheck(LicenseVerdict.valid, payload: payload);
}

/// L4 — كشف رجوع الساعة (docs/11 §٨): ساعة الجهاز للعرض حصراً وتُقارن بآخر
/// قيمة مسجلة. السماحية ٥ دقائق؛ المونوتونيك الكامل مع F7.4 (قرار ٢٩).
bool clockRollbackSuspected({
  required int lastWallMs,
  required int nowMs,
  int toleranceMs = 5 * 60 * 1000,
}) =>
    nowMs < lastWallMs - toleranceMs;

/// الانتظار التدريجي لحماية الكود (قرار ٣٨/النموذج): أول ٥ محاولات حرة
/// ثم يبدأ الانتظار — ٥ و10 و20 و40 دقيقة بسقف ساعة (نمط «حد التخمين»).
/// failures = عدد الإخفاقات المرتكزة حتى الآن؛ القفل المفروض بعدها.
int lockoutMinutesFor(int failures) {
  if (failures < 5) return 0;
  final minutes = 5 * (1 << (failures - 5));
  return minutes > 60 ? 60 : minutes;
}

/// تنسيق الكود كالنموذج: حروف/أرقام لاتينية كبيرة، ١٥ محرفاً، ٥-٥-٥.
String formatLicenseCode(String raw) {
  final filtered = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  final capped = filtered.length > 15 ? filtered.substring(0, 15) : filtered;
  final groups = <String>[];
  for (var i = 0; i < capped.length; i += 5) {
    groups.add(capped.substring(i, i + 5 < capped.length ? i + 5 : capped.length));
  }
  return groups.join('-');
}

/// إخفاء الكود للعرض — النموذج: «K7M2P-•••••-•••••».
String maskCodeId(String codeId) =>
    '${codeId.length >= 5 ? codeId.substring(0, 5) : codeId}-•••••-•••••';
