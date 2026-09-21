// M6/F6.1 — عقد شكل الكود بين أداة المكتب (office_codes) والعميل.
// الكود: ١٥ محرفاً Crockford بلا I/L/O/U — مطابق CODE_RE الخادم
// `^[0-9A-HJ-KM-NP-TV-Z]{15}$` وتنسيق ٥-٥-٥ (formatLicenseCode).
// أي انحراف هنا = كود يولّده المكتب لا يقبله license_activate أو
// يتعذر على الطالب إدخاله. العقد الكامل: docs/16 §٢.
import 'dart:math';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';
import 'package:fizya_clash/core/license/license_core.dart';

void main() {
  final serverRe = RegExp(r'^[0-9A-HJ-KM-NP-TV-Z]{15}$');
  final dashed = RegExp(r'^[0-9A-Z]{5}-[0-9A-Z]{5}-[0-9A-Z]{5}$');

  test('أبجدية Crockford: ٣٢ محرفاً بلا I/L/O/U — مطابقة الخادم', () {
    expect(RoomCode.alphabet.length, 32);
    expect(RoomCode.alphabet, '0123456789ABCDEFGHJKMNPQRSTVWXYZ');
    expect(RegExp(r'[ILOU]').hasMatch(RoomCode.alphabet), isFalse);
  });

  test('أكواد مولّدة من أبجدية العميل تمرّ كلها من CODE_RE الخادم', () {
    final rng = Random(20270914);
    for (var n = 0; n < 1000; n++) {
      final sb = StringBuffer();
      for (var i = 0; i < 15; i++) {
        sb.write(RoomCode.alphabet[rng.nextInt(32)]);
      }
      expect(serverRe.hasMatch(sb.toString()), isTrue,
          reason: 'الكود ${sb.toString()} يجب أن يقبله الخادم');
    }
  });

  test('تنسيق الكود ٥-٥-٥ — كما سيدخله الطالب', () {
    const raw = 'K7M2P9QW4XABCDE';
    final formatted = formatLicenseCode(raw);
    expect(formatted, 'K7M2P-9QW4X-ABCDE');
    expect(dashed.hasMatch(formatted), isTrue);
    // التطبيع: صغير + رموز غريبة
    expect(formatLicenseCode('k7m2p-9qw4x-abcde'), 'K7M2P-9QW4X-ABCDE');
  });

  test('تفرد عشوائي: ٥٠٠٠ كود بلا تكرار (مقياس أمان المكتب)', () {
    final rng = Random(42);
    final seen = <String>{};
    for (var n = 0; n < 5000; n++) {
      final sb = StringBuffer();
      for (var i = 0; i < 15; i++) {
        sb.write(RoomCode.alphabet[rng.nextInt(32)]);
      }
      seen.add(sb.toString());
    }
    expect(seen.length, 5000);
  });

  test('توقيع وفحص كود أصدرته أداة المكتب — جولة كاملة Ed25519', () {
    // نفس نمط license_test: الإصدار بمفتاح والفحص المحلي بالمفتاح العام فقط
    final serverKey = ed.newKeyFromSeed(
        Uint8List.fromList(List<int>.generate(32, (i) => i * 7 + 1)));
    final publicKey = ed.public(serverKey);
    final payload = LicensePayload(
      codeId: 'K7M2P9QW4XABCDE',
      deviceKeyHash: '',
      releaseId: '2027-v1',
      expiresAtMs: 1835904000000 - 1,
      hardDeadlineMs: 1835904000000,
      flags: const {'full'},
    );
    final token = LicenseToken.issue(payload, serverKey);
    // فحص أعمى (بلا مفتاح جهاز) — يقبل لأن deviceKeyHash فارغ
    final verdict = checkLicense(
      token,
      nowMs: 1835904000000 - 1000,
      key: publicKey,
    );
    expect(verdict.verdict, LicenseVerdict.valid);
  });
}
