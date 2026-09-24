// خطوة ٢ — أداة توليد الأكواد المستقلّة: بوابة المفتاح + التوليد.
// بلا شبكة: OfficeApi وهمي وخزنة بالذاكرة (نفس نمط admin_pos_screen_test:
// مفاتيح Key + شاشة كبيرة كي تظهر اللوحة كلها بلا تمرير).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/office_api.dart';
import 'package:fizya_clash/features/office_tool/office_console_screen.dart';

class _FakeVault extends OfficeKeyVault {
  _FakeVault(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
  @override
  Future<void> clear() async => value = null;
}

class _FakeApi extends OfficeApi {
  _FakeApi() : super(baseUrl: 'http://invalid.local');
  int genCount = 0;
  int? lastCount;
  String? lastCustomer;

  @override
  Future<(OfficeStats, List<Subscriber>)> stats(String key) async => (
        const OfficeStats(
            issued: 7, activated: 3, revoked: 1, activeLicenses: 4),
        const <Subscriber>[],
      );

  @override
  Future<List<String>> generate(String key,
      {int count = 1, bool review = false, String? customer}) async {
    genCount++;
    lastCount = count;
    lastCustomer = customer;
    return [for (var i = 0; i < count; i++) 'AAAAA-BBBBB-${1000 + i}'];
  }
}

void main() {
  Future<void> pump(WidgetTester tester, OfficeConsoleScreen screen) async {
    // شاشة طويلة كي تظهر اللوحة كلها بلا تمرير (نمط admin_pos_screen_test).
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: screen),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('بلا مفتاح: تظهر بوابة الإدخال ثم الدخول يفتح الكونسول',
      (tester) async {
    final api = _FakeApi();
    await pump(
        tester, OfficeConsoleScreen(api: api, vault: _FakeVault(null)));

    expect(find.byKey(const Key('office-login')), findsOneWidget);
    expect(find.byKey(const Key('office-generate')), findsNothing);

    await tester.enterText(
        find.byKey(const Key('office-key-field')), 'OFFICE-KEY-123');
    await tester.tap(find.byKey(const Key('office-login')));
    await tester.pumpAndSettle();

    // بعد التحقّق يظهر الكونسول والإحصاءات
    expect(find.byKey(const Key('office-generate')), findsOneWidget);
    expect(find.textContaining('صُدر: 7'), findsOneWidget);
  });

  testWidgets('مع مفتاح محفوظ: التوليد يستدعي generate ويعرض الأكواد',
      (tester) async {
    final api = _FakeApi();
    await pump(
        tester, OfficeConsoleScreen(api: api, vault: _FakeVault('SAVED-KEY')));

    expect(find.byKey(const Key('office-generate')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('office-count')), '3');
    await tester.tap(find.byKey(const Key('office-generate')));
    await tester.pumpAndSettle();

    expect(api.genCount, 1);
    expect(api.lastCount, 3);
    expect(find.text('AAAAA-BBBBB-1000'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('العدد خارج المدى (0) يُرفض بلا استدعاء الخادم', (tester) async {
    final api = _FakeApi();
    await pump(
        tester, OfficeConsoleScreen(api: api, vault: _FakeVault('SAVED-KEY')));

    await tester.enterText(find.byKey(const Key('office-count')), '0');
    await tester.tap(find.byKey(const Key('office-generate')));
    await tester.pump(); // بناء
    await tester.pump(const Duration(milliseconds: 400)); // ظهور السناك-بار

    expect(api.genCount, 0);
    expect(find.textContaining('العدد بين'), findsOneWidget);
  });
}
