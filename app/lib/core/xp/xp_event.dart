/// F3.7 — دفتر XP الموقّع (docs/12 §٤.۲ حرفياً):
///   event = { seq, type, ts, payload, prevHash }
///   hash  = SHA-256( prevHash ‖ canonJSON(event بدون hash) )
///   sig   = Ed25519(devicePrivateKey, hash)
/// الدفتر Append-only — أي تعديل/حذف/تزوير يُكتشف بالتحقق (رفض ١٠٠٪
/// — الاختبار الإلزامي docs/12 §٨-4).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// prevHash للحدث الأول (جذر السلسلة).
const String genesisPrevHash = 'GENESIS';

/// ترميز بايتات hex صغير — للهاشات (بلا اعتماد خارجي إضافي).
String bytesToHex(List<int> bytes) {
  const digits = '0123456789abcdef';
  final b = StringBuffer();
  for (final byte in bytes) {
    b.write(digits[(byte >> 4) & 0xf]);
    b.write(digits[byte & 0xf]);
  }
  return b.toString();
}

/// حدث XP واحد بسلسلة الهاش والتوقيع.
class XpEvent {
  const XpEvent({
    required this.seq,
    required this.type,
    required this.tsMs,
    required this.payload,
    required this.prevHash,
    required this.hash,
    required this.sigB64,
  });

  final int seq; // تسلسل من 1 بلا فجوات — docs/12 §٤.۲
  final String type; // معرف الحدث من جدول §٤.١
  final int tsMs; // طابع زمني (ميلي ثانية)
  final Map<String, dynamic> payload; // {points, dateKey, ...تفاصيل}
  final String prevHash; // hex — GENESIS للجذر
  final String hash; // hex — SHA-256(prevHash ‖ canonJSON)
  final String sigB64; // Ed25519(deviceKey, hash bytes)

  /// JSON القانوني للحدث بلا hash وsig — ترتيب الحقول ثابت دائماً.
  Map<String, dynamic> canonicalCore() => <String, dynamic>{
        'seq': seq,
        'type': type,
        'ts': tsMs,
        'payload': payload,
        'prevHash': prevHash,
      };

  Uint8List canonicalCoreBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(canonicalCore())));

  /// إعادة حساب الهاش المتوقع — prevHash يسبق الجسم حرفياً كالوثيقة.
  String expectedHash() => bytesToHex(
        crypto.sha256
            .convert(utf8.encode(prevHash + jsonEncode(canonicalCore())))
            .bytes,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seq': seq,
        'type': type,
        'ts': tsMs,
        'payload': payload,
        'prevHash': prevHash,
        'hash': hash,
        'sig': sigB64,
      };

  factory XpEvent.fromJson(Map<String, dynamic> json) => XpEvent(
        seq: (json['seq'] as num).toInt(),
        type: json['type'] as String,
        tsMs: (json['ts'] as num).toInt(),
        payload:
            (json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
        prevHash: json['prevHash'] as String? ?? genesisPrevHash,
        hash: json['hash'] as String? ?? '',
        sigB64: json['sig'] as String? ?? '',
      );
}
