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

}
