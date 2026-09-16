import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/lab/experiments.dart';
import 'package:fizya_clash/core/lab/spring_sim.dart';

/// المادة ١٤ — نوى التجارب الخمس: القوانين، RK4، الحتمية، والتحدّيات.
void main() {
  group('السجل', () {
    test('خمس تجارب بمعرّفات الحزمة وفصولها الصحيحة', () {
      expect(labExperiments.keys.toList(),
          ['torsion', 'gravity', 'lc', 'string', 'photo']);
      expect(labExperiments['torsion']!.chapterId, 'U1C2');
      expect(labExperiments['gravity']!.chapterId, 'U1C3');
      expect(labExperiments['lc']!.chapterId, 'U2C4');
      expect(labExperiments['string']!.chapterId, 'U3C1');
      expect(labExperiments['photo']!.chapterId, 'U4C3');
    });

    test('كل تجربة: توقّع بثلاثة خيارات ومؤشر صحيح داخل النطاق وتحدٍّ',
        () {
      for (final e in labExperiments.values) {
        expect(e.prediction.options.length, 3, reason: e.id);
        expect(e.prediction.correct, inInclusiveRange(0, 2), reason: e.id);
        expect(e.challenge, isNotNull, reason: e.id);
        expect(e.params, isNotEmpty, reason: e.id);
        // الافتراضيات داخل النطاق وعلى الشبكة
        for (final p in e.params) {
          expect(p.initial, inInclusiveRange(p.min, p.max), reason: p.id);
          expect(p.clampSnap(p.initial), p.initial, reason: p.id);
        }
      }
    });

    test('المصطلحات المحظورة (glossary banned) لا تظهر في نصوص التجارب', () {
      const banned = ['الزنبرك', 'الذبذبة', 'عزم القصور', 'التأثير الكهروضوئي',
        'الموجة الموقوفة', 'الفيض المغناطيسي'];
      for (final e in labExperiments.values) {
        final blob = [
          e.title, e.law, e.prediction.question, ...e.prediction.options,
          e.prediction.afterText, e.challenge!.title, e.challenge!.hint,
          e.explain(e.initialParams, 1.0, 1.0),
          for (final p in e.params) p.label,
        ].join(' ');
        for (final b in banned) {
          expect(blob.contains(b), isFalse, reason: '${e.id} يحوي «$b»');
        }
      }
    });
  });

  group('LabParam.clampSnap', () {
    test('يثبّت على الشبكة ويحصر بالنطاق', () {
      const p = LabParam(
          id: 'x', label: 'x', unit: '', min: 0.2, max: 1.0, step: 0.05,
          initial: 0.5, decimals: 2);
      expect(p.clampSnap(0.53), 0.55);
      expect(p.clampSnap(0.0), 0.2);
      expect(p.clampSnap(7.0), 1.0);
      expect(p.clampSnap(0.5), 0.5);
    });
  });

  group('١) نواس الفتل — T0 = 2π√(IΔ/C)', () {
    const e = TorsionExperiment();
    test('IΔ الساق = mL²/12 والدور النظري', () {
      final p = {'m': 0.6, 'L': 0.5, 'C': 0.05};
      expect(TorsionExperiment.inertia(p), closeTo(0.0125, 1e-12));
      expect(e.period(p), closeTo(2 * math.pi * math.sqrt(0.25), 1e-9));
    });
    test('مضاعفة L تضاعف الدور (التوقع الصحيح = ٢)', () {
      final p1 = {'m': 0.6, 'L': 0.5, 'C': 0.05};
      final p2 = {'m': 0.6, 'L': 1.0, 'C': 0.05};
      expect(e.period(p2) / e.period(p1), closeTo(2.0, 1e-9));
      expect(e.prediction.correct, 2);
    });
    test('RK4 يعيد القياس النظري بدقة ‰ — والافتراضي خارج نافذة التحدي', () {
      final p = e.initialParams;
      expect(e.challenge!.ok(e.challengeValue(p)), isFalse);
      final measured = _measure(e, p, q0: 0.5);
      expect(measured, closeTo(e.period(p), 0.006));
      // C = 0.12 ⇒ T0 ≈ 2.03 داخل ±0.05
      final p2 = {...p, 'C': 0.12};
      expect(e.challenge!.ok(e.challengeValue(p2)), isTrue);
    });
  });

  group('٢) النواس الثقلي — T0 = 2π√(l/g) في السعات الصغيرة', () {
    const e = GravityPendulumExperiment();
    test('الكتلة لا تدخل والدور مع g = 10، l = 1 ⇒ ≈ 1.987', () {
      final a = {'l': 1.0, 'g': 10.0, 'm': 0.2};
      final b = {'l': 1.0, 'g': 10.0, 'm': 2.0};
      expect(e.period(a), e.period(b));
      expect(e.period(a), closeTo(1.9869, 1e-3));
      expect(e.prediction.correct, 1);
    });
    test('سعة صغيرة ⇒ قياس ≈ نظري؛ سعة كبيرة (80°) ⇒ يطول ~١٠٪', () {
      final p = {'l': 1.0, 'g': 10.0, 'm': 0.2};
      final small = _measure(e, p, q0: 0.1);
      expect(small, closeTo(e.period(p), 0.006));
      final big = _measure(e, p, q0: 1.4);
      expect(big / e.period(p), greaterThan(1.08));
      expect(big / e.period(p), lessThan(1.20));
    });
    test('نواس الثواني: l = 1.0 يحقق التحدي، الافتراضي 0.6 لا', () {
      expect(e.challenge!.ok(e.challengeValue(e.initialParams)), isFalse);
      expect(e.challenge!.ok(e.challengeValue({'l': 1.0, 'g': 10.0, 'm': 0.2})),
          isTrue);
    });
  });

  group('٣) الدارة المهتزّة — طومسون T0 = 2π√(LC)', () {
    const e = LcCircuitExperiment();
    test('10 mH × 10 μF ⇒ 1.987 ms؛ ٤ أمثال C ⇒ ضعف الدور', () {
      final p = {'L': 10.0, 'C': 10.0};
      expect(e.toDisplay(e.period(p)), closeTo(1.9869, 1e-3));
      expect(e.periodUnit, 'ms');
      final p4 = {'L': 10.0, 'C': 40.0};
      expect(e.period(p4) / e.period(p), closeTo(2.0, 1e-9));
      expect(e.prediction.correct, 1);
    });
    test('RK4 بالزمن المبطّأ يطابق النظري؛ الافتراضي خارج النافذة', () {
      expect(e.challenge!.ok(e.challengeValue(e.initialParams)), isFalse);
      final p = {'L': 10.0, 'C': 10.0};
      expect(e.challenge!.ok(e.challengeValue(p)), isTrue);
      final measured = _measure(e, p, q0: 1.0);
      expect(measured, closeTo(e.period(p), 0.006));
    });
  });

  group('٤) الوتر المشدود — fn = (n/2L)√(FT/μ)', () {
    const e = StringWaveExperiment();
    test('v = √(FT/μ)، f1 = v/2L، وعدد المغازل عند الطنين', () {
      final p = {'f': 50.0, 'FT': 16.0, 'L': 1.0, 'mu': 4.0};
      expect(StringWaveExperiment.speed(p), closeTo(63.246, 1e-3));
      expect(StringWaveExperiment.fundamental(p), closeTo(31.623, 1e-3));
      expect(StringWaveExperiment.spindles(p), isNull); // 50 ليس مدروجاً
      final p2 = {...p, 'f': 63.0};
      expect(StringWaveExperiment.spindles(p2), 2);
      final p3 = {...p, 'f': 95.0};
      expect(StringWaveExperiment.spindles(p3), 3);
      expect(e.challenge!.ok(e.challengeValue(p3)), isTrue);
      expect(e.challenge!.ok(e.challengeValue(p2)), isFalse);
    });
    test('٤ أمثال الشد ⇒ نصف عدد المغازل (التوقع الصحيح = ٠)', () {
      final p = {'f': 63.0, 'FT': 16.0, 'L': 1.0, 'mu': 4.0};
      expect(StringWaveExperiment.spindles(p), 2);
      expect(StringWaveExperiment.spindles({...p, 'FT': 64.0}), 1);
      expect(e.prediction.correct, 0);
    });
    test('دور الهزّاز بوحدة المحاكاة (١٠ ms) والقياس RK4', () {
      final p = {'f': 50.0, 'FT': 16.0, 'L': 1.0, 'mu': 4.0};
      expect(e.toDisplay(e.period(p)), closeTo(20.0, 1e-9)); // 1/50 s = 20 ms
      final measured = _measure(e, p, q0: 1.0);
      expect(measured, closeTo(e.period(p), 0.006));
    });
  });

  group('٥) الفعل الكهرضوئي — Ek = hf − Ws', () {
    const e = PhotoelectricExperiment();
    test('البوتاسيوم Ws = 2.2 eV ⇒ λ0 ≈ 565 nm، و450 nm ⇒ Ek ≈ 0.56 eV', () {
      final p = {'lambda': 450.0, 'Ws': 2.2, 'P': 3.0};
      expect(PhotoelectricExperiment.photonEv(p), closeTo(2.763, 2e-3));
      expect(PhotoelectricExperiment.ekEv(p), closeTo(0.563, 2e-3));
      expect(PhotoelectricExperiment.thresholdNm(p), closeTo(565.1, 0.5));
      expect(PhotoelectricExperiment.emits(p), isTrue);
    });
    test('فوق العتبة لا انتزاع مهما زادت الاستطاعة (التوقع الصحيح = ١)', () {
      final p = {'lambda': 600.0, 'Ws': 2.2, 'P': 0.5};
      expect(PhotoelectricExperiment.emits(p), isFalse);
      expect(PhotoelectricExperiment.ekEv(p), 0.0);
      expect(PhotoelectricExperiment.emits({...p, 'P': 10.0}), isFalse);
      expect(e.prediction.correct, 1);
      expect(e.hasDynamics, isFalse);
    });
    test('التحدي Ek = 1 eV ± 0.1: λ = 390 nm يحققه والافتراضي لا', () {
      expect(e.challenge!.ok(e.challengeValue(e.initialParams)), isFalse);
      final p = {'lambda': 390.0, 'Ws': 2.2, 'P': 3.0};
      expect(PhotoelectricExperiment.ekEv(p), closeTo(0.98, 0.02));
      expect(e.challenge!.ok(e.challengeValue(p)), isTrue);
    });
    test('عدد الفوتونات N = P/E (مثال النوطة: 3 mW عند 400 nm ≈ 6×10¹⁵)', () {
      final p = {'lambda': 400.0, 'Ws': 2.2, 'P': 3.0};
      expect(PhotoelectricExperiment.photonsPerSecond(p) / 1e15,
          closeTo(6.03, 0.05));
    });
  });

  group('الحتمية', () {
    test('نفس المعاملات ونفس السحب ⇒ نفس المسار بتّاً على كل تجربة', () {
      for (final e in labExperiments.values) {
        if (!e.hasDynamics) continue;
        var a = OscState(e.maxInitial * 0.5, 0);
        var b = OscState(e.maxInitial * 0.5, 0);
        for (var i = 0; i < 1000; i++) {
          a = e.step(a, e.initialParams);
          b = e.step(b, e.initialParams);
        }
        expect(a.q, b.q, reason: e.id);
        expect(a.dq, b.dq, reason: e.id);
      }
    });
  });
}

/// يقيس الدور بعدّاد النابض نفسه: تكامل حتى ٦ دورات نظرية.
double _measure(LabExperiment e, Map<String, double> p, {required double q0}) {
  final meter = PeriodMeter();
  var s = OscState(q0, 0);
  var t = 0.0;
  final horizon = e.period(p) * 8;
  while (t < horizon) {
    s = e.step(s, p);
    t += simDt;
    meter.feed(t, s.q);
  }
  return meter.averagePeriod!;
}
