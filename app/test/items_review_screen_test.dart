// المادة ١٣ — فهرس مراجعة البنود المولّدة (جهاز الأستاذ): العدّاد، الفلاتر،
// الحكم السريع ⇒ ReviewNotesStore (kind 'g') ⇒ تقرير واتساب «بند…»،
// وفتح الجلسة على البند بعينه مع شارة «قيد المراجعة» وزر ✏️ في الشريط.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fizya_clash/core/content/generated_items.dart';
import 'package:fizya_clash/core/review/review_mode.dart';
import 'package:fizya_clash/features/review/items_review_screen.dart';
import 'package:fizya_clash/features/review/review_widgets.dart';

void main() {
  late GeneratedItemsPack pack;

  setUpAll(() {
    final raw = File('${Directory.current.path}/test/fixtures/items_sample.json')
        .readAsStringSync();
    pack = GeneratedItemsPack.fromJsonString(raw);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ReviewNotesStore> pump(WidgetTester tester,
      {bool reviewMode = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final notes = ReviewNotesStore();
    // كما في main.dart: النطاق فوق الـNavigator حتى تراه الشاشات المدفوعة
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ReviewScope(
        enabled: reviewMode,
        unapprovedQuestionIds: const {},
        notes: notes,
        child: child ?? const SizedBox.shrink(),
      ),
      home: ItemsReviewScreen(pack: pack, notes: notes),
    ));
    await tester.pumpAndSettle();
    return notes;
  }

  test('ReviewNote kind g ⇒ تسمية «بند» في التقرير', () {
    const n = ReviewNote(
      kind: 'g',
      itemId: '20001',
      verdict: ReviewVerdict.edit,
      text: 'الخيار ب غير دقيق',
      updatedMs: 0,
    );
    expect(n.label, 'بند20001');
    expect(n.key, 'g:20001');
    final r = formatReviewReport([n], now: DateTime(2026, 9, 20));
    expect(r, contains('• بند20001: الخيار ب غير دقيق'));
    expect(ReviewNote.fromJson(n.toJson()).label, 'بند20001');
  });

  testWidgets('العدّاد ٠ من ٥ + كل البنود معروضة + شريط المراجعة',
      (tester) async {
    await pump(tester);
    expect(find.text('٠ من ٥'), findsOneWidget);
    expect(find.text('المعروض: ٥ بند'), findsOneWidget);
    expect(find.textContaining('وضع المراجعة'), findsOneWidget);
    expect(find.byKey(const Key('item-row-20001')), findsOneWidget);
    expect(find.byKey(const Key('item-row-20301')), findsOneWidget);
  });

  testWidgets('فلتر النمط: برهان ⇒ بند واحد · غير المراجَع يخفي المحكوم',
      (tester) async {
    // حكم مسبق على البرهان (نفس SharedPreferences الوهمية للاختبار)
    await ReviewNotesStore().put(const ReviewNote(
      kind: 'g',
      itemId: '20301',
      verdict: ReviewVerdict.ok,
      updatedMs: 1,
    ));
    await pump(tester);
    expect(find.text('١ من ٥'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-proof')));
    await tester.pumpAndSettle();
    expect(find.text('المعروض: ١ بند'), findsOneWidget);
    expect(find.byKey(const Key('item-row-20301')), findsOneWidget);
    expect(find.byKey(const Key('item-row-20001')), findsNothing);
    expect(find.textContaining('صحيح'), findsOneWidget); // حكمه ظاهر بالصف

    // «غير المراجَع فقط» يخفي المحكوم
    await tester.tap(find.byKey(const Key('filter-unreviewed')));
    await tester.pumpAndSettle();
    expect(find.text('المعروض: ٠ بند'), findsOneWidget);
    expect(find.text('لا بنود بهذا الفلتر.'), findsOneWidget);
  });

  testWidgets('حكم سريع ✏️ من الصف ⇒ يُحفظ بمفتاح g ويرفع العدّاد',
      (tester) async {
    final notes = await pump(tester);
    await tester.tap(find.byKey(const Key('note-20052')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ملاحظة — بند20052'), findsOneWidget);
    await tester.tap(find.text('✏️ يحتاج تعديل'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الوحدة ثا لا s');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final saved = await notes.load();
    expect(saved.keys, contains('g:20052'));
    expect(saved['g:20052']!.verdict, ReviewVerdict.edit);
    expect(saved['g:20052']!.text, 'الوحدة ثا لا s');
    expect(find.text('١ من ٥'), findsOneWidget);
    expect(find.textContaining('يحتاج تعديل — الوحدة ثا لا s'), findsOneWidget);
  });

  testWidgets('نقرة الصف تفتح الجلسة على البند نفسه بشارة «قيد المراجعة» و✏️',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('item-row-20127')));
    await tester.pumpAndSettle();
    expect(find.text('بند ٣ من ٥'), findsOneWidget); // الثالث في العيّنة
    expect(find.byKey(const Key('why-text')), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsNothing); // 20127 معتمد بالعيّنة
    expect(find.byIcon(Icons.edit_note), findsOneWidget); // ✏️ الشريط العلوي

    // البند الخامس (99999) غير معتمد ⇒ الشارة تظهر
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('item-row-99999')));
    await tester.tap(find.byKey(const Key('item-row-99999')));
    await tester.pumpAndSettle();
    expect(find.text('بند ٥ من ٥'), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsOneWidget);
  });
}
