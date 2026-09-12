/// F3.7 — مفتاح الجهاز لتوقيع أحداث XP (docs/11 §٦ + docs/12 §٤.۲).
/// البذرة 32 بايت تعيش في خزنة آمنة (flutter_secure_storage الآن —
/// والترقية لـKeystore غير القابل للتصدير مع F4.4). المفتاح العام فقط
/// هو ما يتحقق منه السيرفر لاحقاً؛ التوقيع محلي دائماً.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خزنة بذرة مفتاح الجهاز — تجريداً عن آلية التخزين.
abstract class XpKeyVault {
  Future<Uint8List?> readSeed();
  Future<void> writeSeed(Uint8List seed);
}

/// خزنة بالذاكرة — للاختبارات (بذرة حتمية ممكنة) والحقن.
class InMemoryXpKeyVault implements XpKeyVault {
  InMemoryXpKeyVault([Uint8List? seed]) : _seed = seed;

  Uint8List? _seed;

  @override
  Future<Uint8List?> readSeed() async => _seed;

  @override
  Future<void> writeSeed(Uint8List seed) async => _seed = seed;
}

/// خزنة الإنتاج: flutter_secure_storage — مفتاح واحد base64.
class SecureXpKeyVault implements XpKeyVault {
  SecureXpKeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'xp_device_seed_v1';

  @override
  Future<Uint8List?> readSeed() async {
    final b64 = await _storage.read(key: _key);
    if (b64 == null || b64.isEmpty) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  @override
  Future<void> writeSeed(Uint8List seed) async {
    await _storage.write(key: _key, value: base64Encode(seed));
  }
}

/// موقّع أحداث XP بمفتاح الجهاز — البذرة تُولَّد أول مرة وتُخزَّن.
class XpSigner {
  XpSigner._(this._privateKey, this.publicKey, this.seed);

  final ed.PrivateKey _privateKey;
  final Uint8List seed;
  final ed.PublicKey publicKey;

  /// من خزنة موجودة أو يولّد بذرة عشوائية جديدة ويخزنها — مرة واحدة.
  static Future<XpSigner> load(XpKeyVault vault) async {
    var seed = await vault.readSeed();
    if (seed == null || seed.length != 32) {
      seed = Uint8List(32);
      final rng = Random.secure();
      for (var i = 0; i < 32; i++) {
        seed[i] = rng.nextInt(256);
      }
      await vault.writeSeed(seed);
    }
    return XpSigner.fromSeed(seed); // داخل static: بادئة الصنف إلزامية
  }

  /// حتمي من بذرة معلومة — للاختبارات والمتجهات الذهبية.
  factory XpSigner.fromSeed(Uint8List seed) {
    final privateKey = ed.newKeyFromSeed(seed);
    final publicKey = ed.public(privateKey);
    return XpSigner._(privateKey, publicKey, Uint8List.fromList(seed));
  }

  /// توقيع بايتات الهاش — base64 للتخزين.
  String signHash(Uint8List hashBytes) =>
      base64Encode(ed.sign(_privateKey, hashBytes));

  /// تحقق التوقيع ضد المفتاح العام لهذا الموقّع.
  bool verifyHash(Uint8List hashBytes, String sigB64) {
    final Uint8List sig;
    try {
      sig = Uint8List.fromList(base64Decode(sigB64));
    } catch (_) {
      return false;
    }
    try {
      return ed.verify(publicKey, hashBytes, sig);
    } catch (_) {
      return false;
    }
  }
}
