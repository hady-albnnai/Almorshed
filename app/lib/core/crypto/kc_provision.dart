/// F2.2-T2 — تزويد K_c من الخادم (قرار ٣٠ · قرار ٦٧ · docs/16 §١٠.٢/§١٠.٣).
///
/// يجمع خزنة زوج الجهاز X25519 وخزنة K_c بواجهة واحدة يستعملها التفعيل
/// والنبض: يعطي المفتاح العام للرفع، ويبتلع رد الخادم فإن حمل `kc_wrapped`
/// فكّه بمفتاح الجهاز الخاص (لا يغادر خزنته) وحفظ K_c في خزنة المحتوى.
/// أي رد بلا الحقل ⇒ لا شيء يتغير (الواجهة ثابتة — القراءة النصية تستمر).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'content_key_vault.dart';
import 'device_key_vault.dart';
import 'kc_wrap.dart';

class ContentKeyProvisioner {
  ContentKeyProvisioner({
    required this.deviceKeys,
    required this.contentKeys,
  });

  final DeviceKeyVault deviceKeys;
  final ContentKeyVault contentKeys;

  /// مفتاح X25519 العام base64 (44 محرفاً) — يُرسل بحقل
  /// `device_x25519_pub_b64` في license_activate وheartbeat.
  Future<String> devicePublicB64() async =>
      base64Encode(await deviceKeys.publicBytes());

  /// هل K_c حاضر بالخزنة؟ (إن لا ⇒ النبض يطلبه بـ`want_kc`).
  Future<bool> get hasKey async => (await contentKeys.read()) != null;

  /// يبتلع رد خادم: إن حمل `kc_wrapped` (base64 لـ92 بايت) فكّه وحفظه.
  ///
  /// يعيد true عند حفظ مفتاح جديد. فشل الفكّ (تغليف لجهاز آخر/عبث) لا
  /// يرمي — يُعاد false ويبقى المفتاح القديم إن وُجد (النبض لا يحجب شيئاً).
  Future<bool> ingest(Map<String, dynamic> response) async {
    final wrappedB64 = response['kc_wrapped'];
    if (wrappedB64 is! String || wrappedB64.isEmpty) return false;
    final Uint8List wrapped;
    try {
      wrapped = base64Decode(wrappedB64);
    } on FormatException {
      return false;
    }
    try {
      final kc = await KcWrap.unwrap(
        wrapped: wrapped,
        deviceKeyPair: await deviceKeys.loadOrCreate(),
      );
      await contentKeys.write(kc);
      return true;
    } on KcWrapException {
      return false;
    }
  }
}
