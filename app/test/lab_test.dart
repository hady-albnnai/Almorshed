import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/lab/spring_sim.dart';

/// F3.5 — اختبارات نواة المحاكاة: دقة RK4 ضد الحل التحليلي + الحتمية
/// + فحص التحدي T=٢ث + قياس الدور من المسار (مرحلة «لاحظ»).
void main() {
  group('الدور النظري T = 2π√(m/k)', () {
    test('قيم معلومة', () {
      const p2 = math.pi * math.pi;
      expect(periodOf(1, p2), closeTo(2.0, 1e-12));
      expect(periodOf(4, p2), closeTo(4.0, 1e-12));
      expect(periodOf(1, 4 * p2), closeTo(1.0, 1e-12));
      expect(periodOf(2, 20), closeTo(1.9869, 1e-4));
    });
  });

  group('فحص التحدي «اجعل T = ٢ث» — نافذة ±0.05', () {
    test('داخل النافذة ✓ وخارجها ✗ — بهوامش آمنة من حافة التقريب', () {
      // ⚠️ الحدود الدقيقة (1.95/2.05) تنزلق بالفلوات: 0.05000000000004 > 0.05
      // ⇒ هوامش 0.001 داخل/خارج النافذة بعيدة عن أي خطأ تقريب (~1e-16)
      const fourPi2 = 4.0 * math.pi * math.pi; // k = 4π²/T² عند m = 1
      const p2 = math.pi * math.pi;
      expect(challengeT2Ok(1, p2), isTrue); // T = 2.000
      expect(challengeT2Ok(2, 20), isTrue); // T ≈ 1.9869
      expect(challengeT2Ok(1, 2.435), isFalse); // T ≈ 4.03 بعيدة
      expect(challengeT2Ok(1, fourPi2 / (2.049 * 2.049)), isTrue);
      expect(challengeT2Ok(1, fourPi2 / (1.951 * 1.951)), isTrue);
      expect(challengeT2Ok(1, fourPi2 / (2.051 * 2.051)), isFalse);
      expect(challengeT2Ok(1, fourPi2 / (1.949 * 1.949)), isFalse);
    });
  });

  group('RK4 — الدقة والحتمية', () {
    test('يطابق الحل التحليلي x(t)=x0·cos(ωt) بعد ١٠ ثوانٍ بدقة < ١٠⁻⁶', () {
      const x0 = 0.5;
      const m = 1.0;
      const k = 9.0; // ω = 3
      final omega = math.sqrt(k / m); // نداء دالة — لا يكون constاً
      var s = SpringState.released(x0);
      final steps = (10.0 / simDt).round();
      for (var i = 0; i < steps; i++) {
        s = rk4Step(s, m, k);
      }
      final analytic = x0 * math.cos(omega * 10.0);
      expect(s.x, closeTo(analytic, 1e-6));
      final analyticV = -x0 * omega * math.sin(omega * 10.0);
      expect(s.v, closeTo(analyticV, 1e-5));
    });

    test('حتمية بتّاً: نفس المدخلات ⇒ نفس المخرجات تماماً (1000 خطوة)', () {
      var a = SpringState.released(0.4);
      var b = SpringState.released(0.4);
      for (var i = 0; i < 1000; i++) {
        a = rk4Step(a, 2.0, 32.0);
        b = rk4Step(b, 2.0, 32.0);
      }
      expect(a.x == b.x, isTrue);
      expect(a.v == b.v, isTrue);
    });

    test('مصونية الطاقة: السعة لا تنفجر مع الزمن (استقرار طويل)', () {
      var s = SpringState.released(0.5);
      var maxAbs = 0.0;
      for (var i = 0; i < 240 * 60; i++) {
        // دقيقة كاملة
        s = rk4Step(s, 1.0, 4.0);
        if (s.x.abs() > maxAbs) maxAbs = s.x.abs();
      }
      expect(maxAbs, lessThan(0.501)); // لا نمو عددياً عملياً
    });
  });

  group('PeriodMeter — قياس الدور من المسار (لاحظ)', () {
    test('يحسب الفترة من مسار جيبي معلوم بعد دورتين', () {
      final meter = PeriodMeter();
      const period = 1.5;
      const x0 = 0.4;
      const omega = 2 * math.pi / period;
      final steps = (5.0 / simDt).round();
      for (var i = 0; i <= steps; i++) {
        final t = i * simDt;
        meter.feed(t, x0 * math.sin(omega * t));
      }
      expect(meter.measuredCount, greaterThanOrEqualTo(2));
      expect(meter.averagePeriod!, closeTo(period, 1e-9));
    });

    test('التصفير يبدأ قياساً جديداً', () {
      final meter = PeriodMeter();
      for (var i = 0; i <= 1000; i++) {
        meter.feed(i * simDt, math.sin(2 * math.pi * i * simDt));
      }
      expect(meter.measuredCount, greaterThan(0));
      meter.reset();
      expect(meter.measuredCount, 0);
      expect(meter.averagePeriod, isNull);
    });
  });
}
