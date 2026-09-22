// F6.3 — شهادة الموسم: حمولة canonical + توقيع Ed25519 محلي + طبقتا 🥇/🥈.
// متجه الاختبار ثابت البذرة — لا شبكة ولا أسرار.
import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/cert/certificate.dart';

void main() {
  final seed = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  final sk = ed.newKeyFromSeed(seed);
  final pk = ed.public(sk);

  Certificate sample({String notice = '', int xp = 1200}) => Certificate(
        id: '11111111-2222-3333-4444-555555555555',
        season: '2026-2027',
        tier: CertTier.goldTwoYears,
        years: 2,
        xp: xp,
        devicePubkeyB64: base64Encode(utf8.encode('device-pub')),
        issuedAtMs: 1790000000000,
        notice: notice,
        signatureB64: '',
      );

  group('الحمولة الـcanonical', () {
    test('ترتيب الحقول ثابت وبدون signature — كما يبنيه cert_issue', () {
      final c = sample();
      final keys = (jsonDecode(c.canonicalJson) as Map<String, dynamic>).keys;
      expect(
        keys.toList(),
        ['id', 'season', 'tier', 'years', 'xp', 'device_pubkey_b64',
         'issued_at_ms', 'notice'],
      );
      expect(c.canonicalJson.contains('signature'), isFalse);
    });

    test('JSON ذهاباً وإياباً متطابق حرفياً', () {
      final c = sample(notice: 'تنويه');
      final back = Certificate.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
      );
      expect(back.canonicalJson, c.canonicalJson);
      expect(back.tier, c.tier);
      expect(back.notice, 'تنويه');
    });
  });

  group('التوقيع والتحقق', () {
    test('توقيع بالمفتاح الصحيح ⇒ verify صحيح', () {
      final c = sample();
      final signed = Certificate(
        id: c.id,
        season: c.season,
        tier: c.tier,
        years: c.years,
        xp: c.xp,
        devicePubkeyB64: c.devicePubkeyB64,
        issuedAtMs: c.issuedAtMs,
        notice: c.notice,
        signatureB64: Certificate.signCanonical(c, sk),
      );
      expect(Certificate.verify(signed, publicKey: pk), isTrue);
    });

    test('تلاعب بالحمولة (xp) ⇒ verify يفشل', () {
      final c = sample();
      final sig = Certificate.signCanonical(c, sk);
      final tampered = Certificate(
        id: c.id,
        season: c.season,
        tier: c.tier,
        years: c.years,
        xp: c.xp + 1, // تلاعب
        devicePubkeyB64: c.devicePubkeyB64,
        issuedAtMs: c.issuedAtMs,
        notice: c.notice,
        signatureB64: sig,
      );
      expect(Certificate.verify(tampered, publicKey: pk), isFalse);
    });

    test('مفتاح عام آخر ⇒ verify يفشل · توقيع فارغ ⇒ false بلا رمي', () {
      final c = sample();
      final signed = Certificate(
        id: c.id,
        season: c.season,
        tier: c.tier,
        years: c.years,
        xp: c.xp,
        devicePubkeyB64: c.devicePubkeyB64,
        issuedAtMs: c.issuedAtMs,
        notice: c.notice,
        signatureB64: Certificate.signCanonical(c, sk),
      );
      final otherPk = ed.public(ed.newKeyFromSeed(Uint8List.fromList(
          List<int>.generate(32, (i) => 100 - i))));
      expect(Certificate.verify(signed, publicKey: otherPk), isFalse);
      final unsigned = Certificate(
        id: c.id,
        season: c.season,
        tier: c.tier,
        years: c.years,
        xp: c.xp,
        devicePubkeyB64: c.devicePubkeyB64,
        issuedAtMs: c.issuedAtMs,
        notice: c.notice,
        signatureB64: '',
      );
      expect(Certificate.verify(unsigned, publicKey: pk), isFalse);
      expect(
        () => Certificate.verify(
          Certificate.fromJson({...c.toJson(), 'signature': '!!ليس-ب64!!'}),
          publicKey: pk,
        ),
        returnsNormally,
      );
    });
  });

  group('الطبقات والعنوان', () {
    test('العنوان والملصقات حرفية كما في docs/13 وF6.3', () {
      expect(certTitle, 'بطل دوري فيزيا كلاش');
      expect(CertTier.goldTwoYears.machine, 'gold_two');
      expect(CertTier.goldTwoYears.label, '🥇 سنتان');
      expect(CertTier.silverOneYear.machine, 'silver_one');
      expect(CertTier.silverOneYear.label, '🥈 سنة');
      expect(CertTier.fromMachine('gold_two'), CertTier.goldTwoYears);
      // تنويه قرار ٤٠: لا نصّ مُخمَّن — ما دام غير مُسلَّم فهو فارغ
      expect(kFlexibilityNotice40, isEmpty);
    });
  });
}
