/// F2.2-T1 — ختم الحزمة pack_seal_v1 (قرار ٣٠ · قرار ٦٧ · docs/16 §١٠).
///
/// AES-256-GCM بمفتاح إصدار K_c (32 بايت — docs/11 §٧): الترويسة
/// 'FCP1' ‖ nonce(12) ‖ cipherText ‖ mac(16). التفريق النطقي عن kc_wrap_v1
/// عبر AAD ثابت. أي تلاعب يُرفض بتذكّر GCM (فشل مبكر — قرار ٦).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// استثناء الختم/الفك — سبب موحّد: 'format' | 'key' | 'auth'.
class ContentSealException implements Exception {
  ContentSealException(this.reason, [this.detail = '']);

  final String reason;
  final String detail;

  @override
  String toString() => 'ContentSealException($reason) $detail';
}

class ContentSeal {
  ContentSeal._();

  /// ترويسة الصيغة 'FCP1'.
  static const List<int> magic = <int>[0x46, 0x43, 0x50, 0x31];

  /// AAD ثابت — فصل نطاق عن kc_wrap_v1 (لا إعادة استعمال عبر البروتوكولين).
  static final List<int> aad = 'fizya-pack-seal-v1'.codeUnits;

  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int macLength = 16;

  /// magic(4) ‖ nonce(12).
  static const int headerLength = 4 + nonceLength;

  static final AesGcm _aes = AesGcm.with256bits();

  /// يختم [plain] بمفتاح [key] — nonce عشوائي ما لم يُمرَّر (المتجهات تثبّته).
  static Future<Uint8List> seal(
    List<int> plain, {
    required List<int> key,
    List<int>? nonce,
  }) async {
    _checkKey(key);
    final n = List<int>.from(nonce ?? _randomBytes(nonceLength));
    if (n.length != nonceLength) {
      throw ContentSealException('format', 'طول nonce');
    }
    final box = await _aes.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: n,
      aad: aad,
    );
    return Uint8List.fromList(<int>[
      ...magic,
      ...n,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// يفك ختم [sealed] — أي عبث أو مفتاح خاطئ يُرمى ContentSealException.
  static Future<Uint8List> open(
    List<int> sealed, {
    required List<int> key,
  }) async {
    _checkKey(key);
    if (sealed.length < headerLength + macLength || !_startsWithMagic(sealed)) {
      throw ContentSealException('format', 'ترويسة pack_seal_v1');
    }
    final n = sealed.sublist(4, headerLength);
    final ct = sealed.sublist(headerLength, sealed.length - macLength);
    final mac = sealed.sublist(sealed.length - macLength);
    try {
      final clear = await _aes.decrypt(
        SecretBox(ct, nonce: n, mac: Mac(mac)),
        secretKey: SecretKey(key),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } catch (e) {
      throw ContentSealException('auth', e.toString());
    }
  }

  static void _checkKey(List<int> key) {
    if (key.length != keyLength) {
      throw ContentSealException('key', 'طول K_c');
    }
  }

  static bool _startsWithMagic(List<int> bytes) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => r.nextInt(256)),
    );
  }
}
