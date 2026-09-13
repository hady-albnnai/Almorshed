// M4-جيب — حلقة مراجعة الأخطاء (mistakesFive): الخامسة اليوم = +١٠ مرة
// وحدة (السقف يحمي) + الدوران بالأرشيف + منع التكرار بنفس اليوم.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/training/training_store.dart';
import 'package:fizya_clash/core/xp/streak_service.dart';
import 'package:fizya_clash/features/training/mistakes_screen.dart';


TrainingStore _storeWith(int n, {List<int>? reviewedTodayIdx}) {
  final mistakes = <MistakeRecord>[
    for (var i = 0; i < n; i++)
      MistakeRecord(
        questionId: 500 + i,
        chosenIndex: 0,
        correctIndex: 1,
        atMs: reviewedTodayIdx != null && reviewedTodayIdx.contains(i)
            ? DateTime.now().millisecondsSinceEpoch // مراجع اليوم (الوقت الحقيقي)
            : DateTime.now().millisecondsSinceEpoch - 3 * 86400000,
      ),
  ];
  final store = InMemoryTrainingStore();
  store.save(TrainingData(mistakes: mistakes));
  return store;
}

ContentPack _packOf(List<int> ids) => ContentPack.fromJsonString('''
{"packId":"t","year":2027,"edition":1,"units":[],
 "questions":[${ids.map((id) => '{"id":$id,"unit":"U1","chapter":"U1C1","stem":"س$id","options":["أ","ب","ج","د"],"correctIndex":1}').join(",")}]}
''');

Future<void> _pump(WidgetTester tester,
    {required TrainingStore store, required ContentPack pack}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final recorder = XpRecorder.inMemory();
  await tester.pumpWidget(MaterialApp(
    home: MistakesScreen(
      pack: pack,
      trainingStore: store,
      xpRecorder: recorder,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> _driveFive(WidgetTester tester, TrainingStore store,
      ContentPack pack, XpRecorder recorder) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: MistakesScreen(
            pack: pack, trainingStore: store, xpRecorder: recorder)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('فهمت ✓').first);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('أ-التقدم والسناك', (tester) async {
    final store = _storeWith(6);
    await _driveFive(tester, store, _packOf([500, 501, 502, 503, 504, 505]),
        XpRecorder.inMemory());
    expect(find.textContaining('راجعت ٥ من ٥'), findsOneWidget);
    expect(find.textContaining(r'\+١٠'), findsOneWidget);
  });

  testWidgets('ب-الدفتر: حدث واحد بـ١٠ نقاط', (tester) async {
    final store = _storeWith(6);
    final recorder = XpRecorder.inMemory();
    await _driveFive(tester, store, _packOf([500, 501, 502, 503, 504, 505]),
        recorder);
    final events = await recorder.ledger.events();
    final five = events.where((e) => e.type == 'mistakesFive').toList();
    expect(five.length, 1);
    expect(five.single.payload['points'], 10);
  });

  testWidgets('ج-الدوران بالأرشيف + لا مكافأة سادسة', (tester) async {
    final store = _storeWith(6);
    final recorder = XpRecorder.inMemory();
    final pack = _packOf([500, 501, 502, 503, 504, 505]);
    await _driveFive(tester, store, pack, recorder);
    final after = (await store.load()).mistakes;
    expect(after.first.questionId, 504);
    expect(after.last.questionId, 505);
    await tester.tap(find.text('فهمت ✓').first);
    await tester.pumpAndSettle();
    final events2 = await recorder.ledger.events();
    expect(events2.where((e) => e.type == 'mistakesFive').length, 1);
  });

  testWidgets('مراجَع اليوم يظهر «رُوجع اليوم ✓» بلا زر', (tester) async {
    final store = _storeWith(2, reviewedTodayIdx: [0]);
    await _pump(tester,
        store: store, pack: _packOf([500, 501]));
    expect(find.text('رُوجع اليوم ✓'), findsOneWidget);
    expect(find.text('فهمت ✓'), findsOneWidget); // الثاني فقط
    expect(find.textContaining('راجعت ١ من ٥'), findsOneWidget);
  });

  testWidgets('أرشيف فارغ ⇒ لا شريط ولا أزرار', (tester) async {
    final store = _storeWith(0);
    await _pump(tester, store: store, pack: _packOf([]));
    expect(find.text('لا أخطاء محفوظة — واصل التدريب!'), findsOneWidget);
    expect(find.textContaining('راجعت'), findsNothing);
  });
}
