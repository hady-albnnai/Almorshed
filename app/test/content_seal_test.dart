/// F2.2-T1 — pack_seal_v1: ختم/فتح + مقاومة العبث + المتجهات الذهبية
/// (مولَّدة بـtools/gen_content_crypto_vectors.mjs — تحقّق مزدوج Dart↔Node).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/crypto/content_seal.dart';

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
  test('دورة ختم/فتح — أجوف ونص عربي وعشوائي 10KB', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final inputs = <List<int>>[
      <int>[],
      utf8.encode('فيزيا كلاش — Clash of Physics ⚡'),
      Uint8List.fromList(List<int>.generate(10 * 1024, (i) => i & 0xFF)),
    ];
    for (final plain in inputs) {
      final sealed = await ContentSeal.seal(plain, key: key);
      expect(sealed.length, plain.length + ContentSeal.headerLength + 16);
      final clear = await ContentSeal.open(sealed, key: key);
      expect(clear, equals(plain));
    }
  });

  test('nonce مثبّت ⇒ ختم حتمي؛ الافتراضي عشوائي ⇒ نتائج تختلف', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => 3));
    final plain = utf8.encode('نفس المتن');
    final nonce = Uint8List.fromList(List<int>.generate(12, (i) => 9));
    final a = await ContentSeal.seal(plain, key: key, nonce: nonce);
    final b = await ContentSeal.seal(plain, key: key, nonce: nonce);
    expect(a, equals(b));

    final c = await ContentSeal.seal(plain, key: key);
    final d = await ContentSeal.seal(plain, key: key);
    expect(c, isNot(equals(d)));
    expect(await ContentSeal.open(c, key: key), equals(plain));
    expect(await ContentSeal.open(d, key: key), equals(plain));
  });

  test('العبث بكل منطقة يُرفض + ترويسة/طول معطوب', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => 7 + i));
    final plain = utf8.encode('حزمة');
    final sealed = await ContentSeal.seal(plain, key: key);

    // قلب بايت في: الترويسة والـnonce والمتن والتذكار ⇒ رفض كامل
    final flipTargets = <int>[0, 3, 4, 15, 16, sealed.length - 1, sealed.length - 16];
    for (final i in flipTargets) {
      final tampered = Uint8List.fromList(sealed);
      tampered[i] = tampered[i] ^ 0xFF;
      await expectLater(
        ContentSeal.open(tampered, key: key),
        throwsA(isA<ContentSealException>()),
      );
    }

    await expectLater(
      ContentSeal.open(sealed.sublist(0, 10), key: key),
      throwsA(predicate((e) => e is ContentSealException && e.reason == 'format')),
    );

    final badMagic = Uint8List.fromList(sealed);
    badMagic[1] = 0x58; // 'FCP1' ⇒ 'FXP1'
    await expectLater(
      ContentSeal.open(badMagic, key: key),
      throwsA(predicate((e) => e is ContentSealException && e.reason == 'format')),
    );
  });

  test('مفتاح خاطئ يُرفض (auth) ومفتاح خاطئ الطول (key)', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => 21));
    final sealed = await ContentSeal.seal(utf8.encode('سري'), key: key);
    final wrongKey = Uint8List.fromList(List<int>.generate(32, (i) => 22));
    await expectLater(
      ContentSeal.open(sealed, key: wrongKey),
      throwsA(predicate((e) => e is ContentSealException && e.reason == 'auth')),
    );
    await expectLater(
      ContentSeal.seal(utf8.encode('x'), key: Uint8List(31)),
      throwsA(predicate((e) => e is ContentSealException && e.reason == 'key')),
    );
    await expectLater(
      ContentSeal.open(sealed, key: Uint8List(33)),
      throwsA(predicate((e) => e is ContentSealException && e.reason == 'key')),
    );
  });

  test('المتجة الذهبي pack_seal_v1 بتّياً (Node ↔ Dart)', () async {
    final v = loadVectors()['pack_seal_v1'] as Map<String, dynamic>;
    final key = hexToBytes(v['key'] as String);
    final nonce = hexToBytes(v['nonce'] as String);
    final plain = hexToBytes(v['plain_hex'] as String);
    final sealedGolden = hexToBytes(v['sealed'] as String);

    // AAD مجمّد مطابق للنطاق
    expect(hexToBytes(v['aad'] as String), equals(ContentSeal.aad));
    expect(ContentSeal.aad, 'fizya-pack-seal-v1'.codeUnits);

    final sealed = await ContentSeal.seal(plain, key: key, nonce: nonce);
    expect(sealed, equals(sealedGolden));

    final clear = await ContentSeal.open(sealedGolden, key: key);
    expect(clear, equals(plain));
    expect(utf8.decode(clear), v['plain_utf8']);
  });
}
