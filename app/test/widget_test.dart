import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/license/license_store.dart';
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
      'cards': [
        {
          'id': 801,
          'unit': 'U1',
          'chapter': 'U1C1',
          'front': 'ما قانون هوك؟',
          'back': 'القوة تتناسب مع التمدد',
          'formula': 'F = −k·x'
        },
        {
          'id': 802,
          'unit': 'U1',
          'chapter': 'U1C1',
          'front': 'وحدة ثابت النابض k؟',
          'back': 'نيوتن لكل متر N/m'
        }
      ]
    }));

/// مضخة بحزمة مخصصة — لاختبارات التدريب (F3.3).
Future<void> pumpTrainingApp(WidgetTester tester,
    {required ContentPack pack,
    InMemoryTrainingStore? store,
    InMemoryLicenseStore? licenseStore}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FizyaClashApp(
    packLoader: () async => pack,
    progressStore: InMemoryProgressStore(),
    trainingStore: store ?? InMemoryTrainingStore(),
    // وضع التجربة افتراضياً — اختبارات المنهاج لا تعبر البوابة
    licenseStore: licenseStore ?? InMemoryLicenseStore.trial(),
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
      licenseStore: InMemoryLicenseStore.trial(), // المنهاج مباشرة بلا بوابة
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

  testWidgets('F3.4: بوابة البطاقات — الطابور والبدء والتجميد', (tester) async {
    final pack = _trainingPack();
    final store = InMemoryTrainingStore();
    await pumpTrainingApp(tester, pack: pack, store: store);

    // الدخول لشاشة التدريب أولاً ثم إلى البطاقات
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة البطاقات'));
    await tester.pumpAndSettle();

    // الطابور الاستباقي: بطاقتان جديدتان
    expect(find.textContaining('طابور اليوم: ٢'), findsOneWidget);
    expect(find.text('٠ مراجعة + ٢ جديدة'), findsOneWidget);

    // البدء يجمّد الطابور ويفتح جلسة المراجعة
    await tester.tap(find.text('ابدأ مراجعة البطاقات'));
    await tester.pumpAndSettle();
    expect(find.text('ما قانون هوك؟'), findsOneWidget); // 801 أولاً

    // الخروج — البوابة تعرض «أكمل» بتقدم ٠
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('أكمل المراجعة'), findsOneWidget);
    expect(find.textContaining('تقدّمك: ٠'), findsOneWidget);
  });

  testWidgets('F3.4: دورة كاملة — كشف ثم تقييم ثم إتمام +١٥', (tester) async {
    final pack = _trainingPack();
    final store = InMemoryTrainingStore();
    await pumpTrainingApp(tester, pack: pack, store: store);
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة البطاقات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ مراجعة البطاقات'));
    await tester.pumpAndSettle();

    // الوجه أولاً — لا تقييم قبل الكشف
    expect(find.text('اضغط لكشف الجواب'), findsOneWidget);
    expect(find.text('😎 أعرفها'), findsNothing);

    // الكشف: الظهر والقانون الذهبي والأزرار الثلاثة
    await tester.tap(find.text('ما قانون هوك؟'));
    await tester.pumpAndSettle();
    expect(find.text('القوة تتناسب مع التمدد'), findsOneWidget);
    expect(find.text('F = −k·x'), findsOneWidget);
    expect(find.text('😅 ما عرفتها'), findsOneWidget);
    expect(find.text('😔 بصعوبة'), findsOneWidget);
    expect(find.text('😎 أعرفها'), findsOneWidget);

    // التقييم ينتقل للبطاقة الثانية
    await tester.tap(find.text('😎 أعرفها'));
    await tester.pumpAndSettle();
    expect(find.text('وحدة ثابت النابض k؟'), findsOneWidget);

    // كشف وتقييم ثانٍ → شاشة الإتمام +١٥
    await tester.tap(find.text('وحدة ثابت النابض k؟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😔 بصعوبة'));
    await tester.pumpAndSettle();
    expect(find.text('أنهيت بطاقات اليوم!'), findsOneWidget);
    expect(find.text('+١٥ نقطة لدوري فيزيا كلاش ✓'), findsOneWidget);

    // العودة — البوابة تعرض الإنجاز
    await tester.tap(find.text('رجوع للبطاقات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أنهيت بطاقات اليوم'), findsOneWidget);

    // والحالات محفوظة بالمخزن (FSRS فعلياً)
    final data = await store.load();
    expect(data.cardStates, hasLength(2));
    expect(data.cardDay!.finished, isTrue);
  });

  testWidgets('F3.6: بوابة أول فتح — التجربة تدخل والبوابة لا تعود',
      (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack,
        licenseStore: InMemoryLicenseStore()); // وضع none ⇒ البوابة
    expect(find.text('أهلاً بك في «فيزيا كلاش»'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);

    await tester.tap(find.text('تجربة المحتوى التجريبي (بدون تفعيل)'));
    await tester.pumpAndSettle();
    // دخلت المنهاج — والبوابة اختفت
    expect(find.text('أهلاً بك في «فيزيا كلاش»'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    // إعادة فتح كاملة (بناء جديد): الوضع محفوظ — لا بوابة مجدداً
    await pumpTrainingApp(tester, pack: pack,
        licenseStore: InMemoryLicenseStore.trial());
    expect(find.text('أهلاً بك في «فيزيا كلاش»'), findsNothing);
  });

  testWidgets('F3.6: تنسيق الكود الحي ٥-٥-٥ كالنموذج', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack,
        licenseStore: InMemoryLicenseStore());
    await tester.enterText(
        find.byType(TextField), 'k7m2p9qw4x4tr8n');
    await tester.pumpAndSettle();
    expect(find.text('K7M2P-9QW4X-4TR8N'), findsOneWidget);
  });

  testWidgets('F3.6: كود ناقص يُرفض + ٥ محاولات ثم انتظار تدريجي',
      (tester) async {
    final pack = _trainingPack();
    final license = InMemoryLicenseStore();
    await pumpTrainingApp(tester, pack: pack, licenseStore: license);
    const incomplete = 'K7M2P-9QW4'; // أقل من ١٥
    await tester.enterText(find.byType(TextField), incomplete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الكود ناقص'), findsOneWidget);

    const full = 'K7M2P-9QW4X-4TR8N'; // شكله سليم — ولا توكن بعد (F4.4)
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), full);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تفعيل ✓'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('غير معروف بعد'), findsOneWidget);

    // المحاولة السادسة: قفل ٥ دقائق (بعد الخامسة يبدأ الانتظار)
    await tester.enterText(find.byType(TextField), full);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pumpAndSettle();
    expect(find.textContaining('محاولات كثيرة'), findsOneWidget);

    // العدّاد محفوظ فعلاً بالمخزن
    final data = await license.load();
    expect(data.failures, 5);
  });

  testWidgets('F3.6: حسابي — شارة التجربة وإعادة الفحص بلا توكن',
      (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('حسابي'), findsOneWidget);
    expect(find.text('وضع تجريبي'), findsOneWidget);
    expect(find.textContaining('أنت بوضع التجربة'), findsOneWidget);

    await tester.tap(find.text('⟲ إعادة فحص التوقيع الآن'));
    await tester.pumpAndSettle();
    expect(find.text('لا توقيع محفوظ — أنت بوضع التجربة'), findsOneWidget);
  });

  testWidgets('F3.5: POE كامل — توقع ثم محاكاة ثم قياس وشرح', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    await tester.tap(find.byIcon(Icons.science_outlined)); // المختبر
    await tester.pumpAndSettle();

    // البوابة: النابض جاهز والبقية قيد الإعداد
    expect(find.text('النابض التوافقي'), findsOneWidget);
    await tester.tap(find.text('النابض التوافقي'));
    await tester.pumpAndSettle();

    // مرحلة التوقع إلزامية أولاً
    expect(find.text('توقع قبل التجريب'), findsOneWidget);
    expect(find.text('تشغيل ▶'), findsNothing);
    await tester.tap(find.text('يطول الدور T'));
    await tester.pumpAndSettle();

    // اسحب الكتلة أولاً — بدون سحب تبقى عند سكون x=0 ولا يتذبذب شيء
    await tester.drag(find.byKey(const Key('spring-canvas')),
        const Offset(40, 0));
    await tester.pumpAndSettle();
    // شغّل — pumpAndSettle ممنوعة مع تيكر يعمل (لا يهدأ أبداً)
    expect(find.text('تشغيل ▶'), findsOneWidget);
    await tester.tap(find.text('تشغيل ▶'));
    await tester.pump();
    // ٦ ثوانٍ: T≈1.99 ⇒ عبوران صاعدان على الأقل ⇒ دورتان مقيستان
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.textContaining('T المقيس'), findsOneWidget);

    // الشرح ظهر بعد القياس (ربط POE)
    expect(find.text('اشرح'), findsOneWidget);
  });

  testWidgets('F3.5: التحدي T=٢ث — الوصول بالأزرار ± والتسجيل مرة باليوم',
      (tester) async {
    final pack = _trainingPack();
    final store = InMemoryTrainingStore();
    await pumpTrainingApp(tester, pack: pack, store: store);
    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النابض التوافقي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('يقصر الدور T')); // أي توقع يمر
    await tester.pumpAndSettle();

    // الافتراضي m=1.0, k=10 ⇒ T≈1.9869 داخل النافذة أصلاً!
    expect(find.textContaining('تحقّق'), findsOneWidget);
    await tester.tap(find.text('سجّل التحدي (+١٠)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('سُجّل اليوم'), findsOneWidget);

    // الحالة محفوظة — إعادة فتح المختبر لا تعيد التسجيل
    final data = await store.load();
    expect(data.labChallengeDoneDateKey,
        dateKeyOf(DateTime.now()));

    await tester.pageBack(); // عودنا لبوابة المختبر (لا للمنهاج!)
    await tester.pumpAndSettle();
    await tester.tap(find.text('النابض التوافقي'));
    await tester.pumpAndSettle();
    // ⚠️ الشاشة الجديدة تبدأ ببوابة التوقع (طقس POE بكل جلسة) — بدّلها أولاً
    await tester.tap(find.text('لا يتغير T'));
    await tester.pumpAndSettle();
    // شارة الإنجاز تأتي من البيانات المخزنة لا من حالة الجلسة — جوهر الاختبار
    expect(find.text('سجّل التحدي (+١٠)'), findsNothing);
    expect(find.textContaining('سُجّل اليوم'), findsOneWidget);
  });

  testWidgets('F3.5: خروج النافذة عند تغيير m — الفحص حي', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النابض التوافقي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لا يتغير T'));
    await tester.pumpAndSettle();

    // داخل النافذة افتراضياً — زر m إيجابي مرتين: m=1.2 ⇒ T≈2.176 خارج
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('تحقّق'), findsNothing);
    expect(find.textContaining('اضبط m وk'), findsOneWidget);
  });

  testWidgets('F3.4: استئناف منتصف المراجعة — التالية لا المكررة', (tester) async {
    final pack = _trainingPack();
    await pumpTrainingApp(tester, pack: pack);
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة البطاقات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ مراجعة البطاقات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ما قانون هوك؟')); // كشف
    await tester.pumpAndSettle();
    await tester.tap(find.text('😎 أعرفها')); // الأولى تمت
    await tester.pumpAndSettle();
    await tester.pageBack(); // خروج منتصف المراجعة
    await tester.pumpAndSettle();

    await tester.tap(find.text('أكمل المراجعة'));
    await tester.pumpAndSettle();
    // الثانية مباشرة — لا عودة للأولى
    expect(find.text('وحدة ثابت النابض k؟'), findsOneWidget);
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
