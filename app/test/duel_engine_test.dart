// Run E5 — getter يحضر لكن scopeString لا تُلمس
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

DuelScope get _scope =>
    DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'test-pack-1');

void main() {
  test('E5 — getter بلا scopeString', () {
    expect(_scope().count, 10);
  });
}
