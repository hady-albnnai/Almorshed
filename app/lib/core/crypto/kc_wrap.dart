/// F2.2-T1 — نقل مفتاح الإصدار kc_wrap_v1 (قرار ٣٠ · قرار ٦٧ · docs/16 §١٠).
///
/// نمط sealed-box (docs/11 §٧): زوج X25519 عابر للمُغلِّف + ECDH (RFC 7748)
/// + HKDF-SHA256 (RFC 5869) مقيد بالطرفين + AES-256-GCM. الملف السلكي 92
/// بايت: eph_pk(32) ‖ nonce(12) ‖ ct(32) ‖ mac(16) — لا يفكّه إلا جهاز
/// الطالب الذي وُجِّه إليه (مفتاحه الخاص لا يغادر خزنته الآمنة).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// استثناء التغليف/الفك — سبب موحّد: 'format' | 'kc' | 'device_pk' | 'auth'.
class KcWrapException implements Exception {
  KcWrapException(this.reason, [this.detail = '']);

  final String reason;
  final String detail;

  @override
  String toString() => 'KcWrapException($reason) $detail';
}

class KcWrap {
  KcWrap._();

  /// نطاق النطاق ASCII ‏'fizya-kc-wrap-v1' (16 بايت) — يدخل info وAAD.
  static final List<int> domain = 'fizya-kc-wrap-v1'.codeUnits;

  /// ملح HKDF صريح: 32 بايت أصفار (بلا الغموض «الملح الغائب» في RFC 5869).
  static final List<int> salt = List<int>.filled(32, 0);

  static const int publicKeyLength = 32;
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int kcLength = 32;

  /// eph_pk(32) ‖ nonce(12) ‖ ct(32) ‖ mac(16).
  static const int wrappedLength = 32 + nonceLength + kcLength + macLength;

  static final X25519 _x = X25519();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// يغلّف مفتاح الإصدار [kc] لمفتاح الجهاز العام [devicePublicKey] (32 بايت).
  ///
  /// [ephemeralSeed] و[nonce] للمتجهات الذهبية حصراً — الإنتاج عشوائي تاماً.
  static Future<Uint8List> wrap({
    required List<int> kc,
    required List<int> devicePublicKey,
    List<int>? ephemeralSeed,
    List<int>? nonce,
  }) async {
    _checkKc(kc);
    _checkPub(devicePublicKey, 'device_pk');
    final eph = ephemeralSeed == null
        ? await _x.newKeyPair()
        : await _x.newKeyPairFromSeed(ephemeralSeed);
    final ephPub = (await eph.extractPublicKey()).bytes;
    final n = List<int>.from(nonce ?? _randomBytes(nonceLength));
    if (n.length != nonceLength) {
      throw KcWrapException('format', 'طول nonce');
    }
    final remote = SimplePublicKey(devicePublicKey, type: KeyPairType.x25519);
    final shared = await (await _x.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: remote,
    ))
        .extractBytes();
    final info = <int>[...domain, ...ephPub, ...devicePublicKey];
    final wrapKey = await _wrapKey(shared, info);
    final box = await _aes.encrypt(kc, secretKey: wrapKey, nonce: n, aad: info);
    return Uint8List.fromList(<int>[
      ...ephPub,
      ...n,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// يفكّ تغليف [wrapped] بزوج الجهاز X25519 — أي جهاز آخر يُرفض (auth).
  static Future<Uint8List> unwrap({
    required List<int> wrapped,
    required SimpleKeyPair deviceKeyPair,
  }) async {
    if (wrapped.length != wrappedLength) {
      throw KcWrapException('format', 'طول kc_wrap_v1');
    }
    final ephPub = wrapped.sublist(0, publicKeyLength);
    final n = wrapped.sublist(32, 32 + nonceLength);
    final ct = wrapped.sublist(44, 44 + kcLength);
    final mac = wrapped.sublist(wrapped.length - macLength);
    final devicePub = (await deviceKeyPair.extractPublicKey()).bytes;
    final remote = SimplePublicKey(ephPub, type: KeyPairType.x25519);
    final shared = await (await _x.sharedSecretKey(
      keyPair: deviceKeyPair,
      remotePublicKey: remote,
    ))
        .extractBytes();
    final info = <int>[...domain, ...ephPub, ...devicePub];
    final wrapKey = await _wrapKey(shared, info);
    try {
      final kc = await _aes.decrypt(
        SecretBox(ct, nonce: n, mac: Mac(mac)),
        secretKey: wrapKey,
        aad: info,
      );
      return Uint8List.fromList(kc);
    } catch (e) {
      throw KcWrapException('auth', e.toString());
    }
  }

  /// wrapKey = HKDF-SHA256(ikm=shared ‖ salt=أصفار32 ‖ info) — info يربط
  /// النطاق والطرفين معاً (لا إعادة توجيه تغليف بين الأجهزة — RFC 9180 الروح).
  static Future<SecretKey> _wrapKey(List<int> shared, List<int> info) {
    return _hkdf.deriveKey(
      secretKey: SecretKey(shared),
      nonce: salt,
      info: info,
    );
  }

  static void _checkKc(List<int> kc) {
    if (kc.length != kcLength) {
      throw KcWrapException('kc', 'طول K_c');
    }
  }

  static void _checkPub(List<int> pub, String label) {
    if (pub.length != publicKeyLength) {
      throw KcWrapException('device_pk', 'طول $label');
    }
  }

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => r.nextInt(256)),
    );
  }
}
