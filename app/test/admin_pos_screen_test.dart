// F6.1-POS — نقطة البيع داخل لوحة الإدارة المخفية (قرار ٣٤):
// بيع باسم الطالب ⇒ كود واحد لحظي ⇒ بطاقة تسليم؛ بحث بالكود/الاسم؛
// اسم الزبون على الصف. كله بلا شبكة: OfficeApi وهمي وخزنة بالذاكرة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fizya_clash/core/supabase/office_api.dart';
import 'package:fizya_clash/features/admin/admin_screen.dart';

class _FakeVault extends OfficeKeyVault {
  String? value = 'K';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
  @override
  Future<void> clear() async => value = null;
}

class _FakeApi extends OfficeApi {
  _FakeApi() : super(baseUrl: 'http://invalid.local');
  final List<Map<String, dynamic>> rows = [
    {
      'code': 'AAAAA-BBBBB-CCCCC',
      'status': 'activated',
      'distributor': 'مكتب لورانيم',
      'devices_used': 1,
      'customer': 'سارة محمود',
    },
    {
      'code': 'DDDDD-EEEEE-FFFFF',
      'status': 'activated',
      'distributor': 'مكتب لورانيم',
      'devices_used': 2,
    },
  ];
  String? lastCustomer;
  int genCount = 0;

  @override
  Future<(OfficeStats, List<Subscriber>)> stats(String key) async => (
        OfficeStats(
          issued: 0,
          activated: rows.length,
          revoked: 0,
          activeLicenses: 3,
        ),
        [for (final r in rows) Subscriber.fromJson(r)],
      );

  @override
  Future<List<String>> generate(
    String key, {
    int count = 1,
    bool review = false,
    String? customer,
  }) async {
    genCount += count;
    lastCustomer = customer;
    rows.insert(0, {
      'code': 'NEW11-NEW22-NEW33',
      'status': 'issued',
      'distributor': 'مكتب لورانيم',
      'devices_used': 0,
      'customer': customer,
    });
    return ['NEW11-NEW22-NEW33'];
  }

  @override
  Future<void> note(String key, String code, String customer) async {
    for (final r in rows) {
      if (r['code'] == code) r['customer'] = customer;
    }
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeApi> pump(WidgetTester tester) async {
    // شاشة طويلة كي تظهر اللوحة كلها بلا تمرير (هاتف بارتفاع كبير)
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final api = _FakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AdminScreen(api: api, vault: _FakeVault()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  test('Subscriber.matches: بالكود بلا شرطات وبالاسم', () {
    final s = Subscriber.fromJson(const {
      'code': 'AAAAA-BBBBB-CCCCC',
      'status': 'activated',
      'customer': 'سارة محمود',
    });
    expect(s.matches(''), isTrue);
    expect(s.matches('bbbbbc'), isTrue);
    expect(s.matches('سارة'), isTrue);
    expect(s.matches('ZZZ'), isFalse);
    expect(Subscriber.fromJson(const {'customer': '  '}).customer, isNull);
  });

  test('رسالة التسليم تحوي الاسم والكود وقاعدة الجهازين', () {
    final m = _AdminMsg.of('K7M2P-9QW4X-ABCDE', 'أحمد');
    expect(m, contains('أحمد'));
    expect(m, contains('K7M2P-9QW4X-ABCDE'));
    expect(m, contains('جهازين'));
  });

  testWidgets('اللوحة تعرض اسم الزبون و«بلا اسم» لمن لا اسم له', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('إدارة المكتب 🗂'), findsOneWidget);
    expect(find.textContaining('سارة محمود'), findsOneWidget);
    expect(find.textContaining('بلا اسم'), findsOneWidget);
  });

  testWidgets('البحث بالاسم يصفّي الصفوف', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('pos_search')), 'سارة');
    await tester.pumpAndSettle();
    expect(find.textContaining('AAAAA-BBBBB-CCCCC'), findsOneWidget);
    expect(find.textContaining('DDDDD-EEEEE-FFFFF'), findsNothing);
  });

  testWidgets('بيع اشتراك: اسم ⇒ كود واحد باسمه ⇒ بطاقة التسليم', (
    tester,
  ) async {
    final api = await pump(tester);
    await tester.tap(find.byKey(const Key('pos_sell')));
    await tester.pumpAndSettle();
    expect(find.text('بيع اشتراك 🧾'), findsOneWidget);
    // اسم فارغ ⇒ لا إصدار
    await tester.tap(find.text('إصدار الكود'));
    await tester.pumpAndSettle();
    expect(api.genCount, 0);

    await tester.tap(find.byKey(const Key('pos_sell')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'أحمد خالد');
    await tester.tap(find.text('إصدار الكود'));
    await tester.pumpAndSettle();
    expect(api.genCount, 1);
    expect(api.lastCustomer, 'أحمد خالد');
    expect(find.text('تم الإصدار ✅'), findsOneWidget);
    expect(find.text('NEW11-NEW22-NEW33'), findsOneWidget);
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();
    // الصف الجديد يظهر باسمه بعد التحديث (فلتر «مشتركون» يخفيه — نختار الكل)
    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أحمد خالد'), findsOneWidget);
  });
}

/// وصول إلى الرسالة الثابتة عبر الحالة العامة.
class _AdminMsg {
  static String of(String code, String customer) =>
      AdminSaleMessage.build(code, customer);
}
