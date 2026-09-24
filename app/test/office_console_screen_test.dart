// خطوة ٢ — أداة توليد الأكواد المستقلّة: بوابة المفتاح + التوليد.
// بلا شبكة: OfficeApi وهمي وخزنة بالذاكرة (نفس نمط admin_pos_screen_test).
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

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  testWidgets('بلا مفتاح: تظهر بوابة الإدخال ثم الدخول يفتح الكونسول',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(OfficeConsoleScreen(
      api: api,
      vault: _FakeVault(null),
    )));
    await tester.pumpAndSettle();

    expect(find.text('حفظ ودخول'), findsOneWidget);
    expect(find.text('توليد ونسخ / واتساب'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'OFFICE-KEY-123');
    await tester.tap(find.text('حفظ ودخول'));
    await tester.pumpAndSettle();

    // بعد التحقّق تظهر الإحصاءات والكونسول
    expect(find.textContaining('صُدر: 7'), findsOneWidget);
    expect(find.text('توليد ونسخ / واتساب'), findsOneWidget);
  });

  testWidgets('مع مفتاح محفوظ: التوليد يستدعي generate ويعرض الأكواد',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(OfficeConsoleScreen(
      api: api,
      vault: _FakeVault('SAVED-KEY'),
    )));
    await tester.pumpAndSettle();

    // الكونسول مباشرة (لا بوابة)
    expect(find.text('توليد ونسخ / واتساب'), findsOneWidget);

    // العدد = 3
    await tester.enterText(
        find.widgetWithText(TextField, 'العدد (١–١٠٠)'), '3');
    await tester.tap(find.text('توليد ونسخ / واتساب'));
    await tester.pumpAndSettle();

    expect(api.genCount, 1);
    expect(api.lastCount, 3);
    expect(find.text('أُصدرت 3 أكواد ✅'), findsOneWidget);
    expect(find.text('AAAAA-BBBBB-1000'), findsOneWidget);
  });

  testWidgets('العدد خارج المدى (0) يُرفض بلا استدعاء الخادم', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(OfficeConsoleScreen(
      api: api,
      vault: _FakeVault('SAVED-KEY'),
    )));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'العدد (١–١٠٠)'), '0');
    await tester.tap(find.text('توليد ونسخ / واتساب'));
    await tester.pumpAndSettle();

    expect(api.genCount, 0);
    expect(find.textContaining('العدد بين'), findsOneWidget); // سناك-بار
  });
}
