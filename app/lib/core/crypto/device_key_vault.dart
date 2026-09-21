/// F2.2-T1 — خزنة زوج X25519 لمفتاح الجهاز (قرار ٣٠ · docs/11 §٦).
///
/// البذرة 32 بايت تعيش في خزنة آمنة (flutter_secure_storage الآن — الترقية
/// لـKeystore غير القابل للتصدير مع F4.4 كما لـXpSigner). هذا المفتاح
/// يُشفَّر إليه K_c (kc_wrap_v1) فلا ينتقل المحتوى لجهاز آخر.
///
/// درس لصقة 2026-09-21: `implements` لا ترث أجرام الدوال — الوراثة هنا
/// `extends` لتصير loadOrCreate/publicBytes موروثتين لا التزامات مجردة.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خزنة بذرة زوج X25519 — تجريداً عن آلية التخزين.
abstract class DeviceKeyVault {
  Future<Uint8List?> readSeed();

  Future<void> writeSeed(Uint8List seed);

  /// يقرأ البذرة أو يولدها أول مرة ثم يعيد زوج X25519 جاهزاً.
  Future<SimpleKeyPair> loadOrCreate() async {
    var seed = await readSeed();
    if (seed == null) {
      final created = await X25519().newKeyPair();
      seed = Uint8List.fromList(await created.extractPrivateKeyBytes());
      await writeSeed(seed);
      return created;
    }
    return X25519().newKeyPairFromSeed(seed);
  }

  /// المفتاح العام 32 بايت (يُرفع للسيرفر عند التفعيل — T2).
  Future<Uint8List> publicBytes() async {
    final pair = await loadOrCreate();
    return Uint8List.fromList((await pair.extractPublicKey()).bytes);
  }
}

/// خزنة بالذاكرة — للاختبارات (بذرة حتمية ممكنة) والحقن.
class InMemoryDeviceKeyVault extends DeviceKeyVault {
  InMemoryDeviceKeyVault([Uint8List? seed]) : _seed = seed;

  Uint8List? _seed;

  @override
  Future<Uint8List?> readSeed() async => _seed;

  @override
  Future<void> writeSeed(Uint8List seed) async => _seed = seed;
}

/// خزنة الإنتاج: flutter_secure_storage — مفتاح واحد base64.
class SecureDeviceKeyVault extends DeviceKeyVault {
  SecureDeviceKeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'device_x25519_seed_v1';

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
