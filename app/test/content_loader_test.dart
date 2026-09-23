import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // ByteData/Uint8List — بعد إزالة flutter/services (جولة تحليل المالك)

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
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

  test('الحزمة الحقيقية v2 (التأليف من الكتاب + الأستاذ): ٥ وحدات · ١٧ درساً · نظيفة لفظياً · محجوبة عن الأستاذ', () async {
    const realRoot = AssetRoot(
      glossaryPath: 'assets/content/glossary.json',
      packPath: 'assets/content/pack.json',
    );
    final realLoader = ContentLoader(root: realRoot);
    final pack = await realLoader.loadPack();

    expect(pack.packId, 'syria-2027-v2');
    expect(pack.edition, 2);

    // خريطة الوحدات بحسب فهرس الكتاب الرسمي (docs/20)
    expect(pack.units.map((u) => u.id), ['U1', 'U2', 'U3', 'U4', 'U5']);
    expect(pack.units.map((u) => u.chapters.length), [5, 6, 2, 3, 1]);
    expect(pack.units[0].title, 'الوحدة الأولى: الحركة والتحريك');
    expect(pack.units[1].title, 'الوحدة الثانية: الكهرباء والمغناطيسية');
    expect(pack.units[2].title, 'الوحدة الثالثة: الأمواج المستقرة');
    expect(pack.units[3].title, 'الوحدة الرابعة: الإلكترونيات والجسم الصلب');
    expect(pack.units[4].title, contains('الفلكية'));

    // صفحات الكتاب تصاعدية عبر الحزمة كلها
    final pages = [
      for (final u in pack.units)
        for (final c in u.chapters) c.page,
    ];
    expect(pages.first, 6);
    expect(pages.last, 254);
    for (var i = 1; i < pages.length; i++) {
      expect(pages[i], greaterThan(pages[i - 1]), reason: 'ترتيب الصفحات');
    }

    // كل درس: مقدمة للطالب (P0) + أقسام القالب (🔑 📖 🧮 ✍️ 🎯 🧾 ⚖️)
    for (final u in pack.units) {
      for (final c in u.chapters) {
        expect(c.paragraphs.length, greaterThanOrEqualTo(8), reason: c.id);
        expect(c.paragraphs.first.id, '${c.id}P0');
        final summaries = c.paragraphs.map((p) => p.summary).join('\n');
        expect(summaries, contains('🔑'), reason: c.id);
        expect(summaries, contains('🧾'), reason: c.id);
        expect(summaries, contains('⚖️'), reason: c.id);
        for (final p in c.paragraphs) {
          expect(p.text, isNotEmpty);
          expect(p.text, isNot(contains('**')), reason: '${p.id} بقايا Markdown');
        }
      }
    }

    // رموز الكتاب حرفياً (قرار ١٤) — عيّنات من الوحدات الأربع الامتحانية
    String textOf(String chapterId) => pack.units
        .expand((u) => u.chapters)
        .firstWhere((c) => c.id == chapterId)
        .paragraphs
        .map((p) => p.text)
        .join('\n');
    expect(textOf('U1C1'), contains('T0 = 2π'));
    expect(textOf('U2C4'), contains('T0 = 2π·√(LC)'));
    expect(textOf('U2C5'), contains('P = Ueff·Ieff·cos φ'));
    expect(textOf('U3C1'), contains('v = √(FT/μ)'));
    expect(textOf('U3C2'), contains('f = (2n−1)·v/(4L)'));
    expect(textOf('U4C3'), contains('h·f = Ws + ½·me·v²max'));

    // اعتماد وزاري (dev/self-content): كل الأسئلة مبنيّة من المنهاج الوزاري
    // وأسئلة الدورات وسلالم التصحيح ⇒ معتمدة (لا بوابة أستاذ). راجع BRANCHING.md.
    expect(pack.questions.length, greaterThanOrEqualTo(60));
    expect(pack.approvedQuestions.length, pack.questions.length);
    for (final q in pack.questions) {
      expect(q.options, hasLength(4), reason: 'Q${q.id}');
      expect(q.correctIndex, inInclusiveRange(0, 3), reason: 'Q${q.id}');
      expect(q.stem, isNotEmpty);
    }
    // كل درس له أسئلة وبطاقات
    for (final u in pack.units) {
      for (final c in u.chapters) {
        expect(pack.questions.where((q) => q.chapter == c.id), isNotEmpty, reason: c.id);
        expect(pack.cards.where((k) => k.chapter == c.id), isNotEmpty, reason: c.id);
      }
    }
    expect(pack.cards.length, greaterThanOrEqualTo(150));

    // نظافة لفظية على القاموس الحقيقي 444/30
    expect(await realLoader.lintLoadedPack(), isEmpty);
  });


  test('فحص السلامة يرفض حزمة فاسدة (سؤال بفصل غير معروف)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
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
