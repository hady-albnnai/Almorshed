import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/features/splash/animated_splash.dart';

void main() {
  // مسار «تقليل الحركة»: إطار ثابت نهائي بلا مؤقّت متكرّر ⇒ pumpAndSettle آمنة.
  testWidgets('الـsplash: يحترم تقليل الحركة ويعرض الاسم بلا تحريك',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: AnimatedSplash()),
      ),
    );
    // لا تحريك ⇒ يستقر فوراً.
    await tester.pumpAndSettle();
    expect(find.text('فيزيا كلاش'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  // المسار المتحرك: نستخدم pump (لا pumpAndSettle) لأن الدوران مستمر بالتصميم.
  testWidgets('الـsplash: المسار المتحرك يبني بلا أخطاء ويظهر الاسم',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AnimatedSplash()),
    );
    // إطار أولي ثم تقدّم زمني خلال المقدّمة (≤ 1 ثانية).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('فيزيا كلاش'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
