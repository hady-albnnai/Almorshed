// F6.6 — إدارة الموسم في لوحة المكتب: عرض حالة الموسم + ضبط/مسح ends_on.
// بلا شبكة: OfficeApi وهمي يخزّن الحالة بالذاكرة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fizya_clash/core/cert/certificate.dart' show currentSeason;
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
  _FakeApi({this.endsOn}) : super(baseUrl: 'http://invalid.local');

  String? endsOn; // حالة الموسم بالذاكرة
  String? lastSet; // آخر قيمة أُرسلت لـ setSeasonEnd ('null' = مسح)

  @override
  Future<(OfficeStats, List<Subscriber>)> stats(String key) async => (
        const OfficeStats(issued: 0, activated: 0, revoked: 0, activeLicenses: 0),
        const <Subscriber>[],
      );

  bool _closed(String? e) =>
      e != null && DateTime.parse(e).isBefore(DateTime.now());

  @override
  Future<SeasonInfo> seasonInfo(String key, String season) async => SeasonInfo(
        season: season,
        exists: endsOn != null,
        endsOn: endsOn,
        closed: _closed(endsOn),
      );

  @override
  Future<SeasonInfo> setSeasonEnd(String key, String season, String? e) async {
    lastSet = e ?? 'null';
    endsOn = e;
    return SeasonInfo(
        season: season, exists: true, endsOn: e, closed: _closed(e));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeApi> pump(WidgetTester tester, {String? endsOn}) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final api = _FakeApi(endsOn: endsOn);
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

  testWidgets('بطاقة الموسم تظهر بالموسم الحالي وحالة «مفتوح» حين لا نهاية',
      (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('season_card')), findsOneWidget);
    expect(find.textContaining('دوري الموسم ${currentSeason()}'), findsOneWidget);
    expect(find.textContaining('مفتوح'), findsOneWidget);
    // بلا نهاية ⇒ لا زر إعادة فتح، وزر التحديد بصيغة «تحديد».
    expect(find.byKey(const Key('season_reopen')), findsNothing);
    expect(find.text('تحديد نهاية الموسم'), findsOneWidget);
  });

  testWidgets('موسم مغلق (تاريخ ماضٍ) ⇒ «الشهادات متاحة» + زر إعادة الفتح',
      (tester) async {
    await pump(tester, endsOn: '2025-06-01');
    expect(find.textContaining('الشهادات متاحة'), findsOneWidget);
    expect(find.byKey(const Key('season_reopen')), findsOneWidget);
    expect(find.text('تعديل التاريخ'), findsOneWidget);
  });

  testWidgets('إعادة الفتح تستدعي setSeasonEnd(null) وتحدّث البطاقة',
      (tester) async {
    final api = await pump(tester, endsOn: '2025-06-01');
    await tester.tap(find.byKey(const Key('season_reopen')));
    await tester.pumpAndSettle();
    // حوار تأكيد → موافقة (زر إعادة الفتح داخل الحوار)
    await tester.tap(find.widgetWithText(FilledButton, 'إعادة الفتح'));
    await tester.pumpAndSettle();
    expect(api.lastSet, 'null');
    expect(find.textContaining('مفتوح'), findsOneWidget);
  });
}
