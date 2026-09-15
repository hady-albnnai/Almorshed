import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/challenge/challenge_builder.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/xp/challenge_points.dart';
import 'package:fizya_clash/core/xp/streak_service.dart';

// A5 — تحدي اليوم (قرار ٦٠): النقاط التناقصية + حتمية التحدي + المغادرة.
//
// أخطر ما يُختبر هنا: تطابق دالة النقاط بين الطرفين. السيرفر يعيد حسابها
// (supabase/functions/verify_xp_events/index.ts) ويرفض الدفعة كلها عند أي
// فرق ⇒ هذه الاختبارات هي عقد التطابق لا مجرد حساب.
// (تعليق بـ// لا /// عن قصد: التعليق التوثيقي المعلّق = info فادح بالبوابة.)

Question _q(int id, String chapter, {bool approved = true}) => Question(
      id: id,
      unit: 'U1',
      chapter: chapter,
      approved: approved,
      stem: 'متن السؤال $id',
      options: ['أ ($id)', 'ب ($id)', 'ج ($id)', 'د ($id)'],
      correctIndex: 1,
      solutionSteps: const ['الخطوة الأولى', 'الخطوة الثانية'],
      followThrough: const [],
    );

ContentPack _packWith(List<Question> qs) => ContentPack(
      packId: 't',
      year: 2027,
      edition: 1,
      units: const [
        Unit(
          id: 'U1',
          title: 'وحدة',
          chapters: [
            Chapter(id: 'A', title: 'فصل أ', page: 1, paragraphs: []),
            Chapter(id: 'B', title: 'فصل ب', page: 2, paragraphs: []),
          ],
        ),
      ],
      questions: qs,
      cards: const [],
    );

void main() {
  group('النقاط التناقصية — الدالة الحتمية (عقد التطابق مع السيرفر)', () {
    test('إجابة فورية = base — وآخر لحظة = min', () {
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: 0), 12);
      expect(
          challengePoints(
              kind: kChallengeMcq, elapsedMs: kChallengeMcq.budgetMs - 1),
          4); // min
    });

    test('انتهاء الوقت أو زمن سالب ⇒ ٠ («لا نقاط بلا إجابة صحيحة»)', () {
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: 22000), 0);
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: 999999), 0);
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: -5), 0);
    });

    test('متناقصة رتيباً مع الزمن — ولا تتجاوز base أبداً', () {
      var prev = 1 << 30;
      for (var t = 0; t <= 22000; t += 250) {
        final p = challengePoints(kind: kChallengeMcq, elapsedMs: t);
        expect(p, lessThanOrEqualTo(prev));
        expect(p, lessThanOrEqualTo(kChallengeMcq.base));
        expect(p, greaterThanOrEqualTo(0));
        prev = p;
      }
    });

    test('متجهات ذهبية — نفسها حرفياً على السيرفر (TS Math.trunc)', () {
      // mcq: ١٢ / ٤ / ٢٢٠٠٠
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: 11000), 8);
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: 5500), 10);
      expect(challengePoints(kind: kChallengeMcq, elapsedMs: 21999), 4);
      // numeric: ٣٠ / ١٠ / ٩٠٠٠٠
      expect(challengePoints(kind: kChallengeNumeric, elapsedMs: 0), 30);
      expect(challengePoints(kind: kChallengeNumeric, elapsedMs: 45000), 20);
      expect(challengePoints(kind: kChallengeNumeric, elapsedMs: 89999), 10);
      // step: ١٨ / ٦ / ٤٠٠٠٠
      expect(challengePoints(kind: kChallengeStep, elapsedMs: 20000), 12);
    });

    test('الأصناف الثلاثة بمعرفاتها — والمجهول null', () {
      expect(challengeKindOf('mcq'), kChallengeMcq);
      expect(challengeKindOf('step'), kChallengeStep);
      expect(challengeKindOf('numeric'), kChallengeNumeric);
      expect(challengeKindOf('freeText'), isNull);
    });
  });

  group('حتمية التحدي — مرة واحدة كل يوم', () {
    final pack = _packWith([
      for (var i = 1; i <= 6; i++) _q(200 + i, i.isEven ? 'B' : 'A'),
    ]);

    test('المعرّف بصيغة UUID وحتمي من (الجهاز ⊕ اليوم)', () {
      final a = challengeIdFor(deviceId: 7, dateKey: '2026-09-12');
      final b = challengeIdFor(deviceId: 7, dateKey: '2026-09-12');
      final c = challengeIdFor(deviceId: 7, dateKey: '2026-09-13');
      final d = challengeIdFor(deviceId: 8, dateKey: '2026-09-12');
      expect(a, b); // ثبات إعادة الفتح
      expect(a, isNot(c)); // يوم جديد = تحدي جديد
      expect(a, isNot(d)); // جهاز آخر = تحدي آخر
      // صيغة UUID 8-4-4-4-12 — يرفضها السيرفر بـ CHALLENGE_ID_FORMAT إن خالفت
      expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
              .hasMatch(a),
          isTrue);
    });

    test('نفس اليوم ⇒ نفس الأسئلة ونفس ترتيب الخيارات', () {
      final c1 = buildDailyChallenge(pack, dateKey: '2026-09-12', deviceId: 7);
      final c2 = buildDailyChallenge(pack, dateKey: '2026-09-12', deviceId: 7);
      expect(c1, isNotNull);
      expect(c1!.session.questionIds, c2!.session.questionIds);
      expect(c1.session.optionOrders, c2.session.optionOrders);
      expect(c1.id, c2.id);
    });

    test('يوم آخر ⇒ ترتيب مختلف (ضد حفظ الأسئلة)', () {
      final c1 = buildDailyChallenge(pack, dateKey: '2026-09-12', deviceId: 7);
      final c2 = buildDailyChallenge(pack, dateKey: '2026-09-13', deviceId: 7);
      expect(c1!.session.questionIds, isNot(c2!.session.questionIds));
    });

    test('المعتمد حصراً — وبنك فارغ ⇒ null', () {
      final none = _packWith([
        _q(301, 'A', approved: false),
        _q(302, 'B', approved: false),
      ]);
      expect(buildDailyChallenge(none, dateKey: '2026-09-12'), isNull);
    });
  });

  group('المُسجّل — الأحداث التنافسية وقراءة الدرس', () {
    test('إجابة صحيحة: النقاط من الدالة الحتمية + الحمولة كاملة', () async {
      final r = XpRecorder.inMemory();
      final ok = await r.recordChallenge(
        challengeId: '11111111-2222-3333-4444-555555555555',
        qIndex: 0,
        qType: 'mcq',
        elapsedMs: 11000,
        now: DateTime(2026, 9, 12, 18),
      );
      expect(ok, isTrue);
      final events = await r.ledger.events();
      final e = events.firstWhere((x) => x.type == 'challengeQ');
      expect(e.payload['points'], 8); // challengePoints(mcq, 11000)
      expect(e.payload['challengeId'], '11111111-2222-3333-4444-555555555555');
      expect(e.payload['qIndex'], 0);
      expect(e.payload['qType'], 'mcq');
      expect(e.payload['elapsedMs'], 11000);
      // التحدي يُشعل السلسلة (نشاط بإجابة صحيحة) + نقاطه تدخل الترتيب
      expect(events.any((x) => x.type == 'streakDay'), isTrue);
      expect(await r.ledger.arenaTotalXp(), 8);
    });

    test('صنف مجهول ⇒ رفض بلا حدث', () async {
      final r = XpRecorder.inMemory();
      final ok = await r.recordChallenge(
        challengeId: '11111111-2222-3333-4444-555555555555',
        qIndex: 0,
        qType: 'freeText',
        elapsedMs: 100,
      );
      expect(ok, isFalse);
      expect(await r.ledger.events(), isEmpty);
    });

    test('المغادرة: ٠ نقطة + إقفال التحدي محلياً', () async {
      final r = XpRecorder.inMemory();
      const cid = '11111111-2222-3333-4444-555555555555';
      expect(await r.ledger.challengeStarted(cid), isFalse);
      expect(await r.recordChallengeAbandon(
            challengeId: cid,
            reason: 'مغادرة التطبيق',
          ),
          isTrue);
      expect(await r.ledger.challengeStarted(cid), isTrue);
      // إعادة فتح التطبيق: الشاشة تعرض «أنهيت تحدي اليوم» ولا تعيد النقاط
      final fresh = XpRecorder.inMemory();
      expect(await fresh.ledger.challengeStarted(cid), isFalse);
      expect(await r.ledger.arenaTotalXp(), 0);
    });

    test('challengeStarted يرى بدايةً بالنقاط أيضاً', () async {
      final r = XpRecorder.inMemory();
      const cid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      await r.recordChallenge(
        challengeId: cid,
        qIndex: 3,
        qType: 'mcq',
        elapsedMs: 0,
      );
      expect(await r.ledger.challengeStarted(cid), isTrue);
    });
  });

  group('فصل النقاط — تعلّم شخصي ↔ ترتيب تنافسي (قرار ٦٠)', () {
    test('نقاط التدريب لا تدخل الترتيب، ونقاط التحدي تدخل', () async {
      final r = XpRecorder.inMemory();
      final now = DateTime(2026, 9, 12, 18);
      await r.record('batchDone', now: now); // تعلّم ١٥
      await r.record('cardReview', now: now); // تعلّم ١
      await r.recordChallenge(
        challengeId: '11111111-2222-3333-4444-555555555555',
        qIndex: 0,
        qType: 'mcq',
        elapsedMs: 0,
        now: now,
      ); // تنافسي ١٢
      await r.record('duelWin', now: now); // تنافسي ٤٥
      final total = await r.ledger.totalXp();
      final arena = await r.ledger.arenaTotalXp();
      // ١٥ + ١٠ (سلسلة) + ١ + ١٢ + ٤٥ = ٨٣
      expect(total, 83);
      // الترتيب: ١٢ + ٤٥ فقط = ٥٧
      expect(arena, 57);
      expect(arena, lessThan(total));
    });

    test('خسارة المبارزة صفر ولا تزيد الترتيب', () async {
      final r = XpRecorder.inMemory();
      await r.record('duelLoss', now: DateTime(2026, 9, 12, 18));
      expect(await r.ledger.arenaTotalXp(), 0);
    });
  });
}
