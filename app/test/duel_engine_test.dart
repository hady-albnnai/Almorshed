// Run D — + duel_engine و_scope
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';

DuelScope get _scope =>
    const DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'test-pack-1');

void main() {
  test('Run D — _scope تُستهلك', () {
    expect(_scope().scopeString, contains('U1'));
    expect(scopeTagOf(_scope()), 2852);
  });
}
