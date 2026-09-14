import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:fizya_clash/core/license/heartbeat_client.dart';
import 'package:fizya_clash/core/license/license_core.dart';
import 'package:fizya_clash/core/license/license_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// F7.4 — نبض الترخيص: منطق تطبيق ردّ heartbeat بلا شبكة.
/// يثبت: الأرضية الرتيبة لا تتراجع · التوكن المجدَّد يُقبل فقط بعد تحقق
/// محلي كامل (توقيع + جهاز) · التوكن المزوّر/الغريب يُهمل صامتاً.
void main() {
  final serverKey = ed.newKeyFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => i)),
  );
  final otherKey = ed.newKeyFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => 100 + i)),
  );
  final publicKey = ed.public(serverKey);

  // مفتاح جهاز ثابت + هاشه كما يحسبه الخادم
  final devicePub = Uint8List.fromList(List<int>.generate(32, (i) => 7 * i));
  final deviceHash = deviceKeyHashFor(devicePub);

  const nowMs = 1790000000000;
  const day = 24 * 3600 * 1000;

  LicenseToken issue({
    int expiresAtMs = nowMs + 30 * day,
    String hash = '',
    ed.PrivateKey? key,
  }) => LicenseToken.issue(
    LicensePayload(
      codeId: 'K7M2P9QW4XABCDE',
      deviceKeyHash: hash,
      releaseId: '2027-v1',
      expiresAtMs: expiresAtMs,
      hardDeadlineMs: nowMs + 220 * day,
      flags: const {'full'},
    ),
    key ?? serverKey,
  );

  Map<String, dynamic> tokenJson(LicenseToken t) => <String, dynamic>{
    'payload': t.payloadB64,
    'sig': t.sigB64,
  };

  final oldToken = issue(hash: deviceHash, expiresAtMs: nowMs + 3 * day);
  final base = LicenseData(
    mode: LicenseMode.licensed,
    token: oldToken,
    lastWallMs: nowMs,
  );

  group('الأرضية الرتيبة (L4)', () {
    test('زمن سيرفر أحدث ⇒ يرفع lastWallMs', () {
      final r = applyHeartbeatResponse(
        base,
        {'ok': true, 'server_time_ms': nowMs + 5 * day},
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r, isNotNull);
      expect(r!.lastWallMs, nowMs + 5 * day);
      expect(r.token, same(oldToken)); // بلا توكن جديد ⇒ القديم يبقى
    });

    test('زمن سيرفر أقدم (رد متأخر/مكرر) ⇒ لا تراجع، لا حفظ', () {
      final r = applyHeartbeatResponse(
        base,
        {'ok': true, 'server_time_ms': nowMs - 1 * day},
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r, isNull);
    });

    test('رد بلا server_time_ms ⇒ يُهمل', () {
      expect(
        applyHeartbeatResponse(
          base,
          {'ok': true},
          devicePubkeyBytes: devicePub,
          key: publicKey,
        ),
        isNull,
      );
    });
  });

  group('التجديد الصامت (docs/11 §٥)', () {
    test('توكن مجدَّد سليم لهذا الجهاز ⇒ يُقبل ويُحفظ', () {
      final fresh = issue(hash: deviceHash, expiresAtMs: nowMs + 32 * day);
      final r = applyHeartbeatResponse(
        base,
        {
          'ok': true,
          'server_time_ms': nowMs + 2 * day,
          'renewed': true,
          'token': tokenJson(fresh),
        },
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r, isNotNull);
      expect(r!.token!.payloadB64, fresh.payloadB64);
      expect(r.mode, LicenseMode.licensed);
      final c = checkLicense(
        r.token!,
        nowMs: nowMs + 31 * day,
        key: publicKey,
        devicePubkeyBytes: devicePub,
      );
      expect(c.ok, isTrue); // ما بعد انتهاء القديم — الجديد يغطي
    });

    test('توكن موقّع بمفتاح آخر (خادم مزيّف) ⇒ يُهمل، القديم يبقى', () {
      final forged = issue(
        hash: deviceHash,
        expiresAtMs: nowMs + 365 * day,
        key: otherKey,
      );
      final r = applyHeartbeatResponse(
        base,
        {
          'ok': true,
          'server_time_ms': nowMs + 2 * day,
          'token': tokenJson(forged),
        },
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r, isNotNull); // الأرضية ارتفعت
      expect(r!.token!.payloadB64, oldToken.payloadB64); // التوكن لم يتغيّر
    });

    test('توكن جهاز آخر (نُسخ من طالب ثانٍ) ⇒ يُهمل', () {
      final otherDevice = Uint8List.fromList(
        List<int>.generate(32, (i) => 3 * i + 1),
      );
      final stolen = issue(
        hash: deviceKeyHashFor(otherDevice),
        expiresAtMs: nowMs + 40 * day,
      );
      final r = applyHeartbeatResponse(
        base,
        {
          'ok': true,
          'server_time_ms': nowMs + 2 * day,
          'token': tokenJson(stolen),
        },
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r!.token!.payloadB64, oldToken.payloadB64);
    });

    test('توكن بايت معطوب/حقول ناقصة ⇒ يُهمل بلا انفجار', () {
      final r1 = applyHeartbeatResponse(
        base,
        {
          'ok': true,
          'server_time_ms': nowMs + 1,
          'token': {
            'payload': base64Encode([1, 2, 3]),
            'sig': 'x',
          },
        },
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r1!.token!.payloadB64, oldToken.payloadB64);
      final r2 = applyHeartbeatResponse(
        base,
        {
          'ok': true,
          'server_time_ms': nowMs + 1,
          'token': {'payload': 'only'},
        },
        devicePubkeyBytes: devicePub,
        key: publicKey,
      );
      expect(r2!.token!.payloadB64, oldToken.payloadB64);
    });
  });
}
