/// F2.2-T1 — ContentKeyVault + محمّل الحزمة بمسار pack_seal_v1 المشفّر
/// (قرار ٣٠: بلا مفتاح ⇒ القراءة النصية كالسابق؛ بمفتاح ⇒ الفكّ حصراً).
///
/// درس لصقة 2026-09-21: ملفات الاختبار المؤقتة تُكتب بمسارات **نسبية**
/// داخل test/fixtures — فالمطلق بنوافذ ويندوز يُشوَّه داخل `Uri(path:)`
/// بـPlatformAssetBundle فيصل المُعالج مفتاحاً مشوَّهاً فتفشل قراءته.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/content_loader.dart';
import 'package:fizya_clash/core/crypto/content_key_vault.dart';
import 'package:fizya_clash/core/crypto/content_seal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempFiles = <String>[];
  String tempFixture(String name) {
    final path = 'test/fixtures/tmp_$name';
    tempFiles.add(path);
    return path;
  }

  setUpAll(() {
    // أصول من القرص مباشرة (قناة content_loader_test المجرَّبة — بلا تلويث
    // pubspec بملفات الاختبار) — مسارات نسبية حصراً (انظر تعليق الملف).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final file = File('${Directory.current.path}/$key');
        return ByteData.view(
            Uint8List.fromList(file.readAsBytesSync()).buffer);
      },
    );
  });

  tearDownAll(() {
    for (final p in tempFiles) {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    }
  });

  test('خزنة المحتوى: كتابة/قراءة/مسح بالذاكرة', () async {
    final vault = InMemoryContentKeyVault();
    expect(await vault.read(), isNull);
    final kc = Uint8List.fromList(List<int>.generate(32, (i) => i));
    await vault.write(kc);
    expect(await vault.read(), equals(kc));
    await vault.clear();
    expect(await vault.read(), isNull);
  });

  test('بلا خزنة أو بلا مفتاح ⇒ القراءة النصية (مسار العرض الحالي)', () async {
    const root = AssetRoot(
      glossaryPath: 'assets/content/glossary.json',
      packPath: 'test/fixtures/sample_pack.json',
    );
    final pack = await ContentLoader(root: root).loadPack();
    expect(pack.approvedQuestions, hasLength(1));

    final emptyVaultLoader =
        ContentLoader(root: root, keys: InMemoryContentKeyVault());
    final pack2 = await emptyVaultLoader.loadPack();
    expect(pack2.approvedQuestions, hasLength(1));
    expect((await emptyVaultLoader.loadGlossary()).termCount, 444);
  });

  test('بمفتاح K_c ⇒ فكّ pack_seal_v1 من الأصول المشفرة', () async {
    final kc = Uint8List.fromList(List<int>.generate(32, (i) => 11 + i));
    final plainPack =
        File('${Directory.current.path}/test/fixtures/sample_pack.json')
            .readAsBytesSync();
    final plainGlossary =
        File('${Directory.current.path}/assets/content/glossary.json')
            .readAsBytesSync();
    final packPath = tempFixture('sample_pack.json.sealed');
    final glossaryPath = tempFixture('glossary.json.sealed');
    File(packPath)
        .writeAsBytesSync(await ContentSeal.seal(plainPack, key: kc));
    File(glossaryPath)
        .writeAsBytesSync(await ContentSeal.seal(plainGlossary, key: kc));

    final loader = ContentLoader(
      root: AssetRoot(
        glossaryPath: 'assets/content/glossary.json',
        packPath: 'test/fixtures/sample_pack.json',
        sealedGlossaryPath: glossaryPath,
        sealedPackPath: packPath,
      ),
      keys: InMemoryContentKeyVault(Uint8List.fromList(kc)),
    );
    final pack = await loader.loadPack();
    expect(pack.approvedQuestions, hasLength(1));
    expect((await loader.loadGlossary()).termCount, 444);
  });

  test('مفتاح خاطئ ⇒ فشل مبكر باستثناء الختم (لا نصف مفتوح)', () async {
    final kc = Uint8List.fromList(List<int>.generate(32, (i) => 5));
    final plain =
        File('${Directory.current.path}/test/fixtures/sample_pack.json')
            .readAsBytesSync();
    final packPath = tempFixture('bad_key_pack.sealed');
    File(packPath).writeAsBytesSync(await ContentSeal.seal(plain, key: kc));

    final wrong = InMemoryContentKeyVault(
        Uint8List.fromList(List<int>.generate(32, (i) => 6)));
    final loader = ContentLoader(
      root: AssetRoot(
        glossaryPath: 'assets/content/glossary.json',
        packPath: 'test/fixtures/sample_pack.json',
        sealedPackPath: packPath,
      ),
      keys: wrong,
    );
    await expectLater(loader.loadPack(), throwsA(isA<ContentSealException>()));
  });
}
