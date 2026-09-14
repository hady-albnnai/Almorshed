// Run D4 — إنشاء DuelScope بلا scopeString
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

void main() {
  test('D4 — إنشاء فقط', () {
    final s = DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'test-pack-1');
    expect(s.count, 10);
    expect(s.units.length, 3);
  });
}
