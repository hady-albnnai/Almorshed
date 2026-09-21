/// F2.2-T1 — kc_wrap_v1: sealed-box (X25519+HKDF+AES-GCM) + خزنة الجهاز
/// + المتجهات الذهبية (Node ↔ Dart — RFC 7748 و5869 أرضية التحقق).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/crypto/device_key_vault.dart';
import 'package:fizya_clash/core/crypto/kc_wrap.dart';

List<int> hexToBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return out;
}

Map<String, dynamic> loadVectors() {
  final file =
      File('${Directory.current.path}/test/fixtures/content_crypto_vectors.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test('RFC 7748 §6.1 — البذرة⇒العامة والمفتاح المشترك بتّياً', () async {
    final v = loadVectors()['rfc7748'] as Map<String, dynamic>;
    final alice =
        await X25519().newKeyPairFromSeed(hexToBytes(v['alice_seed'] as String));
    final bob =
        await X25519().newKeyPairFromSeed(hexToBytes(v['bob_seed'] as String));
    expect(
      (await alice.extractPublicKey()).bytes,
      equals(hexToBytes(v['alice_pub'] as String)),
    );
    expect(
      (await bob.extractPublicKey()).bytes,
      equals(hexToBytes(v['bob_pub'] as String)),
    );
    final shared = await (await X25519().sharedSecretKey(
      keyPair: alice,
      remotePublicKey: await bob.extractPublicKey(),
    ))
        .extractBytes();
    expect(shared, equals(hexToBytes(v['shared'] as String)));
  });

  test('RFC 5869 حالة ١ — Hkdf ‏(nonce=ملح) مطابق RFC', () async {
    final v = loadVectors()['rfc5869_case1'] as Map<String, dynamic>;
    final out = await Hkdf(hmac: Hmac.sha256(), outputLength: 42).deriveKey(
      secretKey: SecretKey(hexToBytes(v['ikm'] as String)),
      nonce: hexToBytes(v['salt'] as String),
      info: hexToBytes(v['info'] as String),
    );
    expect(await out.extractBytes(), equals(hexToBytes(v['okm'] as String)));
  });

  test('kc_wrap_v1 المتجه الذهبي — تغليف حتمي وفكّ بتّي (Node ↔ Dart)', () async {
    final v = loadVectors()['kc_wrap_v1'] as Map<String, dynamic>;
    final kc = hexToBytes(v['kc'] as String);
    final wrapped = await KcWrap.wrap(
      kc: kc,
      devicePublicKey: hexToBytes(v['device_pub'] as String),
      ephemeralSeed: hexToBytes(v['eph_seed'] as String),
      nonce: hexToBytes(v['nonce'] as String),
    );
    expect(wrapped, equals(hexToBytes(v['wrapped'] as String)));

    final device = await X25519()
        .newKeyPairFromSeed(hexToBytes(v['device_seed'] as String));
    expect(await KcWrap.unwrap(wrapped: wrapped, deviceKeyPair: device),
        equals(kc));
  });

  test('جهاز آخر لا يفكّ + العبث يُرفض + طول خاطئ', () async {
    final v = loadVectors()['kc_wrap_v1'] as Map<String, dynamic>;
    final other =
        loadVectors()['kc_wrap_v1_other_device'] as Map<String, dynamic>;
    final wrapped = hexToBytes(v['wrapped'] as String);
    final device = await X25519()
        .newKeyPairFromSeed(hexToBytes(v['device_seed'] as String));
    final otherPair = await X25519()
        .newKeyPairFromSeed(hexToBytes(other['device_seed'] as String));

    await expectLater(
      KcWrap.unwrap(wrapped: wrapped, deviceKeyPair: otherPair),
      throwsA(predicate((e) => e is KcWrapException && e.reason == 'auth')),
    );

    final tampered = Uint8List.fromList(wrapped);
    tampered[50] = tampered[50] ^ 0xFF; // داخل المتن
    await expectLater(
      KcWrap.unwrap(wrapped: tampered, deviceKeyPair: device),
      throwsA(isA<KcWrapException>()),
    );

    await expectLater(
      KcWrap.unwrap(wrapped: wrapped.sublist(0, 20), deviceKeyPair: device),
      throwsA(predicate((e) => e is KcWrapException && e.reason == 'format')),
    );
  });

  test('دورة حية: خزنة بالذاكرة ⇒ تغليف/فكّ عشوائيان + حدود الإدخال', () async {
    final vault = InMemoryDeviceKeyVault();
    final pair = await vault.loadOrCreate();
    final pub = await vault.publicBytes();
    expect(pub, hasLength(KcWrap.publicKeyLength));
    // البذرة مخزّنة ⇒ نداء ثانٍ يعيد العلامة العامة نفسها
    expect((await (await vault.loadOrCreate()).extractPublicKey()).bytes,
        equals(pub));

    final kc = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
    final wrapped = await KcWrap.wrap(kc: kc, devicePublicKey: pub);
    expect(wrapped, hasLength(KcWrap.wrappedLength));
    expect(await KcWrap.unwrap(wrapped: wrapped, deviceKeyPair: pair),
        equals(kc));

    // eph/nonce عشوائيان ⇒ تغليفان مختلفان وكلاهما يُفكّ
    final wrapped2 = await KcWrap.wrap(kc: kc, devicePublicKey: pub);
    expect(wrapped2, isNot(equals(wrapped)));
    expect(await KcWrap.unwrap(wrapped: wrapped2, deviceKeyPair: pair),
        equals(kc));

    await expectLater(
      KcWrap.wrap(kc: <int>[1, 2], devicePublicKey: pub),
      throwsA(predicate((e) => e is KcWrapException && e.reason == 'kc')),
    );
    await expectLater(
      KcWrap.wrap(kc: kc, devicePublicKey: pub.sublist(0, 10)),
      throwsA(predicate((e) => e is KcWrapException && e.reason == 'device_pk')),
    );
  });

  test('خزنة الجهاز: البذرة تُستعاد وتلد الزوج ذاته', () async {
    final seed = Uint8List.fromList(List<int>.generate(32, (i) => 42));
    final vault = InMemoryDeviceKeyVault(seed);
    expect(await vault.readSeed(), equals(seed));
    final pub1 = await vault.publicBytes();
    final pub2 =
        await InMemoryDeviceKeyVault(Uint8List.fromList(seed)).publicBytes();
    expect(pub1, equals(pub2)); // حتمية البذرة⇒الزوج

    final fresh = InMemoryDeviceKeyVault();
    await fresh.writeSeed(Uint8List.fromList(seed));
    expect(await fresh.publicBytes(), equals(pub1));
  });
}
