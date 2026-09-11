import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/tts/speaker.dart';
import 'package:fizya_clash/features/curriculum/lesson_screen.dart';
import 'package:fizya_clash/main.dart';

/// حزمة اختبار مصغّرة: وحدة بفصل من فقرتين + وحدة فارغة.
ContentPack _fakePack() => ContentPack.fromJsonString(jsonEncode({
      'packId': 'test-pack',
      'year': 2027,
      'edition': 1,
      'units': [
        {
          'id': 'U1',
          'title': 'الحركة والتحريك',
          'chapters': [
            {
              'id': 'U1C1',
              'title': 'الحركة التوافقية البسيطة',
              'page': 6,
              'paragraphs': [
                {
                  'id': 'P1',
                  'text': 'نص الفقرة الأولى كاملاً للقراءة.',
                  'summary': 'خلاصة الفقرة الأولى'
                },
                {
                  'id': 'P2',
                  'text': 'نص الفقرة الثانية للقراءة.',
                  'summary': 'خلاصة الفقرة الثانية'
                }
              ]
            }
          ]
        },
        {
          'id': 'U2',
          'title': 'الكهرباء والمغناطيسية',
          'chapters': []
        }
      ],
      'questions': [],
      'cards': []
    }));

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // سطح اختبار بمقاس هاتف فعلي — يمنع مشاكل off-screen بالمسار الكامل
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        FizyaClashApp(packLoader: () async => _fakePack()));
    await tester.pumpAndSettle();
  }

  testWidgets('المنهاج: العنوان + الوحدتان + الوضع الفاتح/الداكن', (tester) async {
    await pumpApp(tester);

    expect(find.text('فيزيا كلاش'), findsOneWidget);
    expect(find.text('الوحدات الخمس'), findsOneWidget);
    expect(find.text('١ · الحركة والتحريك'), findsOneWidget);
    expect(find.text('٢ · الكهرباء والمغناطيسية'), findsOneWidget);
    // الوحدة الفارغة: قيد الإعداد
    expect(find.text('قيد الإعداد — تصل مع تحديث المحتوى'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
    expect(find.text('الوحدات الخمس'), findsOneWidget);
  });

  testWidgets('مسار القراءة: وحدة ← فصل ← فقرتان + خلاصة + انتهى الدرس',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('١ · الحركة والتحريك'));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ القراءة'), findsOneWidget);

    await tester.tap(find.text('ابدأ القراءة'));
    await tester.pumpAndSettle();
    expect(find.text('نص الفقرة الأولى كاملاً للقراءة.'), findsOneWidget);
    expect(find.text('خلاصة الفقرة الأولى'), findsOneWidget);
    expect(find.text('فقرة ١ من ٢'), findsOneWidget);

    // الفهرس الحر: فتحه يظهر الفقرتين
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(find.text('الفقرة ٢ — خلاصة الفقرة الثانية'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    expect(find.text('نص الفقرة الثانية للقراءة.'), findsOneWidget);
    expect(find.text('فقرة ٢ من ٢'), findsOneWidget);

    await tester.tap(find.text('انتهى الدرس ✓'));
    await tester.pumpAndSettle();
    expect(find.text('أنهيت الفصل!'), findsOneWidget);
    expect(find.text('+١٠ نقطة لدوري فيزيا كلاش ✓'), findsOneWidget);
  });

  testWidgets('اسمعني: يظهر مع محرك عربي وينطق الفقرة', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final speaker = _FakeSpeaker(available: true);
    final chapter = _fakePack().units.first.chapters.first;

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LessonScreen(chapter: chapter, speaker: speaker),
      ),
    ));
    await tester.pumpAndSettle(); // إتاحة المحرك غير متزامنة

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_outlined));
    await tester.pumpAndSettle();
    expect(speaker.spoken, ['نص الفقرة الأولى كاملاً للقراءة.']);
  });

  testWidgets('اسمعني: يختفي كلياً بلا محرك عربي (قرار F3.2)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final chapter = _fakePack().units.first.chapters.first;

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child:
            LessonScreen(chapter: chapter, speaker: _FakeSpeaker(available: false)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    // والفهرس باقٍ — الاختفاء خاص بزر النطق فقط
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });
}

/// زائف النطق — يسجل ما طُلب نطقه (نمط الحقن نفسه).
class _FakeSpeaker implements Speaker {
  _FakeSpeaker({required this.available});

  final bool available;
  final List<String> spoken = [];

  @override
  Future<bool> hasArabicEngine() async => available;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
