import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/main.dart';

void main() {
  testWidgets('F0.2 smoke — الهوية تظهر والتبديل يعمل', (tester) async {
    await tester.pumpWidget(const FizyaClashApp());

    // قرار ٤٦: الاسم والعنوان الفرعي
    expect(find.text('فيزيا كلاش'), findsOneWidget);
    expect(find.text('Clash of Physics · منهاج الثالث الثانوي العلمي'),
        findsOneWidget);

    // قرار ٤٧: الداكن أولاً — والتبديل للفاتح يعمل
    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
    expect(find.text('أول بناء ناجح ✓'), findsOneWidget);
  });
}
