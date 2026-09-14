// Run D1 — استيراد المحرك + رمز بسيط
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

void main() {
  test('D1 — رموز ثابتة', () {
    expect(DuelConstants.count, 10);
    expect(DuelConstants.pointsPerCorrect, 100);
  });
}
