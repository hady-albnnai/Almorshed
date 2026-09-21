/// F2.2-T1 — خزنة مفتاح المحتوى K_c (قرار ٣٠ · قرار ٦٧ — docs/11 §٧).
///
/// بعد فكّ التغليف من السيرفر (kc_wrap_v1) يُخزَّن K_c هنا وحده؛ المتن
/// المفكوك لا يُكتب لأي مجلد عام أبداً — الفكّ في الذاكرة حصراً.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تجريداً عن آلية التخزين — يقابله XpKeyVault/DeviceKeyVault بالنمط ذاته.
abstract class ContentKeyVault {
  Future<Uint8List?> read();

  Future<void> write(Uint8List kc);

  Future<void> clear();
}

/// خزنة بالذاكرة — للاختبارات (بذرة حتمية ممكنة) والحقن.
class InMemoryContentKeyVault implements ContentKeyVault {
  InMemoryContentKeyVault([Uint8List? kc]) : _kc = kc;

  Uint8List? _kc;

  @override
  Future<Uint8List?> read() async => _kc;

  @override
  Future<void> write(Uint8List kc) async => _kc = kc;

  @override
  Future<void> clear() async => _kc = null;
}

/// خزنة الإنتاج: flutter_secure_storage — مفتاح واحد base64.
class SecureContentKeyVault implements ContentKeyVault {
  SecureContentKeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'content_kc_v1';

  @override
  Future<Uint8List?> read() async {
    final b64 = await _storage.read(key: _key);
    if (b64 == null || b64.isEmpty) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  @override
  Future<void> write(Uint8List kc) async {
    await _storage.write(key: _key, value: base64Encode(kc));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
