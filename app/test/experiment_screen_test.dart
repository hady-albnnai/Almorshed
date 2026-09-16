import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/lab/experiments.dart';
import 'package:fizya_clash/core/progress/progress_store.dart';
import 'package:fizya_clash/core/training/batch_builder.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/core/xp/streak_service.dart';
import 'package:fizya_clash/features/curriculum/lesson_screen.dart';
import 'package:fizya_clash/features/lab/experiment_screen.dart';
import 'package:fizya_clash/features/lab/lab_screen.dart';

/// المادة ١٤ — شاشة التجربة العامة: بوابة التوقع، المحاكاة الحية (بلا
/// pumpAndSettle مع التيكر)، التحدي مرة/يوم بالحفظ، والدمج داخل الدرس.
void main() {
  Future<void> pumpExperiment(
    WidgetTester tester,
    LabExperiment exp, {
    TrainingStore? store,
    XpRecorder? rec,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ExperimentScreen(
          experiment: exp,
          trainingStore: store ?? InMemoryTrainingStore(),
          xpRecorder: rec,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('نواس الفتل: توقّع ⇒ سحب ⇒ تشغيل ⇒ قياس ⇒ اشرح', (tester) async {
    await pumpExperiment(tester, const TorsionExperiment());
    expect(find.text('توقع قبل التجريب'), findsOneWidget);
    expect(find.text('تشغيل ▶'), findsNothing);
    await tester.tap(find.byKey(const Key('predict-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theory-period')), findsOneWidget);
    // اسحب أولاً (x=0 لا يتذبذب) ثم شغّل — لا pumpAndSettle مع التيكر
    await tester.drag(find.byKey(const Key('exp-canvas')), const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exp-run')));
    await tester.pump();
    // T0 ≈ 3.14 ث ⇒ ١٠ ثوانٍ تكفي لدورتين مكتملتين
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.byKey(const Key('measured-period')), findsOneWidget);
    expect(find.text('اشرح'), findsOneWidget);
    expect(find.textContaining('كان مطابقاً للقانون'), findsOneWidget);
  });

  testWidgets('التشغيل بلا سحب يبدأ من نصف الانحراف — يتذبذب ويقيس',
      (tester) async {
    await pumpExperiment(tester, const GravityPendulumExperiment());
    await tester.tap(find.byKey(const Key('predict-0'))); // توقع خاطئ
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exp-run')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6)); // T0 ≈ 1.54 ث
    await tester.pump();
    expect(find.byKey(const Key('measured-period')), findsOneWidget);
    // التوقع الخاطئ ⇒ يُعرض الأدق مع الشرح
    expect(find.textContaining('التوقع الأدق'), findsOneWidget);
  });

  testWidgets('التحدي: الوصول بالأزرار ± والتسجيل مرة باليوم مع الحفظ وXP',
      (tester) async {
    final store = InMemoryTrainingStore();
    final rec = XpRecorder.inMemory();
    await pumpExperiment(tester, const GravityPendulumExperiment(),
        store: store, rec: rec);
    await tester.tap(find.byKey(const Key('predict-1')));
    await tester.pumpAndSettle();

    // الافتراضي l = 0.6 ⇒ T0 ≈ 1.54 خارج النافذة
    expect(find.textContaining('تحقّق'), findsNothing);
    expect(find.byKey(const Key('challenge-record')), findsNothing);
    // l إلى 1.0 بخطوة 0.05 ⇒ ٨ نقرات
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('inc-l')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('l = 1.00 m'), findsOneWidget);
    expect(find.textContaining('تحقّق'), findsOneWidget);
    await tester.tap(find.byKey(const Key('challenge-record')));
    await tester.pumpAndSettle();
    expect(find.textContaining('سُجّل اليوم'), findsOneWidget);
    expect(find.byKey(const Key('challenge-record')), findsNothing);

    final data = await store.load();
    expect(data.labChallengeDays['gravity'], dateKeyOf(DateTime.now()));
    expect(data.labChallengeDoneDateKey, isNull); // حقل النابض لم يُمس
    final events = await rec.ledger.events();
    expect(events.where((e) => e.type == 'labChallenge').length, 1);
  });

  testWidgets('الحالة من المخزن: تحدي مسجّل اليوم لا يُعاد عرض زره',
      (tester) async {
    final store = InMemoryTrainingStore();
    await store.save(TrainingData(
        labChallengeDays: {'lc': dateKeyOf(DateTime.now())}));
    await pumpExperiment(tester, const LcCircuitExperiment(), store: store);
    await tester.tap(find.byKey(const Key('predict-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('سُجّل اليوم'), findsOneWidget);
    expect(find.byKey(const Key('challenge-record')), findsNothing);
  });

  testWidgets('الوتر: التحدي على عدد المغازل n = ٣ (لا طنين ⇒ لا تسجيل)',
      (tester) async {
    await pumpExperiment(tester, const StringWaveExperiment());
    await tester.tap(find.byKey(const Key('predict-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('لا طنين'), findsOneWidget);
    expect(find.byKey(const Key('challenge-record')), findsNothing);
    // f من 50 إلى 95 Hz (f3 ≈ 94.9) ⇒ ٤٥ نقرة على + الخاص بـ f
    for (var i = 0; i < 45; i++) {
      await tester.tap(find.byKey(const Key('inc-f')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('القيمة الحالية: n = ٣'), findsOneWidget);
    expect(find.byKey(const Key('challenge-record')), findsOneWidget);
  });

  testWidgets('الكهرضوئي: بلا محاكاة زمنية — الشرح فوري والتحدي على Ek',
      (tester) async {
    await pumpExperiment(tester, const PhotoelectricExperiment());
    await tester.tap(find.byKey(const Key('predict-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exp-run')), findsNothing);
    expect(find.text('اشرح'), findsOneWidget);
    expect(find.textContaining('λ0 = hc/Ws'), findsOneWidget);
    expect(find.byKey(const Key('challenge-record')), findsNothing);
    // λ من 450 إلى 390 nm بخطوة 10 ⇒ ٦ نقرات على −
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('dec-lambda')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('λ = 390 nm'), findsOneWidget);
    expect(find.byKey(const Key('challenge-record')), findsOneWidget);
  });

  testWidgets('فهرس المختبر: الخمس ظاهرة، تفتح الشاشة، وتعود بعلامة ✓',
      (tester) async {
    final store = InMemoryTrainingStore();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LabScreen(trainingStore: store),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('النابض التوافقي'), findsOneWidget);
    for (final id in labExperiments.keys) {
      expect(find.byKey(Key('lab-$id')), findsOneWidget);
    }
    expect(find.textContaining('قيد الإعداد'), findsNothing);
    expect(find.text('✓'), findsNothing);

    await tester.tap(find.byKey(const Key('lab-photo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('الفعل الكهرضوئي'), findsWidgets);
    await tester.tap(find.byKey(const Key('predict-1')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('dec-lambda')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge-record')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('✓'), findsOneWidget); // بطاقة الكهرضوئي فقط
  });

  testWidgets('داخل الدرس: الفقرة ذات experimentId تعرض بطاقة «جرّبها بنفسك»',
      (tester) async {
    final pack = ContentPack.fromJsonString(jsonEncode({
      'packId': 'p',
      'year': 2027,
      'edition': 1,
      'units': [
        {
          'id': 'U1',
          'title': 'و١',
          'chapters': [
            {
              'id': 'U1C3',
              'title': 'النواس الثقلي',
              'page': 40,
              'paragraphs': [
                {'id': 'U1C3P1', 'text': 'فقرة بلا تجربة', 'summary': 'أ'},
                {
                  'id': 'U1C3P2',
                  'text': 'الحركة غير توافقية في السعات الكبيرة',
                  'summary': 'ب',
                  'experimentId': 'gravity',
                },
              ],
            }
          ],
        }
      ],
      'questions': [],
      'cards': [],
    }));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LessonScreen(
          chapter: pack.units.single.chapters.single,
          progressStore: InMemoryProgressStore(),
          trainingStore: InMemoryTrainingStore(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('experiment-gravity')), findsNothing);
    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('experiment-gravity')), findsOneWidget);
    await tester.tap(find.byKey(const Key('experiment-gravity')));
    await tester.pumpAndSettle();
    expect(find.text('توقع قبل التجريب'), findsOneWidget);
    expect(find.textContaining('النواس الثقلي البسيط'), findsWidgets);
    await tester.pageBack(); // عودة إلى الدرس بموضعه
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('experiment-gravity')), findsOneWidget);
  });

  test('TrainingData: labChallengeDays يدور عبر JSON ويبقى مع copyWith', () {
    const d = TrainingData(
      labChallengeDoneDateKey: '2026-09-16',
      labChallengeDays: {'torsion': '2026-09-16', 'lc': '2026-09-15'},
    );
    final back = TrainingData.fromJson(d.toJson());
    expect(back.labChallengeDays, {'torsion': '2026-09-16', 'lc': '2026-09-15'});
    expect(back.labChallengeDoneDateKey, '2026-09-16');
    // توافق خلفي: JSON قديم بلا الحقل
    final legacy = TrainingData.fromJson({'mistakes': <dynamic>[]});
    expect(legacy.labChallengeDays, isEmpty);
    expect(legacy.toJson().containsKey('labChallengeDays'), isFalse);
    // copyWith لا يُسقط شيئاً (العلة الكامنة القديمة)
    final merged = withNewMistakes(d, const []);
    expect(merged.labChallengeDays.length, 2);
    expect(merged.labChallengeDoneDateKey, '2026-09-16');
    final c = d.copyWith(labChallengeDays: {...d.labChallengeDays, 'photo': 'x'});
    expect(c.labChallengeDays.length, 3);
    expect(c.labChallengeDoneDateKey, '2026-09-16');
  });
}
