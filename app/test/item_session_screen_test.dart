// المادة ١٢ — شاشة التدريب على البنود المولّدة: الأنماط الأربعة + التصحيح
// الفوري بمحرك المادة ١١ + بوابة الاعتماد (F2.4) + مدخل بوابة التدريب.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/generated_items.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/features/training/item_session_screen.dart';
import 'package:fizya_clash/features/training/training_screen.dart';

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

    test('الأصل الحقيقي assets/content/items.json: ١٧ فصلاً كلها غير معتمدة',
        () {
      final raw = File('${Directory.current.path}/assets/content/items.json')
          .readAsStringSync();
      final real = GeneratedItemsPack.fromJsonString(raw);
      expect(real.items.length, greaterThanOrEqualTo(500));
      expect(real.visible(reviewMode: false), isEmpty); // قرار ٢٤
      // غير البرهان: أربعة خيارات دائماً؛ البرهان يحمل خطواته لا خيارات
      expect(
        real.items
            .where((i) => i.kind != ItemKind.proof)
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
  });

  group('الأنماط الأربعة', () {
    testWidgets('اختياري: اختيار خاطئ ⇒ الصحيح أخضر + سبب كل خيار + التالي',
        (tester) async {
      final item = ofKind(ItemKind.mcq);
      await pump(
          tester, ItemSessionScreen(items: [item, ofKind(ItemKind.numeric)]));
      expect(find.text(item.stem), findsOneWidget);
      expect(find.text('التالي ←'), findsNothing);
      final wrong = (item.correctIndex + 1) % 4;
      await tester.tap(find.text(item.options[wrong]));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.textContaining('لماذا كل خيار'), findsOneWidget);
      expect(find.text('٠ / ١٠'), findsOneWidget);
      // لا اختيار ثانٍ بعد التصحيح
      await tester.tap(find.text(item.options[item.correctIndex]));
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
    testWidgets('لا بنود معتمدة ⇒ رسالة الانتظار (قرار ٢٤)', (tester) async {
      await pump(tester, const ItemSessionScreen(items: []));
      expect(find.textContaining('بانتظار مصادقة الأستاذ'), findsOneWidget);
    });

    testWidgets('النتيجة النهائية تجمع الدرجات', (tester) async {
      final item = ofKind(ItemKind.mcq);
      await pump(tester, ItemSessionScreen(items: [item]));
      await tester.tap(find.text(item.options[item.correctIndex]));
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
