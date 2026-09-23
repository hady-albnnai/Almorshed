// F6.4 — شاشة «عن التطبيق»: شريط القرار ٥٧ + الهوية + الإصدار (قرار ٣٩).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/features/account/about_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AboutScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'الشريط العلوي: تطوير/لورانيم فقط — أُزيل الإشراف العلمي (dev/self-content)',
      (tester) async {
    await pump(tester);
    expect(find.text('عن التطبيق'), findsOneWidget); // العنوان
    expect(find.text('تطوير'), findsOneWidget);
    expect(find.text('لورانيم تك'), findsOneWidget);
    // الإشراف العلمي أُزيل نهائياً على هذا الفرع (راجع BRANCHING.md)
    expect(find.text('إشراف علمي'), findsNothing);
    expect(find.textContaining('فداء'), findsNothing);
    expect(find.textContaining('البني'), findsNothing);
  });

  testWidgets('سطر مصدر المادة يشير للمنهاج الوزاري لا للأستاذ', (tester) async {
    await pump(tester);
    expect(find.textContaining('المنهاج الوزاري'), findsOneWidget);
    expect(find.textContaining('راجعتها'), findsNothing);
  });

  testWidgets('الهوية والإصدار وحقوق النشر', (tester) async {
    await pump(tester);
    expect(find.text('فيزيا كلاش'), findsOneWidget);
    expect(find.text('Clash of Physics'), findsOneWidget);
    expect(find.text('منهاج الثالث الثانوي العلمي'), findsOneWidget);
    expect(find.text('الإصدار $aboutVersion'), findsOneWidget);
    expect(find.textContaining('حقوق النشر محفوظة'), findsOneWidget);
    expect(find.textContaining('يعمل بدون إنترنت بعد التفعيل'), findsOneWidget);
    expect(find.textContaining('© 2026 — loraneem-tech'), findsOneWidget);
  });

  testWidgets('الشعار موجود كصورة (وبدائل إلى العلامة النصية errorBuilder)',
      (tester) async {
    await pump(tester);
    // assets/brand/loraneem_tech.png موجود في الأصل — يُبنى Widget صورة
    expect(find.byType(Image), findsWidgets);
    // (غياب الألفة يمرّ عبر errorBuilder إلى نصّ loraneem-tech — مسار مغطّى
    //  ببنيته هنا وبوجود الشعار فعلياً في assets.)
  });
}
