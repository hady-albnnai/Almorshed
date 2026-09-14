// Run D3 — getter بلا const
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

DuelScope get _scope =>
    DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'test-pack-1');

void main() {
  test('D3 — getter بلا const', () {
    expect(_scope().scopeString, contains('U1'));
  });
}
