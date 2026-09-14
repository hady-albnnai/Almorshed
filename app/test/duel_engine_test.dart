// Run D4 — إنشاء DuelScope بلا scopeString
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

void main() {
  test('G1 — البنية تُستهلك بحد أدنى', () {
    expect(_pack().questions.length, 15);
    expect(_scope().count, 10);
  });
}
