/// F2.3 — بوابة عرض الصيغ: قاعدة العزل تُختبر على البيانات المُولَّدة نفسها،
/// لا على أمثلة مختارة؛ فمعيار docs/02 («لا كلمة عربية داخل الصيغة») إما ثابت
/// على كامل المستودع أو لا يُعتمد عليه.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/math_text.dart';

/// مرآة عربية النطاق المستخدمة في المصدر — للتأكد أن لا عربي تسرّب إلى معزول.
final RegExp _arabic = RegExp('[؀-ۿ]');
final RegExp _isolated = RegExp('\u{2068}([^\u{2069}]*)\u{2069}');

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> asset = const {};
  setUpAll(() async {
    asset = jsonDecode(
          await rootBundle.loadString('assets/content/items.json'),
        ) as Map<String, dynamic>;
  });

  group('كشف الشرائط', () {
    test('صيغة وسط جملة عربية تُلتقط كاملة', () {
      const s = 'الدور هو T0 = 2π√(L/g) للعلاقة';
      expect(mathRuns(s), ['T0', '2π√(L/g)']);
    });

    test('العزل reversible: حذف علامتَي FSI/PDI يعيد النصّ حرفياً', () {
      const s = 'بما أن π² = 10 وg = 10 m·s⁻² فإن النتائج تُقارب 90%.';
      final iso = isolateMath(s);
      expect(
        iso.replaceAll('\u{2068}', '').replaceAll('\u{2069}', ''),
        s,
      );
      expect('\u{2068}'.allMatches(iso).length, '\u{2069}'.allMatches(iso).length);
    });

    test('لا عربيّ داخل أي شريط معزول (قاعدة docs/02)', () {
      const s = 'المقاومة R = V/I بوحدة Ω ودرجة الحرارة θ';
      final matches = _isolated.allMatches(isolateMath(s)).toList();
      expect(matches, isNotEmpty);
      for (final m in matches) {
        expect(_arabic.hasMatch(m.group(1)!), isFalse, reason: m.group(1));
      }
    });

    test('ما ليس صيغة لا يُعزل', () {
      expect(isMathToken('(A)'), isFalse); // مُعرَّف خيار لا معادلة
      expect(isMathToken('·'), isFalse); // علامة بلا مجهول
      expect(isMathToken('[mix_formulas]:'), isFalse); // معرّف قاعدة
      expect(isMathToken('مقاومة'), isFalse);
      expect(isMathToken('y(t)'), isFalse);
      expect(isMathToken('50%'), isFalse);
    });

    test('ما هو صيغة يُعزل', () {
      for (final t in ['x=0', '60Hz', 'kg/m', 'T0', 'π²', 'IΔ', 'rad·s⁻¹', '=10']) {
        expect(isMathToken(t), isTrue, reason: t);
      }
      // الرقم المجرد ليس «صيغة» تُعزل، والوحدة وحدها تُعزل — سلوك موثَّق.
      expect(mathRuns('100 Ω'), ['Ω']);
      expect(mathRuns('3.00'), isEmpty);
    });
  });

  group('على البيانات المُولَّدة (٥٦١ بنداً)', () {
    late List<dynamic> items;
    setUp(() => items = asset['items'] as List<dynamic>);

    test('لا شريط صيغة في المستودع يحتوي حرفاً عربياً', () {
      var checked = 0;
      for (final raw in items.cast<Map<String, dynamic>>()) {
        final texts = <String>[
          raw['stem'] as String,
          ...((raw['options'] as List?) ?? const []).cast<String>(),
          for (final p in (raw['parts'] as List?) ?? const [])
            (p as Map<String, dynamic>)['prompt'] as String,
          ...((raw['solutionSteps'] as List?) ?? const []).cast<String>(),
        ];
        for (final t in texts) {
          checked++;
          for (final r in mathRuns(t)) {
            expect(_arabic.hasMatch(r), isFalse, reason: '$t → $r');
          }
        }
      }
      expect(checked, 5038);
    });

    test('أعداد النصوص التي تحوي صيغة (تُثبَّت مع البيانات)', () {
      int count(List<String> texts) => texts.where((t) => mathRuns(t).isNotEmpty).length;
      final stems = <String>[];
      final options = <String>[];
      final prompts = <String>[];
      final steps = <String>[];
      for (final raw in items.cast<Map<String, dynamic>>()) {
        stems.add(raw['stem'] as String);
        options.addAll(((raw['options'] as List?) ?? const []).cast<String>());
        for (final p in (raw['parts'] as List?) ?? const []) {
          prompts.add((p as Map<String, dynamic>)['prompt'] as String);
        }
        steps.addAll(((raw['solutionSteps'] as List?) ?? const []).cast<String>());
      }
      expect(count(stems), 314);
      expect(stems.length, 561);
      expect(count(options), 1058);
      expect(options.length, 2184);
      expect(count(prompts), 18);
      expect(prompts.length, 42);
      expect(count(steps), 707);
      expect(steps.length, 2251);
    });
  });

  group('MathText', () {
    testWidgets('بلا renderer → نصّ واحد معزول', (tester) async {
      const s = 'العلاقة T0 = 2π√(L/g) صحيحة';
      await tester.pumpWidget(_host(const MathText(s)));
      expect(find.byType(Text), findsOneWidget);
      expect(find.text(isolateMath(s)), findsOneWidget);
      expect(find.text(s), findsNothing); // لا يُعرض خاماً قبل العزل
    });

    testWidgets('renderer يُستدعى لكل شريط صيغة بالنصّ الخام', (tester) async {
      Widget render(String f) => Text('«$f»');
      await tester.pumpWidget(
        _host(MathText('قِس T0 وIΔ هنا', renderer: render)),
      );
      expect(find.text('«T0»'), findsOneWidget);
      expect(find.text('«IΔ»'), findsOneWidget);
      // كل مرسوم داخل Directionality صريح LTR — لا يرث اتجاه الفقرة.
      expect(
        find.descendant(
          of: find.byType(MathText),
          matching: find.byType(Directionality),
        ),
        findsNWidgets(2),
      );
      for (final d in tester.widgetList<Directionality>(
        find.descendant(
          of: find.byType(MathText),
          matching: find.byType(Directionality),
        ),
      )) {
        expect(d.textDirection, TextDirection.ltr);
      }
    });
  });
}

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
