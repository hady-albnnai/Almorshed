import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// شاشة البداية المتحركة لـ«فيزيا كلاش».
///
/// تُعرض أثناء **التحميل الحقيقي** (حزمة المحتوى + الترخيص) — لا مؤقّت مصطنع:
/// ما إن يجهز التطبيق حتى ينتقل فوراً (قرار الأدلّة 2025-2026).
///
/// الحركة: تجمّع مدارات الذرّة (خضراء) ثم ومضة برق ذهبية «كلاش»، يليها ظهور
/// اسم التطبيق، ثم دوران هادئ للإلكترونات ما دام التحميل جارياً.
///
/// الإتاحة: يحترم «تقليل الحركة» (MediaQuery.disableAnimations) بعرض إطار ثابت
/// نهائي بلا أي تحريك.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with TickerProviderStateMixin {
  // مقدّمة تُشغَّل مرة واحدة (≤ 1 ثانية — إرشاد جوجل الرسمي).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  // دوران هادئ مستمر للإلكترونات ما دام التحميل جارياً (لا يعطّل شيئاً).
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // يُقرأ هنا لأن MediaQuery غير متاح في initState.
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_started) return;
    _started = true;
    if (!_reduceMotion) {
      _intro.forward();
      _idle.repeat();
    } else {
      // fallback ثابت: نُثبّت الحالة النهائية بلا تحريك.
      _intro.value = 1.0;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onCta,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _idle]),
          builder: (context, _) {
            final intro = Curves.easeOutCubic.transform(_intro.value);
            return LayoutBuilder(
              builder: (context, c) {
                final side = math.min(c.maxWidth, c.maxHeight);
                final atom = side * 0.42;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: atom,
                      height: atom,
                      child: CustomPaint(
                        painter: _AtomPainter(
                          intro: intro,
                          spin: _idle.value,
                          reduceMotion: _reduceMotion,
                        ),
                      ),
                    ),
                    SizedBox(height: side * 0.06),
                    // اسم التطبيق يظهر بعد تجمّع الذرّة.
                    Opacity(
                      opacity: _reduceMotion
                          ? 1.0
                          : Curves.easeIn.transform(
                              ((_intro.value - 0.55) / 0.45).clamp(0.0, 1.0),
                            ),
                      child: Text(
                        'فيزيا كلاش',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: side * 0.085,
                          fontWeight: FontWeight.w800,
                          color: AppColors.goldDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// يرسم الذرّة (٣ مدارات + إلكترونات + نواة) والبرق الذهبي فوقها.
class _AtomPainter extends CustomPainter {
  _AtomPainter({
    required this.intro,
    required this.spin,
    required this.reduceMotion,
  });

  /// تقدّم المقدّمة 0→1 (بعد منحنى التسهيل).
  final double intro;

  /// دوران الإلكترونات المستمر 0→1.
  final double spin;

  final bool reduceMotion;

  static const _teal = AppColors.brandDark; // #2DD4A7
  static const _blue = AppColors.brand2Dark; // #38BDF8
  static const _gold = AppColors.goldDark; // #FBBF24
  static const _bg = AppColors.onCta; // #04222B

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // ظهور المدارات: قصّ زاوي (تُرسَم كأنها تُكتب) + تلاشٍ.
    final orbitReveal = (intro / 0.7).clamp(0.0, 1.0);
    final rx = r * 0.92;
    final ry = r * 0.42;

    for (var i = 0; i < 3; i++) {
      final base = i * math.pi / 3; // ٦٠° بين المدارات
      final rot = base + (reduceMotion ? 0 : spin * 2 * math.pi * 0.15);
      _drawOrbit(canvas, center, rx, ry, rot, orbitReveal);
      _drawElectron(canvas, center, rx, ry, rot, i, orbitReveal);
    }

    // النواة الداكنة.
    final nucleusR = r * 0.14 * (0.6 + 0.4 * orbitReveal);
    canvas.drawCircle(
      center,
      nucleusR,
      Paint()..color = _bg,
    );
    canvas.drawCircle(
      center,
      nucleusR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02
        ..color = _teal.withValues(alpha: 0.9 * orbitReveal),
    );

    // ومضة البرق الذهبية «كلاش» — تبدأ بعد تجمّع المدارات.
    final boltT = ((intro - 0.45) / 0.55).clamp(0.0, 1.0);
    if (boltT > 0) {
      _drawBolt(canvas, center, r, boltT);
    }
  }

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    double rot,
    double reveal,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );
    // قوس جزئي يكبر مع reveal (تأثير الرسم التدريجي).
    final sweep = 2 * math.pi * reveal;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rx * 0.055
      ..strokeCap = StrokeCap.round
      ..color = _teal.withValues(alpha: 0.95 * reveal);
    final path = Path()..addArc(rect, -math.pi / 2, sweep);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawElectron(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    double rot,
    int index,
    double reveal,
  ) {
    if (reveal < 1.0 && !reduceMotion) return; // تظهر بعد اكتمال المدار
    // زاوية الإلكترون على المدار (تتقدّم مع الدوران المستمر).
    final t = spin * 2 * math.pi + index * 2 * math.pi / 3;
    final local = Offset(rx * math.cos(t), ry * math.sin(t));
    final dx = local.dx * math.cos(rot) - local.dy * math.sin(rot);
    final dy = local.dx * math.sin(rot) + local.dy * math.cos(rot);
    final pos = center + Offset(dx, dy);
    final er = rx * 0.07;
    canvas.drawCircle(
      pos,
      er,
      Paint()..color = (index.isEven ? _teal : _blue),
    );
    canvas.drawCircle(
      pos,
      er,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = er * 0.4
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _drawBolt(Canvas canvas, Offset center, double r, double t) {
    // برق كلاسيكي متمركز، مقيّس بنصف القطر.
    final h = r * 1.15;
    final w = r * 0.5;
    Offset p(double nx, double ny) =>
        center + Offset(nx * w, ny * h);
    final bolt = Path()
      ..moveTo(p(0.15, -0.62).dx, p(0.15, -0.62).dy)
      ..lineTo(p(-0.55, 0.08).dx, p(-0.55, 0.08).dy)
      ..lineTo(p(-0.08, 0.08).dx, p(-0.08, 0.08).dy)
      ..lineTo(p(-0.28, 0.62).dx, p(-0.28, 0.62).dy)
      ..lineTo(p(0.55, -0.12).dx, p(0.55, -0.12).dy)
      ..lineTo(p(0.05, -0.12).dx, p(0.05, -0.12).dy)
      ..close();

    // نبضة ظهور: تكبير خفيف + وهج يخبو.
    final scale = 0.82 + 0.18 * Curves.easeOutBack.transform(t);
    final flash = (1.0 - t).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    // وهج «الكلاش» عند لحظة الظهور.
    if (flash > 0.01 && !reduceMotion) {
      canvas.drawPath(
        bolt,
        Paint()
          ..color = _gold.withValues(alpha: 0.55 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18 * flash),
      );
    }

    // جسم البرق الذهبي + حدّ داكن.
    canvas.drawPath(bolt, Paint()..color = _gold.withValues(alpha: t));
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = _bg.withValues(alpha: 0.85 * t),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AtomPainter old) =>
      old.intro != intro || old.spin != spin;
}
