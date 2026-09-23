// المادة ١٢ — شاشة التدريب على البنود المولّدة: الأنماط الأربعة + التصحيح
// الفوري بمحرك المادة ١١ + بوابة الاعتماد (F2.4) + مدخل بوابة التدريب.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/generated_items.dart';
import 'package:fizya_clash/core/content/math_text.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/features/training/item_session_screen.dart';
import 'package:fizya_clash/features/training/training_screen.dart';

import 'fixtures/parts_item.dart';

void main() {
  late GeneratedItemsPack pack;

  setUpAll(() {
    final raw =
        File('${Directory.current.path}/test/fixtures/items_sample.json')
            .readAsStringSync();
    pack = GeneratedItemsPack.fromJsonString(raw);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  GeneratedItem ofKind(ItemKind k) => pack.items.firstWhere((i) => i.kind == k);

  group('النموذج', () {
    test('يقرأ العيّنة: الأنماط الأربعة + فلتر الاعتماد (F2.4)', () {
      expect(pack.items, hasLength(5));
      expect(pack.items.map((i) => i.kind).toSet(), ItemKind.values.toSet());
      expect(pack.visible(reviewMode: false), hasLength(4));
      expect(pack.visible(reviewMode: true), hasLength(5));
      expect(ofKind(ItemKind.numeric).numericAnswer!.unit, 's');
      expect(ofKind(ItemKind.proof).proofSteps, hasLength(8));
    });

    test('الأصل الحقيقي assets/content/items.json: ١٧ فصلاً باعتماد وزاري', () {
      final raw = File('${Directory.current.path}/assets/content/items.json')
          .readAsStringSync();
      final real = GeneratedItemsPack.fromJsonString(raw);
      expect(real.items.length, greaterThanOrEqualTo(500));
      // dev/self-content: كل البنود مبنيّة من الدورات وسلالم التصحيح ⇒ معتمدة.
      expect(real.visible(reviewMode: false), hasLength(real.items.length));
      // غير البرهان وغير الأجزاء: أربعة خيارات دائماً؛ البرهان يحمل خطواته لا
      // خيارات، وبنود الأجزاء تحمل مفاتيحها في أجزائها لا في مفتاح مسطّح.
      expect(
        real.items
            .where((i) => i.kind != ItemKind.proof && !i.isParts)
            .every((i) => i.options.length == 4),
        isTrue,
      );
      expect(real.items.where((i) => i.kind == ItemKind.proof), isNotEmpty);
      final chapters = real.items.map((i) => i.chapter).toSet();
      expect(chapters, hasLength(17));
      expect(chapters, containsAll(chapterTitles.keys));
      // كل فصل له اسم عربي معروف (لا يظهر المعرّف الخام في الواجهة)
      for (final c in chapters) {
        expect(chapterTitleOf(c), isNot(c));
      }
      // الأنماط الأربعة كلها حاضرة
      final modes = real.items.map(answerModeOf).toSet();
      expect(
        modes,
        containsAll([ItemKind.mcq, ItemKind.numeric, ItemKind.why]),
      );
    });

    test('الأصل الحقيقي: بنود الأجزاء (F-GEN3) مكتملة البنية باعتماد وزاري',
        () {
      final raw = File('${Directory.current.path}/assets/content/items.json')
          .readAsStringSync();
      final real = GeneratedItemsPack.fromJsonString(raw);
      final parts = real.items.where((i) => i.isParts).toList();
      expect(parts.length, greaterThanOrEqualTo(2));
      // dev/self-content: كل البنود معتمدة وزارياً ⇒ كلها مرئية.
      expect(real.visible(reviewMode: false), hasLength(real.items.length));
      for (final i in parts) {
        expect(i.options, isEmpty);
        expect(i.correctIndex, -1);
        expect(i.parts.length, greaterThanOrEqualTo(2));
        expect(i.weight, i.partsWeight); // وزن البند = مجموع أوزان أجزائه
        for (final q in i.parts) {
          final sum = q.rubric.fold<double>(0, (s, e) => s + e.points);
          expect(q.weight, sum); // وزن الجزء = مجموع أسطره
          for (final e in q.rubric) {
            expect(
              e.kind,
              anyOf('relation', 'substitution', 'result', 'unit'),
              reason: e.step,
            );
            expect(e.points, greaterThan(0));
          }
          if (q.hasOptions) expect(q.options, hasLength(4));
        }
      }
    });

    test('بند أجزاء: لا مفتاح مسطّح له ونمطه الرقمي للمرشّحات فقط', () {
      final i = GeneratedItem.fromJson(partsSampleItem());
      expect(i.isParts, isTrue);
      expect(answerModeOf(i), ItemKind.numeric);
      expect(i.numericAnswer, isNull);
    });
  });

  group('المسألة بأجزاء (F-GEN3)', () {
    GeneratedItem partsItem() => GeneratedItem.fromJson(partsSampleItem());

    testWidgets('حقول الأسطر الثلاثة لكل جزء + شارة «مسألة بأجزاء»',
        (tester) async {
      await pump(tester, ItemSessionScreen(items: [partsItem()]));
      expect(find.textContaining('مسألة بأجزاء'), findsOneWidget);
      for (final k in ['rel', 'sub', 'res']) {
        for (final n in [1, 2]) {
          expect(find.byKey(Key('parts-$k-$n')), findsOneWidget);
        }
      }
      expect(find.text('تسليم المسألة'), findsOneWidget);
      // خيارات الجزء الأول موجودة (وضع القرار ٦١ المؤقَّت) وبلا كشف للإجابة
      // العزل يعمل فعلياً: المعروَّد يحمل علامتَي FSI/PDI حول Ω فلا يطابقه الخام
      expect(find.text(isolateMath('100 Ω')), findsOneWidget);
      expect(find.byType(MathText), findsWidgets);
    });

    testWidgets('إجابة كاملة على جزءين ⇒ ٢٠/٢٠ وبطاقة سطرًا سطرًا',
        (tester) async {
      await pump(tester, ItemSessionScreen(items: [partsItem()]));
      await tester.enterText(find.byKey(const Key('parts-rel-1')), fullRelation1);
      await tester.enterText(
          find.byKey(const Key('parts-sub-1')), fullSubst1);
      await tester.enterText(find.byKey(const Key('parts-res-1')), fullResult1);
      await tester.enterText(find.byKey(const Key('parts-rel-2')), fullRelation2);
      await tester.enterText(
          find.byKey(const Key('parts-sub-2')), fullSubst2);
      await tester.enterText(find.byKey(const Key('parts-res-2')), fullResult2);
      await tester.ensureVisible(find.byKey(const Key('parts-submit')));
      await tester.tap(find.byKey(const Key('parts-submit')));
      await tester.pumpAndSettle();
      expect(find.text('٢٠ / ٢٠'), findsOneWidget);
      expect(find.text('سلّم التصحيح'), findsOneWidget);
      expect(find.textContaining('الجزء ١'), findsWidgets);
      // نصّ السلم الحرفيّ يُسرد تحت سطره (مؤجّل §٦.٦-4 — منفَّذ)
      expect(find.text(isolateMath('الجزء ١ · العلاقة: Z = √(R² + X²)')),
          findsOneWidget);
      expect(
          find.text(isolateMath('الجزء ٢ · الوحدة (مقدار بلا بُعد)')),
          findsOneWidget);
      expect(find.textContaining('لم تُكتب'), findsNothing);
      // الحقول تُقفل بعد التسليم ويُبدَّل زرّ التسليم
      expect(find.text('تم التصحيح'), findsOneWidget);
      expect(find.text('متابعة للخطأ'), findsNothing);
      expect(find.textContaining('ملخّص الأجزاء'), findsOneWidget);
    });

    testWidgets('متابعة الخطأ: خيار خاطئ في ١ ونتيجة مبنية عليه في ٢ ⇒ FT',
        (tester) async {
      await pump(tester, ItemSessionScreen(items: [partsItem()]));
      await tester.tap(find.text('140')); // الجزء ١ — مشتت الجمع الجبري
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('parts-res-2')), '0.428571');
      await tester.ensureVisible(find.byKey(const Key('parts-submit')));
      await tester.tap(find.byKey(const Key('parts-submit')));
      await tester.pumpAndSettle();
      expect(find.text('٢ / ٢٠'), findsOneWidget);
      expect(find.textContaining('متابعة للخطأ (FT)'), findsWidgets);
      expect(find.text('FT'), findsOneWidget);
    });

    testWidgets('خيار خاطئ في جزء بخيارات ⇒ الصحيح أخضر والمختار أحمر',
        (tester) async {
      await pump(tester, ItemSessionScreen(items: [partsItem()]));
      await tester.tap(find.text('140'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('parts-submit')));
      await tester.tap(find.byKey(const Key('parts-submit')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.text('٠ / ٢٠'), findsOneWidget);
    });
  });

  group('الأنماط الأربعة', () {
    testWidgets('اختياري: اختيار خاطئ ⇒ الصحيح أخضر + سبب كل خيار + التالي',
        (tester) async {
      final item = ofKind(ItemKind.mcq);
      await pump(
          tester, ItemSessionScreen(items: [item, ofKind(ItemKind.numeric)]));
      expect(find.text(isolateMath(item.stem)), findsOneWidget);
      expect(find.text('التالي ←'), findsNothing);
      final wrong = (item.correctIndex + 1) % 4;
      await tester.tap(find.text(isolateMath(item.options[wrong])));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.textContaining('لماذا كل خيار'), findsOneWidget);
      expect(find.text('٠ / ١٠'), findsOneWidget);
      // لا اختيار ثانٍ بعد التصحيح
      await tester.tap(find.text(isolateMath(item.options[item.correctIndex])));
      await tester.pumpAndSettle();
      expect(find.text('٠ / ١٠'), findsOneWidget);
      await tester.tap(find.text('التالي ←'));
      await tester.pumpAndSettle();
      expect(find.textContaining('بند ٢ من ٢'), findsOneWidget);
    });

    testWidgets('رقمي: قيمة صحيحة بلا وحدة ⇒ ٩/١٠ وملاحظة «الوحدة ناقصة»',
        (tester) async {
      final item = ofKind(ItemKind.numeric); // المفتاح 5 s
      await pump(tester, ItemSessionScreen(items: [item]));
      await tester.enterText(find.byKey(const Key('numeric-value')), '5');
      await tester.tap(find.byKey(const Key('numeric-submit')));
      await tester.pumpAndSettle();
      expect(find.text('٩ / ١٠'), findsOneWidget);
      expect(find.textContaining('الوحدة ناقصة'), findsOneWidget);
      expect(find.text('النتيجة'), findsOneWidget);
    });

    testWidgets('رقمي: أرقام عربية-هندية + وحدة عربية ⇒ كامل', (tester) async {
      final item = ofKind(ItemKind.numeric);
      await pump(tester, ItemSessionScreen(items: [item]));
      await tester.enterText(find.byKey(const Key('numeric-value')), '٥');
      await tester.enterText(find.byKey(const Key('numeric-unit')), 'ثا');
      await tester.tap(find.byKey(const Key('numeric-submit')));
      await tester.pumpAndSettle();
      expect(find.text('١٠ / ١٠'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets(
        'علّل: مفتاح مضاد ⇒ صفر مع «تعليل مغلوط» · مفتاحان من ثلاثة ⇒ جزئي',
        (tester) async {
      final item = ofKind(ItemKind.why);
      final twin =
          GeneratedItem.fromJson(<String, dynamic>{...item.raw, 'id': 777});
      await pump(tester, ItemSessionScreen(items: [item, twin]));
      await tester.enterText(
          find.byKey(const Key('why-text')), 'لأن السرعة عظمى هناك');
      await tester.tap(find.byKey(const Key('why-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعليل مغلوط'), findsOneWidget);
      expect(find.text('٠ / ١٠'), findsOneWidget);
      await tester.tap(find.text('التالي ←'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('why-text')),
          'لأنَّ المطالَ أعظميٌّ وقوّة الإرجاع عظمى');
      await tester.tap(find.byKey(const Key('why-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ناقص'), findsOneWidget);
      expect(find.text('٦٫٧ / ١٠'), findsOneWidget);
    });

    testWidgets('برهان: ترتيب صحيح مع إعلان «بلا إشارة» ⇒ ٢١/٢٥ وملاحظة −٤',
        (tester) async {
      final item = ofKind(ItemKind.proof);
      await pump(tester, ItemSessionScreen(items: [item]));
      expect(find.byKey(const Key('proof-submit')), findsOneWidget);
      for (var n = 1; n <= 8; n++) {
        await tester.ensureVisible(find.byKey(Key('proof-step-$n')));
        await tester.tap(find.byKey(Key('proof-step-$n')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('flag-4-missing_minus')));
      await tester.tap(find.byKey(const Key('flag-4-missing_minus')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('proof-submit')));
      await tester.tap(find.byKey(const Key('proof-submit')));
      await tester.pumpAndSettle();
      expect(find.text('٢١ / ٢٥'), findsOneWidget);
      expect(find.textContaining('الإشارة السالبة'), findsWidgets);
    });
  });

  group('الجلسة والبوابة', () {
    testWidgets('لا بنود ⇒ رسالة حالة فارغة محايدة (dev/self-content)',
        (tester) async {
      await pump(tester, const ItemSessionScreen(items: []));
      expect(find.textContaining('لا بنود متاحة'), findsOneWidget);
      expect(find.textContaining('مصادقة الأستاذ'), findsNothing);
    });

    testWidgets('النتيجة النهائية تجمع الدرجات', (tester) async {
      final item = ofKind(ItemKind.mcq);
      await pump(tester, ItemSessionScreen(items: [item]));
      await tester.tap(find.text(isolateMath(item.options[item.correctIndex])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('النتيجة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('١٠ من ١٠ درجة'), findsOneWidget);
    });

    testWidgets('بوابة التدريب تفتح جلسة البنود من المحمّل المحقون',
        (tester) async {
      final pack0 = ContentPack.fromJsonString(
          '{"packId":"t","year":2027,"edition":1,"units":[],"questions":[]}');
      await pump(
        tester,
        TrainingScreen(
          pack: pack0,
          trainingStore: InMemoryTrainingStore(),
          loadItems: () async => pack,
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('items-u1')));
      await tester.tap(find.byKey(const Key('items-u1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('بند ١ من ٤'), findsOneWidget); // المعتمد فقط
    });
  });
}
