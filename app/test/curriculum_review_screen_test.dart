// اختبار شاشة مراجعة الوحدة: تعرض الفصول وتُظهر أقسام 🔑/🧾/⚖️ عند التوسيع.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/features/curriculum/curriculum_review_screen.dart';

Paragraph _p(String id, String summary, String text) =>
    Paragraph(id: id, text: text, summary: summary, experimentId: null);

Unit _unit() => Unit(
      id: 'U1',
      title: 'الوحدة الأولى: تجريب',
      chapters: [
        Chapter(
          id: 'U1C1',
          title: 'الفصل الأول',
          page: 10,
          paragraphs: [
            _p('U1C1P0', 'مقدمة — لماذا هذا الدرس', 'نصّ المقدمة'),
            _p('U1C1P1', '🔑 قبل أن تبدأ — تحتاج', 'نصّ المتطلبات السابقة'),
            _p('U1C1P9', '📖 الفكرة — جزء 1', 'شرح لا يظهر في المراجعة'),
            _p('U1C1P20', '🧾 خلاصة — القوانين', 'نصّ الخلاصة الذهبية'),
            _p('U1C1P21', '⚖️ خصومات السلم — تنبيهات', 'نصّ خصومات التصحيح'),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: CurriculumReviewScreen(unit: _unit()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('العنوان يحمل اسم الوحدة والفصل مدرَج', (tester) async {
    await _pump(tester);
    expect(find.text('مراجعة: الوحدة الأولى: تجريب'), findsOneWidget);
    expect(find.text('الفصل الأول'), findsOneWidget);
    // ٣ أقسام مراجعة (🔑/🧾/⚖️) — لا المقدمة ولا 📖
    expect(find.text('٣ أقسام مراجعة'), findsOneWidget);
  });

  testWidgets('التوسيع يعرض أقسام المراجعة الثلاثة بنصوصها فقط', (tester) async {
    await _pump(tester);
    // قبل التوسيع: النصوص مخفية
    expect(find.text('نصّ الخلاصة الذهبية'), findsNothing);
    await tester.tap(find.byKey(const Key('review-U1C1')));
    await tester.pumpAndSettle();
    // عناوين الأقسام (قبل « — »)
    expect(find.text('🔑 قبل أن تبدأ'), findsOneWidget);
    expect(find.text('🧾 خلاصة'), findsOneWidget);
    expect(find.text('⚖️ خصومات السلم'), findsOneWidget);
    // النصوص
    expect(find.text('نصّ المتطلبات السابقة'), findsOneWidget);
    expect(find.text('نصّ الخلاصة الذهبية'), findsOneWidget);
    expect(find.text('نصّ خصومات التصحيح'), findsOneWidget);
    // المقدمة و 📖 لا يظهران في المراجعة
    expect(find.text('نصّ المقدمة'), findsNothing);
    expect(find.text('شرح لا يظهر في المراجعة'), findsNothing);
  });
}
