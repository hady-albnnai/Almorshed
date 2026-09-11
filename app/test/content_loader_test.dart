import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/content_loader.dart';

/// F2.2 — محمّل الحزمة: assets حقيقية (glossary.json القاموس الحقيقي
/// + sample_pack كحزمة مؤقتة حتى شحن الحزمة الكاملة في M2 اللاحق).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentLoader loader;

  setUpAll(() {
    // rootBundle بالاختبارات يقرأ الأصول المعلنة فقط — نخدم الملفات من القرص
    // مباشرة (نفس محتوى القرص، بلا تلويث pubspec بملفات الاختبار).
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final file = File('${Directory.current.path}/$key');
        return ByteData.view(
            Uint8List.fromList(utf8.encode(file.readAsStringSync())).buffer);
      },
    );

    // نوجّه pack.json إلى حزمة العينة (الحزمة الكاملة تُشحن من خط المحتوى لاحقاً)
    const root = AssetRoot(
      glossaryPath: 'assets/content/glossary.json',
      packPath: 'test/fixtures/sample_pack.json',
    );
    loader = ContentLoader(root: root);
  });

  test('القاموس الحقيقي يُحمَّل من assets: 444 · 30 BAN · مرادفا SYN', () async {
    final g = await loader.loadGlossary();
    expect(g.termCount, 444);
    expect(g.banned, hasLength(30));
    expect(g.synonyms['التردد'], 'التواتر');
  });

  test('الحزمة تُحمَّل وتجتاز فحص السلامة والذاكرة تُعاد بلا إعادة قراءة',
      () async {
    final p1 = await loader.loadPack();
    final p2 = await loader.loadPack();
    expect(identical(p1, p2), isTrue); // cache
    expect(p1.approvedQuestions, hasLength(1));
  });

  test('lintLoadedPack: عينة الحزمة نظيفة من قاموس الأستاذ الحقيقي', () async {
    final violations = await loader.lintLoadedPack();
    // sample_pack بُنيت بالرموز الحرفية — يجب أن تكون نظيفة تماماً
    expect(violations, isEmpty);
  });

  test('فحص السلامة يرفض حزمة فاسدة (سؤال بفصل غير معروف)', () async {
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (data) async {
        const fake = '''
{"packId":"bad","year":2027,"edition":1,
 "units":[{"id":"U1","title":"وحدة","chapters":[]}],
 "questions":[{"id":1,"unit":"U1","chapter":"U9X9","approved":true,
   "stem":"س","options":["أ","ب"],"correctIndex":0}],
 "cards":[]}''';
        return ByteData.view(
            Uint8List.fromList(utf8.encode(fake)).buffer);
      },
    );
    final badLoader = ContentLoader(
      root: const AssetRoot(
        glossaryPath: 'assets/content/glossary.json',
        packPath: 'assets/content/__bad__.json',
      ),
    );
    expect(
      () => badLoader.loadPack(),
      throwsA(isA<StateError>()),
    );
  });
}
