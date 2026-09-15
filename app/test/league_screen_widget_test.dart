// F4.6 — شاشة الدوري بواجهات مضخّة (ملف مستقل بلا شبكة — درس الـ400).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/supabase/league_api.dart';
import 'package:fizya_clash/features/league/league_screen.dart';

void main() {
  LeagueView makeView() => const LeagueView(isoWeek: 202637, groupNo: 1, rows: [
        LeagueRow(rank: 1, xp: 300, isMe: false),
        LeagueRow(rank: 2, xp: 220, isMe: true),
        LeagueRow(rank: 3, xp: 190, isMe: false),
      ], myRank: 2);

  Future<void> pumpView(WidgetTester tester, Future<LeagueView> Function() fetch) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LeagueScreen(fetch: fetch)));
    await tester.pumpAndSettle();
  }

  testWidgets('العرض الكامل: رأس الموسم + أنت 🎯 مميز + الميداليات',
      (tester) async {
    await pumpView(tester, () async => makeView());
    expect(find.textContaining('ترتيب تراكمي'), findsOneWidget); // رأس الموسم (قرار ٦٥)
    expect(find.text('أنت 🎯'), findsOneWidget);
    expect(find.text('المركز ١'), findsOneWidget);
    expect(find.text('المركز ٣'), findsOneWidget);
    expect(find.textContaining('٣٠٠ نقطة'), findsOneWidget);
    expect(find.textContaining('بلا مجموعات'), findsOneWidget); // ذيل الشرح (قرار ٦٥)
  });

  testWidgets('لا ترتيب بعد ⇒ رسالة البداية', (tester) async {
    await pumpView(tester,
        () async => const LeagueView(isoWeek: 0, groupNo: 0, rows: []));
    expect(find.textContaining('أول إقفال للأسبوع'), findsOneWidget);
  });

  testWidgets('فشل الشبكة ⇒ رسالة لطيفة + زر إعادة يعمل', (tester) async {
    var fail = true;
    await pumpView(tester, () async {
      if (fail) throw Exception('down');
      return makeView();
    });
    expect(find.textContaining('تعذر جلب الترتيب'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('أنت 🎯'), findsOneWidget);
  });
}
