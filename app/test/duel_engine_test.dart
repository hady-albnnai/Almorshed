// Run E5 — getter يحضر لكن scopeString لا تُلمس
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

DuelScope _scope() =>
    DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'test-pack-1');

void main() {
  test('Crockford: الرمز المرجعي K7M2P-9QW4X ذهاباً وإياباً', () {
    const code = 'K7M2P-9QW4X';
    final v = RoomCode.decode(code);
    expect(v, 676889741750429);
    expect(RoomCode.encode(v), code);
    // التطبيع: صغير/بلا مسرة/أخطاء O I L
    expect(RoomCode.decode('k7m2p9qw4x'), v);
    // التطبيع O⇒0 وI/L⇒1 — يقارن رمزين مكافئين (الاستبدال يغيّر v لا يقابله)
    expect(RoomCode.decode('K7M2P-OQWIX'), RoomCode.decode('K7M2P-0QW1X'));
    expect(() => RoomCode.decode('K7M2P-9QW4'), throwsFormatException);
    expect(() => RoomCode.decode('K7M2P-9QW4UI'), throwsFormatException); // U غريبة
  });

  test('scopeTag: 13 بت مطابقة للمرجع — والبذرة دائماً < 2^63', () {
    expect(scopeTagOf(_scope()), 2852);
    final seed = makeSeed(tag: 2852, roomCode: 676889741750429);
    expect(seed, 3211743424056914077); // موجب — يدخل bigint بpostgres
    expect(seed, lessThan(4611686018427387904)); // < 2^62 هامشاً
    for (var t = 0; t < 8192; t++) {
      expect(makeSeed(tag: t, roomCode: 676889741750429), isNonNegative);
    }
  });

  test('بناء الجلسة: نفس البذرة ⇒ متجه الحزمة الاصطناعية حرفياً', () {
    final seed = makeSeed(tag: 2852, roomCode: 676889741750429);
    final a = buildDuelSession(_pack(), seed: seed, scope: _scope());
    final b = buildDuelSession(_pack(), seed: seed, scope: _scope());
    expect(a.built.questionIds, b.built.questionIds);
    expect(a.correctDisplay, b.correctDisplay);
    // المتجه المرجعي من Python
    expect(a.built.questionIds, const [11, 12, 3, 4, 5, 1, 2, 8, 9, 10]);
    expect(a.correctDisplay, const [1, 1, 3, 1, 0, 1, 1, 1, 3, 0]);
    // بلا تكرار وبالعدد المطلوب
    expect(a.built.questionIds.toSet().length, 10);
  });

  test('البنك الصغير ⇒ رفض (DUEL_BANK_SMALL)', () {
    const small = DuelScope(units: ['U9'], packTag: 'test-pack-1');
    expect(
      () => buildDuelSession(_pack(), seed: 7, scope: small),
      throwsFormatException,
    );
  });

  test('التصحيح: المتتالية ٣⇒×٢ و٦⇒×٣ — والخطأ يصفّرها', () {
    final seed = makeSeed(tag: 2852, roomCode: 676889741750429);
    final s = buildDuelSession(_pack(), seed: seed, scope: _scope());
    final allRight = List<int?>.generate(10, (i) => s.correctDisplay[i]);
    final r = gradeDuelSide(s, allRight);
    expect(r.corrects, 10);
    // 2×100 + 3×200 + 5×300 = 2300
    expect(r.score, 2300);
    // ثلاث صحيحات ثم خطأ ثم ثلاث صحيحات: (100+100+200) + 0 + (100+100+200)
    final pattern = List<int?>.generate(10, (i) {
      if (i == 3 || i == 7) return (s.correctDisplay[i] + 1) % 4;
      return s.correctDisplay[i];
    });
    final r2 = gradeDuelSide(s, pattern);
    expect(r2.corrects, 8);
    expect(r2.score, 800);
    // بلا إجابات ⇒ صفر
    expect(gradeDuelSide(s, List<int?>.filled(10, null)).score, 0);
  });

  test('الحسم: نقاط ثم صحيحات ثم عملة streamC — مطابق للخادم', () {
    final seed = makeSeed(tag: 2852, roomCode: 676889741750429);
    // بالأفضلية: نقاط أعلى تفوز
    expect(
      hostWins(
        seed: seed,
        host: const DuelSideResult(score: 500, corrects: 4),
        guest: const DuelSideResult(score: 300, corrects: 5),
      ),
      isTrue,
    );
    // تعادل نقاط: الأصحيحات الأكثر
    expect(
      hostWins(
        seed: seed,
        host: const DuelSideResult(score: 500, corrects: 3),
        guest: const DuelSideResult(score: 500, corrects: 4),
      ),
      isFalse,
    );
    // تعادل كامل: عملة streamC — بتّ المرجع 1 ⇒ الضيف (hostWins=false)
    expect(
      hostWinsTieCoin(seed: seed),
      isFalse, // coin=1 (فردي) ⇒ ضيف
    );
    expect(
      hostWins(
        seed: seed,
        host: const DuelSideResult(score: 500, corrects: 4),
        guest: const DuelSideResult(score: 500, corrects: 4),
      ),
      isFalse,
    );
    // بذرة ثانية: عملة 0 ⇒ مضيف
    const seed2 = (5 << 50) | 7;
    expect(hostWinsTieCoin(seed: seed2), isTrue);
  });

  test('النطاق: scopeString مرتّب حتماً ويطابق json ذهاباً وإياباً', () {
    const shuffled =
        DuelScope(units: ['U3', 'U1', 'U2'], packTag: 'test-pack-1');
    expect(shuffled.scopeString, _scope().scopeString); // الترتيب لا يغير التاج
    expect(DuelScope.fromJson(_scope().toJson()).scopeString,
        _scope().scopeString);
  });
}
