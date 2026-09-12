import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/progress/progress_store.dart';
import 'package:fizya_clash/core/training/batch_builder.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/core/tts/speaker.dart';
import 'package:fizya_clash/features/curriculum/lesson_screen.dart';
import 'package:fizya_clash/main.dart';

/// حزمة اختبار مصغّرة: وحدة بفصل من فقرتين + وحدة فارغة.
ContentPack _fakePack() => ContentPack.fromJsonString(jsonEncode({
      'packId': 'test-pack',
      'year': 2027,
      'edition': 1,
      'units': [
        {
          'id': 'U1',
          'title': 'الحركة والتحريك',
          'chapters': [
            {
              'id': 'U1C1',
              'title': 'الحركة التوافقية البسيطة',
              'page': 6,
              'paragraphs': [
                {
                  'id': 'P1',
                  'text': 'نص الفقرة الأولى كاملاً للقراءة.',
                  'summary': 'خلاصة الفقرة الأولى'
                },
                {
                  'id': 'P2',
                  'text': 'نص الفقرة الثانية للقراءة.',
                  'summary': 'خلاصة الفقرة الثانية'
                }
              ]
            }
          ]
        },
        {
          'id': 'U2',
          'title': 'الكهرباء والمغناطيسية',
          'chapters': []
        }
      ],
      'questions': [],
      'cards': []
    }));

/// حزمة تدريب صغيرة: سؤالان معتمدان بفصل واحد — لدورة الدفعة الكاملة.
ContentPack _trainingPack() => ContentPack.fromJsonString(jsonEncode({
      'packId': 'train-pack',
      'year': 2027,
      'edition': 1,
      'units': [
        {
          'id': 'U1',
          'title': 'وحدة التدريب',
          'chapters': [
            {'id': 'U1C1', 'title': 'فصل التدريب', 'page': 1, 'paragraphs': []}
          ]
        }
      ],
      'questions': [
        {
          'id': 901,
          'unit': 'U1',
          'chapter': 'U1C1',
          'approved': true,
          'stem': 'سؤال ٩٠١: ما وحدة قياس القوة؟',
          'options': ['النيوتن N', 'الجول J', 'الواط W', 'الباسكال Pa'],
          'correctIndex': 0,
          'solutionSteps': ['القوة قياسها النيوتن حسب النظام الدولي.'],
          'followThrough': []
        },
        {
          'id': 902,
          'unit': 'U1',
          'chapter': 'U1C1',
          'approved': true,
          'stem': 'سؤال ٩٠٢: وحدة قياس الشغل؟',
          'options': ['النيوتن N', 'الباسكال Pa', 'الجول J', 'الواط W'],
          'correctIndex': 2,
          'solutionSteps': ['الشغل = قوة × إزاحة ⇒ نيوتن·متر = جول.'],
          'followThrough': []
        }
      ],
      'cards': []
    }));

/// مضخة بحزمة مخصصة — لاختبارات التدريب (F3.3).
Future<void> pumpTrainingApp(WidgetTester tester,
    {required ContentPack pack, InMemoryTrainingStore? store}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FizyaClashApp(
    packLoader: () async => pack,
    progressStore: InMemoryProgressStore(),
    trainingStore: store ?? InMemoryTrainingStore(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> pumpApp(WidgetTester tester,
      {InMemoryProgressStore? progressStore}) async {
    // سطح اختبار بمقاس هاتف فعلي — يمنع مشاكل off-screen بالمسار الكامل
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FizyaClashApp(
      packLoader: () async => _fakePack(),
      progressStore: progressStore ?? InMemoryProgressStore(),
      trainingStore: InMemoryTrainingStore(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('المنهاج: العنوان + الوحدتان + الوضع الفاتح/الداكن', (tester) async {
    await pumpApp(tester);

    expect(find.text('فيزيا كلاش'), findsOneWidget);
    expect(find.text('الوحدات الخمس'), findsOneWidget);
    expect(find.text('١ · الحركة والتحريك'), findsOneWidget);
    expect(find.text('٢ · الكهرباء والمغناطيسية'), findsOneWidget);
    // الوحدة الفارغة: قيد الإعداد
    expect(find.text('قيد الإعداد — تصل مع تحديث المحتوى'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
    expect(find.text('الوحدات الخمس'), findsOneWidget);
  });

  testWidgets('مسار القراءة: وحدة ← فصل ← فقرتان + خلاصة + انتهى الدرس',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('١ · الحركة والتحريك'));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ القراءة'), findsOneWidget);

    await tester.tap(find.text('ابدأ القراءة'));
    await tester.pumpAndSettle();
    expect(find.text('نص الفقرة الأولى كاملاً للقراءة.'), findsOneWidget);
    expect(find.text('خلاصة الفقرة الأولى'), findsOneWidget);
    expect(find.text('فقرة ١ من ٢'), findsOneWidget);

    // الفهرس الحر: فتحه يظهر الفقرتين
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(find.text('الفقرة ٢ — خلاصة الفقرة الثانية'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    expect(find.text('نص الفقرة الثانية للقراءة.'), findsOneWidget);
    expect(find.text('فقرة ٢ من ٢'), findsOneWidget);

    await tester.tap(find.text('انتهى الدرس ✓'));
    await tester.pumpAndSettle();
    expect(find.text('أنهيت الفصل!'), findsOneWidget);
    expect(find.text('+١٠ نقطة لدوري فيزيا كلاش ✓'), findsOneWidget);

    // F3.1: العودة للوحدة — الفصل المكتمل يحمل علامة ✓
    await tester.tap(find.text('رجوع للوحدة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('✓ الفصل ١'), findsOneWidget);
  });

  testWidgets('F3.1: النسبة تبدأ صفراً وتكتمل ١٠٠٪ بعد إتمام الفصل',
      (tester) async {
    final store = InMemoryProgressStore();
    await pumpApp(tester, progressStore: store);

    // قبل القراءة: ٠٪
    expect(find.text('٠٪'), findsWidgets);

    // مسار كامل حتى الإتمام
    await tester.tap(find.text('١ · الحركة والتحريك'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ القراءة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انتهى الدرس ✓'));
    await tester.pumpAndSettle();

    // المخزن حفظ الإتمام فعلاً
    final p = await store.load();
    expect(p.completedIds, contains('U1C1'));

    // العودة للمنهاج — الوحدة الأولى ١٠٠٪
    await tester.tap(find.text('رجوع للوحدة'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('١٠٠٪'), findsOneWidget);
  });

  // تمهيد مشترك: فتح الفصل والتقدم للفقرة ٢ بلا إتمام (تفتيت تشخيصي F3.1)
  Future<void> openLessonAndAdvance(WidgetTester tester) async {
    await tester.tap(find.text('١ · الحركة والتحريك'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ القراءة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
  }

  testWidgets('F3.1-أ: التالي يحفظ cursor=1 بلا إتمام (طبقة المخزن)', (tester) async {
    final store = InMemoryProgressStore();
    await pumpApp(tester, progressStore: store);
    await openLessonAndAdvance(tester);
    expect(find.text('فقرة ٢ من ٢'), findsOneWidget);
    final p = await store.load();
    expect(p.chapters['U1C1']?.cursor, 1);
    expect(p.chapters['U1C1']?.completed, isFalse);
  });

  testWidgets('F3.1-ب: خروج بلا إتمام ⇒ «متابعة القراءة» بالوحدة', (tester) async {
    await pumpApp(tester);
    await openLessonAndAdvance(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('متابعة القراءة'), findsOneWidget);
    expect(find.text('ابدأ القراءة'), findsNothing);
  });

  testWidgets('F3.1-ج: الدخول عبر المتابعة يفتح الفقرة المحفوظة', (tester) async {
    await pumpApp(tester);
    await openLessonAndAdvance(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة القراءة'));
    await tester.pumpAndSettle();
    expect(find.text('فقرة ٢ من ٢'), findsOneWidget);
  });

  testWidgets('F3.1-د: الإتمام بعد الاستئناف يعيد «ابدأ القراءة» مع ✓', (tester) async {
    await pumpApp(tester);
    await openLessonAndAdvance(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة القراءة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انتهى الدرس ✓'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رجوع للوحدة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('✓ الفصل ١'), findsOneWidget);
    expect(find.text('متابعة القراءة'), findsNothing);
    expect(find.text('ابدأ القراءة'), findsOneWidget);
  });

  testWidgets('اسمعني: يظهر مع محرك عربي وينطق الفقرة', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final speaker = _FakeSpeaker(available: true);
    final chapter = _fakePack().units.first.chapters.first;

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LessonScreen(
          chapter: chapter,
          progressStore: InMemoryProgressStore(),
          speaker: speaker,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_outlined));
    await tester.pumpAndSettle();
    expect(speaker.spoken, ['نص الفقرة الأولى كاملاً للقراءة.']);
  });

  testWidgets('اسمعني: يختفي كلياً بلا محرك عربي (قرار F3.2)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final chapter = _fakePack().units.first.chapters.first;

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child:
            LessonScreen(
              chapter: chapter,
              progressStore: InMemoryProgressStore(),
              speaker: _FakeSpeaker(available: false)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    // والفهرس باقٍ — الاختفاء خاص بزر النطق فقط
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });

  testWidgets('F3.3: البنك المقفول قبل مصادقة الأستاذ (قرار ٢٤)', (tester) async {
    // fakePack بلا أسئلة ⇒ pool = 0 ⇒ شاشة الانتظار
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    expect(find.text('بانتظار مصادقة الأستاذ'), findsOneWidget);
    expect(find.text('الأسئلة لم تُفتح بعد'), findsOneWidget);
  });

  // تمهيد مشترك: الدخول للتدريب وبدء دفعة اليوم (تفتيت تشخيصي F3.3)
  Future<void> startDailyBatch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ دفعة اليوم'));
    await tester.pumpAndSettle();
  }

  testWidgets('F3.3-أ: إجابة س١ تصل المخزن وبطاقة الخطوات تظهر', (tester) async {
    final pack = _trainingPack();
    final store = InMemoryTrainingStore();
    await pumpTrainingApp(tester, pack: pack, store: store);
    final todayKey = dateKeyOf(DateTime.now());
    final batch = buildDailyBatch(pack, dateKey: todayKey)!;
    final q1 = pack.questions
        .firstWhere((q) => q.id == batch.session.questionIds[0]);
    final order1 = batch.session.optionOrders[q1.id]!;
    final correct1 = q1.options[order1[displayCorrectIndex(q1, order1)]];

    await startDailyBatch(tester);
    await tester.tap(find.ancestor(
        of: find.text(correct1), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    final data = await store.load(); // الطبقة المحفوظة
    expect(data.daily!.answers[q1.id], isNotNull);
    expect(find.text('📌 خطوات الحل'), findsOneWidget); // الطبقة المرئية
  });

  testWidgets('F3.3-ب: التالي لس٢ وإجابة خاطئة والنتيجة ١ من ٢', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    final todayKey = dateKeyOf(DateTime.now());
    final batch = buildDailyBatch(pack, dateKey: todayKey)!;
    Question qOf(int i) =>
        pack.questions.firstWhere((q) => q.id == batch.session.questionIds[i]);
    List<int> orderOf(int i) => batch.session.optionOrders[qOf(i).id]!;
    String correctText(int i) =>
        qOf(i).options[orderOf(i)[displayCorrectIndex(qOf(i), orderOf(i))]];
    String wrongText(int i) =>
        qOf(i).options[orderOf(i)[(qOf(i).correctIndex + 1) % 4]];

    await startDailyBatch(tester);
    await tester.tap(find.ancestor(
        of: find.text(correctText(0)), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    expect(find.text('سؤال ٢ من ٢'), findsOneWidget);
    await tester.tap(find.ancestor(
        of: find.text(wrongText(1)), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النتيجة'));
    await tester.pumpAndSettle();
    expect(find.text('أنهيت دفعة اليوم!'), findsOneWidget);
    expect(find.text('١ من ٢'), findsOneWidget);
  });

  testWidgets('F3.3-ج: البوابة بعد الإتمام والأرشيف فيه خطأ واحد', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    final todayKey = dateKeyOf(DateTime.now());
    final batch = buildDailyBatch(pack, dateKey: todayKey)!;
    Question qOf(int i) =>
        pack.questions.firstWhere((q) => q.id == batch.session.questionIds[i]);
    List<int> orderOf(int i) => batch.session.optionOrders[qOf(i).id]!;
    String correctText(int i) =>
        qOf(i).options[orderOf(i)[displayCorrectIndex(qOf(i), orderOf(i))]];
    String wrongText(int i) =>
        qOf(i).options[orderOf(i)[(qOf(i).correctIndex + 1) % 4]];

    await startDailyBatch(tester);
    await tester.tap(find.ancestor(
        of: find.text(correctText(0)), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(
        of: find.text(wrongText(1)), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النتيجة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رجوع للتدريب'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أنهيت دفعة اليوم'), findsOneWidget);
    expect(find.text('الأرشيف: ١ خطأ'), findsOneWidget);
  });

  testWidgets('F3.3-د: الأرشيف يعرض الخطأ بنصه وإجابته', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    final todayKey = dateKeyOf(DateTime.now());
    final batch = buildDailyBatch(pack, dateKey: todayKey)!;
    Question qOf(int i) =>
        pack.questions.firstWhere((q) => q.id == batch.session.questionIds[i]);
    List<int> orderOf(int i) => batch.session.optionOrders[qOf(i).id]!;
    String correctText(int i) =>
        qOf(i).options[orderOf(i)[displayCorrectIndex(qOf(i), orderOf(i))]];
    String wrongText(int i) =>
        qOf(i).options[orderOf(i)[(qOf(i).correctIndex + 1) % 4]];

    await startDailyBatch(tester);
    await tester.tap(find.ancestor(
        of: find.text(correctText(0)), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي ←'));
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(
        of: find.text(wrongText(1)), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النتيجة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رجوع للتدريب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الأرشيف: ١ خطأ'));
    await tester.pumpAndSettle();
    expect(find.textContaining(qOf(1).stem), findsOneWidget);
    expect(find.textContaining('✓ الصحيح:'), findsOneWidget);
  });

  testWidgets('F3.3: استئناف منتصف الدفعة — أول غير مجاب', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    final todayKey = dateKeyOf(DateTime.now());
    final batch = buildDailyBatch(pack, dateKey: todayKey)!;
    final q1 = pack.questions
        .firstWhere((q) => q.id == batch.session.questionIds[0]);
    final order1 = batch.session.optionOrders[q1.id]!;
    final correct1 = q1.options[order1[displayCorrectIndex(q1, order1)]];

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ دفعة اليوم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(correct1)); // إجابة السؤال الأول فقط
    await tester.pumpAndSettle();
    await tester.pageBack(); // خروج بلا إتمام
    await tester.pumpAndSettle();

    // البوابة تعرض «أكمل» مع التقدم
    expect(find.text('أكمل دفعة اليوم'), findsOneWidget);
    expect(find.textContaining('تقدّمك اليوم: ١'), findsOneWidget);

    // الاستئناف يفتح أول غير مجاب — السؤال الثاني لا الأول
    await tester.tap(find.text('أكمل دفعة اليوم'));
    await tester.pumpAndSettle();
    expect(find.text('سؤال ٢ من ٢'), findsOneWidget);
  });
}


/// زائف النطق — يسجل ما طُلب نطقه (نمط الحقن نفسه).
class _FakeSpeaker implements Speaker {
  _FakeSpeaker({required this.available});

  final bool available;
  final List<String> spoken = [];

  @override
  Future<bool> hasArabicEngine() async => available;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
