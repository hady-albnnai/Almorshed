/// F7.2 — فرض ضمانات التباين في docs/13 حسابيًا على كل زوج نص/سطح.
/// هذا الاختبار يحرس قرار ٤٧ («كل الرموز مقاسة WCAG»): أي تعديل لون يكسر
/// عتبة AA يسقط هنا فورًا — لا اعتماد على تعليق يدوي.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/theme/app_colors.dart';
import 'package:fizya_clash/core/theme/contrast.dart';

void main() {
  // مرجع صحّة الحاسبة (قيم WCAG معروفة).
  group('حاسبة التباين — متجهات مرجعية', () {
    test('أبيض/أسود = 21:1', () {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21.0, 0.01),
      );
    });
    test('لون مع نفسه = 1:1', () {
      expect(
        contrastRatio(const Color(0xFF2DD4A7), const Color(0xFF2DD4A7)),
        closeTo(1.0, 0.001),
      );
    });
    test('القاعدة الصارمة: أبيض على الأخضر يفشل AA (< 4.5)', () {
      // docs/13: 1.89:1 — لهذا نصّ الـCTA داكن لا أبيض.
      expect(
        passesContrast(const Color(0xFFFFFFFF), AppColors.brandDark),
        isFalse,
      );
    });
  });

  group('الوضع الداكن — نص على سطح البطاقة (AA ≥ 4.5)', () {
    for (final pair in <({String name, Color fg, Color bg, double min})>[
      (name: 'darkTxt/darkCard', fg: AppColors.darkTxt, bg: AppColors.darkCard, min: WcagLevel.aaNormal),
      (name: 'darkTxt2/darkCard', fg: AppColors.darkTxt2, bg: AppColors.darkCard, min: WcagLevel.aaNormal),
      (name: 'darkTxt/darkBg', fg: AppColors.darkTxt, bg: AppColors.darkBg, min: WcagLevel.aaNormal),
      (name: 'brandDark/darkCard', fg: AppColors.brandDark, bg: AppColors.darkCard, min: WcagLevel.aaLarge),
      (name: 'brand2Dark/darkCard', fg: AppColors.brand2Dark, bg: AppColors.darkCard, min: WcagLevel.aaLarge),
      (name: 'goldDark/darkCard', fg: AppColors.goldDark, bg: AppColors.darkCard, min: WcagLevel.aaLarge),
      (name: 'violetDark/darkCard', fg: AppColors.violetDark, bg: AppColors.darkCard, min: WcagLevel.aaLarge),
      (name: 'dangerDark/darkCard', fg: AppColors.dangerDark, bg: AppColors.darkCard, min: WcagLevel.aaLarge),
      (name: 'okDark/darkCard', fg: AppColors.okDark, bg: AppColors.darkCard, min: WcagLevel.aaLarge),
    ]) {
      test('${pair.name} ≥ ${pair.min}', () {
        final r = contrastRatio(pair.fg, pair.bg);
        expect(r, greaterThanOrEqualTo(pair.min),
            reason: '${pair.name} = ${r.toStringAsFixed(2)}:1');
      });
    }
  });

  group('الوضع الفاتح — نص على سطح البطاقة (AA ≥ 4.5)', () {
    for (final pair in <({String name, Color fg, Color bg, double min})>[
      (name: 'lightTxt/lightCard', fg: AppColors.lightTxt, bg: AppColors.lightCard, min: WcagLevel.aaNormal),
      (name: 'lightTxt2/lightCard', fg: AppColors.lightTxt2, bg: AppColors.lightCard, min: WcagLevel.aaNormal),
      (name: 'lightTxt/lightBg', fg: AppColors.lightTxt, bg: AppColors.lightBg, min: WcagLevel.aaNormal),
      (name: 'brandLight/lightCard', fg: AppColors.brandLight, bg: AppColors.lightCard, min: WcagLevel.aaLarge),
      (name: 'brand2Light/lightCard', fg: AppColors.brand2Light, bg: AppColors.lightCard, min: WcagLevel.aaLarge),
      (name: 'goldLight/lightCard', fg: AppColors.goldLight, bg: AppColors.lightCard, min: WcagLevel.aaLarge),
      (name: 'violetLight/lightCard', fg: AppColors.violetLight, bg: AppColors.lightCard, min: WcagLevel.aaLarge),
      (name: 'dangerLight/lightCard', fg: AppColors.dangerLight, bg: AppColors.lightCard, min: WcagLevel.aaLarge),
      (name: 'okLight/lightCard', fg: AppColors.okLight, bg: AppColors.lightCard, min: WcagLevel.aaLarge),
    ]) {
      test('${pair.name} ≥ ${pair.min}', () {
        final r = contrastRatio(pair.fg, pair.bg);
        expect(r, greaterThanOrEqualTo(pair.min),
            reason: '${pair.name} = ${r.toStringAsFixed(2)}:1');
      });
    }
  });

  test('نصّ CTA الداكن على الأخضر يمرّ AA (القاعدة الصارمة docs/13)', () {
    final r = contrastRatio(AppColors.onCta, AppColors.brandDark);
    expect(r, greaterThanOrEqualTo(WcagLevel.aaNormal),
        reason: 'onCta/brandDark = ${r.toStringAsFixed(2)}:1');
  });
}
