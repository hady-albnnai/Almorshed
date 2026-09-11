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

  test('الحزمة الحقيقية (التأليف): U1C1 النواسات — سليمة ونظيفة لفظياً ومحجوبة عن الأستاذ', () async {
    const realRoot = AssetRoot(
      glossaryPath: 'assets/content/glossary.json',
      packPath: 'assets/content/pack.json',
    );
    final realLoader = ContentLoader(root: realRoot);
    final pack = await realLoader.loadPack();

    expect(pack.units.first.id, 'U1');
    expect(pack.units.first.title, 'الوحدة الأولى: النواسات');
    final c1 = pack.units.first.chapters.first;
    expect(c1.id, 'U1C1');
    expect(c1.title, 'الاهتزازات التوافقية البسيطة: النواس المرن غير المتخامد');
    expect(c1.paragraphs, hasLength(6));
    // الرموز حرفياً من الكتاب (قرار ١٤)
    expect(c1.paragraphs[1].text, contains('F = -kx'));
    expect(c1.paragraphs[4].text, contains('T0 = 2π·√(m/k)'));

    // بوابة الأستاذ: لا سؤال مؤلَّف يُفتح قبل مصادقته (قرار ٢٤)
    expect(pack.questions, hasLength(9));
    expect(pack.approvedQuestions, isEmpty);

    // الفصل الثاني: التوابع الزمنية الثلاثة
    final c2 = pack.units.first.chapters[1];
    expect(c2.id, 'U1C2');
    expect(c2.paragraphs, hasLength(6));
    expect(c2.paragraphs[4].text, contains('a = −ω0²·x'));
    expect(pack.questions.where((q) => q.chapter == 'U1C2'), hasLength(3));

    // الفصل الثالث: الطاقة الكلية
    final c3 = pack.units.first.chapters[2];
    expect(c3.id, 'U1C3');
    expect(c3.paragraphs, hasLength(3));
    expect(c3.paragraphs[0].text, contains('E = ½k·XmaX²'));
    expect(pack.questions.where((q) => q.chapter == 'U1C3'), hasLength(2));

    // نظافة لفظية على القاموس الحقيقي 444/30
    expect(await realLoader.lintLoadedPack(), isEmpty);
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
