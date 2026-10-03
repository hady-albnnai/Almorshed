import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U3-5 النابض الحلزوني: تضاغطات وتخاخر (نمط موحّد معتمد).
/// نبضات {x0,t0,sign} بسرعة CC=300px/s وعمر ٤٫٥ث، شكل cos² بعرض ٤٤
/// · انعكاس: مثبت ⇒ معكوس الوجه (تضاغط يعود تخاخراً)، حر ⇒ بنفس الوجه.
/// تحدّي: أرسل تضاغطاً عن النهاية المثبتة ولاحظ الانعكاس (+١٠) بمفتاح 'spring'.
class _Pulse {
  _Pulse(this.x0, this.t0, this.sign);
  final double x0, t0, sign;
}

class SpringScreen extends StatefulWidget {
  const SpringScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<SpringScreen> createState() => _SpringScreenState();
}

class _SpringScreenState extends State<SpringScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-spring.html المعتمد) ──
  static const double cc = 300; // سرعة النبضة px/s
  static const int nco = 34;
  static const double sprX0 = 90, sprX1 = 880;
  static const double fq0 = 1.2;
  double t = 0, fq = fq0;
  bool cont = false, freeEnd = false;
  bool won = false, started = false;
  final List<_Pulse> pulses = <_Pulse>[];

  /// شكل النبضة cos² بعرض w
  double ga(double u, double w) {
    u = u.abs();
    return u > w ? 0 : math.cos(u / w * math.pi / 2) ** 2;
  }

  double dispAt(double x) {
    var d = 0.0;
    for (final p in pulses) {
      final age = t - p.t0;
      if (age < 0 || age > 4.5) continue;
      final xc = p.x0 + cc * age;
      d += p.sign * 30 * ga(x - xc, 44);
      // انعكاس عن النهاية
      final x2 = 2 * sprX1 - (p.x0 + cc * age);
      d += freeEnd
          ? p.sign * 30 * ga(x - x2, 44)
          : -p.sign * 30 * ga(x - x2, 44);
    }
    if (cont) d += 9 * math.sin(2 * math.pi * fq * (t - x / cc));
    return d;
  }

  // ── الكاميرا والنجوم ──
  final OrbitCam cam = OrbitCam(dist: 640, fov: 640);
  final List<Star> stars = makeStars();
  bool view3d = false;
  bool _orbiting = false;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _challengeDoneToday = false;
  bool _predictDone = false;
  int? _predictPick;
  late TrainingData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['spring'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration el) {
    final dt = _last == Duration.zero
        ? 1 / 240
        : math.min((el - _last).inMicroseconds / 1e6, 0.1);
    _last = el;
    t += dt;
    pulses.removeWhere((p) => t - p.t0 > 4.5);
    // فوز 'spring': يُمنح عند إرسال تضاغط عن نهاية مثبتة (كالنموذج المعتمد)
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'spring': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'spring'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _send(int sign) {
    setState(() {
      pulses.add(_Pulse(sprX0 + 30, t, sign.toDouble()));
      if (pulses.isNotEmpty || cont) started = true;
      if (!freeEnd && !won && sign > 0 && !_challengeDoneToday) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    });
  }

  void _reset() {
    setState(() {
      pulses.clear();
      cont = false;
      won = false;
      started = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 336.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final k = size.width / 960;
    final cy = 190.0;
    // جدار التثبيت يسار/حلقة يمين حسب freeEnd
    if (freeEnd) {
      c.drawLine(Offset(sprX1 * k + 14 * k, cy - 60 * k),
          Offset(sprX1 * k + 14 * k, cy + 60 * k),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 4);
      c.drawCircle(Offset(sprX1 * k + 2 * k, cy), 9 * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFC9C9C4)
            ..strokeWidth = 2.6);
    } else {
      c.drawRect(Rect.fromLTWH(sprX1 * k, cy - 70 * k, 14 * k, 140 * k),
          Paint()..color = const Color(0xFF4A4540));
      for (var yy = -60.0; yy <= 60; yy += 15) {
        c.drawLine(Offset(sprX1 * k, cy + yy * k),
            Offset((sprX1 + 14) * k, cy + (yy + 8) * k),
            Paint()
              ..color = const Color.fromRGBO(110, 110, 104, 0.6)
              ..strokeWidth = 1.6);
      }
    }
    // النابض: لفات كخطوط رأسية بإزاحة dispAt
    final p = (sprX1 - sprX0) / (nco - 1);
    final pts = <Offset>[];
    for (var k2 = 0; k2 < nco; k2++) {
      final x = sprX0 + k2 * p;
      final d = dispAt(x);
      pts.add(Offset((x + d) * k, cy));
    }
    // جسم النابض (خطان علوي وسفلي متعرج + لفات)
    final top = Path()..moveTo(pts.first.dx, cy - 26 * k);
    final bot = Path()..moveTo(pts.first.dx, cy + 26 * k);
    for (var k2 = 0; k2 < nco; k2++) {
      top.lineTo(pts[k2].dx, cy - 26 * k);
      bot.lineTo(pts[k2].dx, cy + 26 * k);
    }
    c.drawPath(top, Paint()..color = const Color(0xFF9A9A94)..strokeWidth = 2);
    c.drawPath(bot, Paint()..color = const Color(0xFF9A9A94)..strokeWidth = 2);
    for (var k2 = 0; k2 < nco; k2++) {
      c.drawLine(pts[k2] - const Offset(0, 26), pts[k2] + const Offset(0, 26),
          Paint()
            ..color = k2.isEven
                ? const Color(0xFFB8B8B2)
                : const Color(0xFF8A8A84)
            ..strokeWidth = 2.6);
    }
    // نقاط تتبع التضاغط/التخاخر
    final dens = <double>[];
    for (var k2 = 0; k2 < nco; k2++) {
      final x = sprX0 + k2 * p;
      dens.add(dispAt(x + p) - dispAt(x)); // تضاغط = فراغ سالب
    }
    for (var k2 = 0; k2 < nco - 1; k2++) {
      final gap = dens[k2];
      if (gap < -6) {
        c.drawCircle(
            Offset(pts[k2].dx, cy - 40 * k), 3.4,
            Paint()..color = const Color(0xFFE86A4A));
      } else if (gap > 6) {
        c.drawCircle(
            Offset(pts[k2].dx, cy - 40 * k), 3.4,
            Paint()..color = const Color(0xFF7FB894));
      }
    }
    _arabic(c, '🔴 تضاغط  🟢 تخاخر', Offset(size.width * 0.5, 26), 12.5,
        const Color.fromRGBO(232, 226, 208, 0.85));
    _arabic(
        c,
        'الحالة: ${cont ? 'تردد مستمر ∿' : pulses.isNotEmpty ? 'نبضة تسافر…' : 'ساكن'} · النهاية: ${freeEnd ? 'حرة (حلقة)' : 'مثبتة (جدار)'}',
        Offset(w / 2, size.height - 16),
        13,
        const Color.fromRGBO(156, 195, 223, 0.85));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    final p = (sprX1 - sprX0) / (nco - 1);
    for (var k2 = 0; k2 < nco; k2++) {
      final x = sprX0 + k2 * p;
      final d = dispAt(x);
      final px = (x + d - 480) / 1.4;
      ring3(c, cam, size, px, 30,
          k2.isEven
              ? const Color(0xCCB8B8B2)
              : const Color(0xCC8A8A84),
          2);
    }
    line3(c, cam, size, const P3((sprX0 - 480) / 1.4, -30, 0),
        P3((sprX0 - 480) / 1.4, 30, 0), const Color(0xFF6E6E68), 4);
    if (freeEnd) {
      ring3(c, cam, size, (sprX1 - 480) / 1.4 + 12, 12,
          const Color(0xFFC9C9C4), 3);
    } else {
      line3(c, cam, size, P3((sprX1 - 480) / 1.4, -60, -40),
          P3((sprX1 - 480) / 1.4, 60, -40), const Color(0xFF4A4540), 8);
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        'الحالة: ${cont ? 'مستمر ∿' : pulses.isNotEmpty ? 'نبضة…' : 'ساكن'}',
        Offset(size.width / 2, 26),
        12,
        const Color(0xFFE8E2D0));
  }

  void _arabic(Canvas c, String s, Offset at, double size, Color col) {
    final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontSize: size, color: col, fontFamily: 'Tahoma')),
        textDirection: TextDirection.rtl)
      ..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المختبر: النابض الحلزوني — موجات طولية')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 440,
            child: GestureDetector(
              onPanStart: view3d ? (_) => _orbiting = true : null,
              onPanUpdate: view3d
                  ? (d) {
                      if (!_orbiting) return;
                      cam.yaw += d.delta.dx * 0.008;
                      cam.pitch =
                          (cam.pitch + d.delta.dy * 0.008).clamp(-0.05, 1.0);
                    }
                  : null,
              onPanEnd: (_) => _orbiting = false,
              child: CustomPaint(
                painter: _SpringPainter(this),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LabSlider(
                label: 'تردد الوضع المستمر',
                value: fq,
                min: 0.5, max: 2.5, divisions: 20,
                display: '${toAr(fq.toStringAsFixed(1))}Hz',
                onChanged: (x) => setState(() => fq = x)),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6,
                alignment: WrapAlignment.center, children: [
              ViewToggle(
                  view3d: view3d,
                  onChanged: (x) => setState(() => view3d = x)),
              OutlinedButton(
                  onPressed: () => _send(1),
                  child: const Text('➤ نبضة تضاغط')),
              OutlinedButton(
                  onPressed: () => _send(-1),
                  child: const Text('➤ نبضة تخاخر')),
              OutlinedButton(
                  onPressed: () => setState(() => cont = !cont),
                  child: Text(cont ? '∿ أوقف المستمر' : '∿ تردد مستمر')),
              OutlinedButton(
                  onPressed: () => setState(() => freeEnd = !freeEnd),
                  child: Text(freeEnd ? '⇄ النهاية: حرة' : '⇄ النهاية: مثبتة')),
              OutlinedButton(onPressed: _reset, child: const Text('↺ إعادة')),
            ]),
          ),
        ),
        if (!_predictDone) ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFFDF7),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('توقّع أولاً 🔮', style: txt.titleSmall),
                const SizedBox(height: 4),
                const Text(
                    'أرسلنا تضاغطاً نحو نهاية مثبتة (جدار) — ماذا يعود؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5)),
                const SizedBox(height: 8),
                for (var oi = 0; oi < 3; oi++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _predictPick = oi + 1);
                          if (oi + 1 == 2) {
                            Future.delayed(const Duration(milliseconds: 900),
                                () {
                              if (mounted) {
                                setState(() {
                                  _predictDone = true;
                                  _predictPick = null;
                                });
                              }
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: _predictPick == oi + 1
                                  ? (oi + 1 == 2
                                      ? const Color(0xFF538065)
                                      : const Color(0xFFBB5A45))
                                  : const Color(0xFFDCD8CC)),
                        ),
                        child: Text(const [
                          'تضاغط بنفس الوجه',
                          'تخاخر (منقلبة)',
                          'لا تعود',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — المثبت يقلب النبضة: تضاغط يعود تخاخراً'
                        : '✘ النهاية الحرة من يعيد بنفس الوجه — جرّب الوضعين',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _predictPick == 2
                            ? const Color(0xFF538065)
                            : const Color(0xFFBB5A45)),
                  ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('النبضات: ${toAr(pulses.length)}'),
              _chip('السرعة ٣٠٠px/s · العمر ٤٫٥s'),
              if (!_challengeDoneToday)
                _chip(
                    won ? '🎯 منجز! عاد تخاخراً' : '🎯 تضاغط عن المثبت — لاحظ الانعكاس',
                    ok: won)
              else
                _chip('🏆 التحدي منجز اليوم (+١٠)', ok: true),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اشرح — ربط الملاحظة بالقانون', style: txt.titleSmall),
              const SizedBox(height: 6),
              const Center(
                child: Text('موجة طولية: اهتزاز اللفات بمواجهة انتقال الموجة · v = √(E/ρ)',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('التضاغط: اللفات متقاربة (نقاط حمراء) والتخاخر: متباعدة (خضراء) — كلاهما يسافر بالسرعة نفسها.'),
              _explainLine('النهاية المثبتة تعكس معكوس الوجه: تضاغط يعود تخاخراً — والحرة تعكس بنفس الوجه.'),
              _explainLine('التردد المستمر يرسل سلسلة نبضات متتالية — تشبه كيف يرسل الصوت تضاغطات متتالية.'),
              _explainLine('هذه موجات طولية مثل الصوت: وسط يُضغط ويتمدد والطاقة تسير دون انتقال المادة.'),
              if (!started && !_challengeDoneToday) const _LockedVeil(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String s, {bool ok = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFE2EFE4) : const Color(0xFFF0E6D8),
          border: Border.all(color: ok ? const Color(0xFF538065) : const Color(0xFFDCD8CC)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(s,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: ok ? FontWeight.w700 : FontWeight.w400,
                color: ok ? const Color(0xFF538065) : null)),
      );

  Widget _explainLine(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('• $s', style: const TextStyle(fontSize: 13.5)),
      );
}

class _SpringPainter extends CustomPainter {
  _SpringPainter(this.st);
  final _SpringScreenState st;

  @override
  void paint(Canvas c, Size size) {
    if (st.view3d) {
      st._paint3D(c, size);
    } else {
      st._paintReal(c, size);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _LockedVeil extends StatelessWidget {
  const _LockedVeil();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8)),
      child: const Text(
          '🔒 يُفتح الشرح بعد أول نبضة — أرسل تضاغطاً وراقب!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
