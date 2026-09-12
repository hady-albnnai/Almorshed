import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/license/license_core.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// F3.6 — اختبارات نواة الترخيص «الإيجار الموقّع»: توقيع/تحقق Ed25519
/// + حالات الحكم الخمس + كشف رجوع الساعة + الانتظار التدريجي + التنسيق.
void main() {
  // مفتاحا اختبار حتميان — الإصدار يوقّع والتحقق بالمفتاح العام فقط
  final serverKey = ed.newKeyFromSeed(
      Uint8List.fromList(List<int>.generate(32, (i) => i)));
  final otherKey = ed.newKeyFromSeed(
      Uint8List.fromList(List<int>.generate(32, (i) => 100 + i)));
  final publicKey = ed.public(serverKey);

  const nowMs = 1790000000000; // 2026-09-12 تقريباً
  LicensePayload payload({
    String codeId = 'K7M2P',
    int expiresAfterMs = 30 * 24 * 3600 * 1000,
    Set<String> flags = const {'full'},
  }) =>
      LicensePayload(
        codeId: codeId,
        deviceKeyHash: '',
        releaseId: '2027-v1',
        expiresAtMs: nowMs + expiresAfterMs,
        hardDeadlineMs: nowMs + 220 * 24 * 3600 * 1000,
        flags: flags,
      );

  group('التوقيع والتحقق — docs/11 §٥', () {
    test('دورة كاملة: إصدار ثم فحص محلي سليم (full وdemo)', () {
      final t = LicenseToken.issue(payload(), serverKey);
      final c = checkLicense(t, nowMs: nowMs, key: publicKey);
      expect(c.verdict, LicenseVerdict.valid);
      expect(c.ok, isTrue);

      final demo = LicenseToken.issue(
          payload(flags: {'demo'}), serverKey);
      final cd = checkLicense(demo, nowMs: nowMs, key: publicKey);
      expect(cd.verdict, LicenseVerdict.demo);
      expect(cd.ok, isTrue);
    });

    test('تلاعب بايت واحد بالحمولة ⇒ توقيع مرفوض', () {
      final t = LicenseToken.issue(payload(), serverKey);
      final bytes = t.payloadBytes;
      bytes[0] = bytes[0] ^ 0x01;
      final tampered = LicenseToken(
        payloadB64: base64Encode(bytes),
        sigB64: t.sigB64,
      );
      expect(checkLicense(tampered, nowMs: nowMs, key: publicKey).verdict,
          LicenseVerdict.badSignature);
    });

    test('مفتاح آخر (تزوير إصدار) ⇒ توقيع مرفوض', () {
      final t = LicenseToken.issue(payload(), otherKey);
      expect(checkLicense(t, nowMs: nowMs, key: publicKey).verdict,
          LicenseVerdict.badSignature);
    });

    test('بنية فاسدة ⇒ malformed بلا استثناءات', () {
      final garbage = LicenseToken(
          payloadB64: '!!!غير-قاعدي!!!', sigB64: '===');
      expect(checkLicense(garbage, nowMs: nowMs, key: publicKey).verdict,
          LicenseVerdict.malformed);
      final wrongJson = LicenseToken(
        payloadB64: base64Encode(utf8.encode('{"unexpected": 1}')),
        sigB64: base64Encode(Uint8List(64)),
      );
      // التوقيع على بنية غير متوقعة: قد يُرفض توقيعاً أو يفشل التحليل
      final v = checkLicense(wrongJson, nowMs: nowMs, key: publicKey);
      expect(
          v.verdict == LicenseVerdict.malformed ||
              v.verdict == LicenseVerdict.badSignature,
          isTrue);
    });

    test('توكن جهاز آخر (hash غير فارغ) ⇒ wrongDevice', () {
      final p = LicensePayload(
        codeId: 'K7M2P',
        deviceKeyHash: 'deadbeef',
        releaseId: '2027-v1',
        expiresAtMs: nowMs + 1000,
        hardDeadlineMs: nowMs + 2000,
        flags: const {'full'},
      );
      final t = LicenseToken.issue(p, serverKey);
      expect(checkLicense(t, nowMs: nowMs, key: publicKey).verdict,
          LicenseVerdict.wrongDevice);
    });
  });

  group('الزمن — انتهاء الإيجار والحد الصلب (قرار ٢٠/٢٧)', () {
    test('منتهٍ ⇒ expired والحد الصلب يقطع حتى قبل الانتهاء', () {
      final t = LicenseToken.issue(
          payload(expiresAfterMs: 1000), serverKey);
      // عند الحد بالضبط لا يزال صالحاً (الشرط أكبر-حصراً) ثم يمنع
      expect(
          checkLicense(t, nowMs: nowMs + 1000, key: publicKey).verdict,
          LicenseVerdict.valid);
      expect(
          checkLicense(t, nowMs: nowMs + 1001, key: publicKey).verdict,
          LicenseVerdict.expired);
    });

    test('الحد الصلب: تجاوز يوم الامتحان ⇒ hardPassed مهما كان الإيجار', () {
      final p = LicensePayload(
        codeId: 'K7M2P',
        deviceKeyHash: '',
        releaseId: '2027-v1',
        expiresAtMs: nowMs + 400 * 24 * 3600 * 1000, // أبعد من الحد
        hardDeadlineMs: nowMs + 220 * 24 * 3600 * 1000,
        flags: const {'full'},
      );
      final t = LicenseToken.issue(p, serverKey);
      expect(checkLicense(t, nowMs: nowMs, key: publicKey).verdict,
          LicenseVerdict.valid);
      expect(
          checkLicense(t,
                  nowMs: nowMs + 220 * 24 * 3600 * 1000 + 1, key: publicKey)
              .verdict,
          LicenseVerdict.hardPassed);
    });
  });

  group('L4 — كشف رجوع الساعة (سماحية ٥ دقائق)', () {
    test('رجوع أكبر من السماحية ⇒ مشتبهة، وداخلها أو للأمام ⇒ سليم', () {
      // رجوع ٧ دقائق ⇒ مشتبهة
      expect(
          clockRollbackSuspected(
              lastWallMs: nowMs, nowMs: nowMs - 7 * 60000),
          isTrue);
      // رجوع ٣ دقائق (داخل السماحية) ⇒ سليم
      expect(
          clockRollbackSuspected(
              lastWallMs: nowMs, nowMs: nowMs - 3 * 60000),
          isFalse);
      // إقرار ساعة للأمام لا يُشتبه
      expect(
          clockRollbackSuspected(
              lastWallMs: nowMs, nowMs: nowMs + 30 * 60000),
          isFalse);
    });
  });

  group('الانتظار التدريجي — بعد ٥ محاولات (النموذج)', () {
    test('أول ٤ حرة ثم ٥/١٠/٢٠/٤٠ بسقف ٦٠', () {
      expect(lockoutMinutesFor(0), 0);
      expect(lockoutMinutesFor(4), 0);
      expect(lockoutMinutesFor(5), 5);
      expect(lockoutMinutesFor(6), 10);
      expect(lockoutMinutesFor(7), 20);
      expect(lockoutMinutesFor(8), 40);
      expect(lockoutMinutesFor(9), 60); // السقف
      expect(lockoutMinutesFor(25), 60);
    });
  });

  group('تنسيق الكود — ٥-٥-٥ كالنموذج', () {
    test('حروف صغيرة ورموز غريبة تُصفّى وتُقص عند ١٥', () {
      expect(formatLicenseCode('k7m2p-9qw4x-4tr8n'),
          'K7M2P-9QW4X-4TR8N');
      expect(formatLicenseCode('k7m2p9qw4x4tr8n'), 'K7M2P-9QW4X-4TR8N');
      expect(formatLicenseCode('A1B2C-D3E4F-G5H6J-K7M2P-9!'),
          'A1B2C-D3E4F-G5H6J');
      expect(formatLicenseCode('AB'), 'AB');
      expect(formatLicenseCode(''), '');
    });
    test('إخفاء الكود للعرض — النموذج K7M2P-•••••-•••••', () {
      expect(maskCodeId('K7M2P9QW4X4TR8N'), 'K7M2P-•••••-•••••');
    });
  });
}
