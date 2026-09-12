import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/lab/spring_sim.dart';

/// F3.5 — اختبارات نواة المحاكاة: دقة RK4 ضد الحل التحليلي + الحتمية
/// + فحص التحدي T=٢ث + قياس الدور من المسار (مرحلة «لاحظ»).

void main() {
  group('الدور النظري T = 2π√(m/k)', () {
    test('قيم معلومة', () {
      final p2 = math.pi * math.pi;
      expect(periodOf(1, p2), closeTo(2.0, 1e-12));
      expect(periodOf(4, p2), closeTo(4.0, 1e-12));
      expect(periodOf(1, 4 * p2), closeTo(1.0, 1e-12));
      expect(periodOf(2, 20), closeTo(1.9869, 1e-4));
    });
  });

  group('فحص التحدي «اجعل T = ٢ث» — نافذة ±0.05', () {
    test('داخل النافذة ✓ وخارجها ✗ (بما فيها الحدود)', () {
      final p2 = math.pi * math.pi;
      expect(challengeT2Ok(1, p2), isTrue); // T = 2.000
      expect(challengeT2Ok(2, 20), isTrue); // T ≈ 1.9869
      // k = 4π²/T² (من T = 2π√(m/k) مع m = 1)
      const fourPi2 = 4.0 * math.pi * math.pi;
      expect(challengeT2Ok(1, 2.435), isFalse); // T ≈ 4.03 — بعيدة كل البعد
      expect(challengeT2Ok(1, fourPi2 / (2.05 * 2.05)), isTrue); // T = 2.05 حد
      expect(challengeT2Ok(1, fourPi2 / (2.06 * 2.06)), isFalse); // T = 2.06
      expect(challengeT2Ok(1, fourPi2 / (1.95 * 1.95)), isTrue); // T = 1.95 حد
      expect(challengeT2Ok(1, fourPi2 / (1.94 * 1.94)), isFalse); // T = 1.94
    });
  });
}
