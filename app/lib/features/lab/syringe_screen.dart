import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U1-6 المحقن والإبرة: السحب والدفع والتدفق (نمط موحّد معتمد).
/// Am = 176mm² (مكبس 15mm) · An = πd²/4 · vJet = min(11, F·0.42·An·40/(An·40+(0.05/d²)·14))
/// · Q = vJet·An/1000 · تحدّي: أدخل ٥ml خلال ≤ ٣s بقوة ≤ ٢٥N (+١٠) بمفتاح 'syringe'.
class SyringeScreen extends StatefulWidget {
  const SyringeScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<SyringeScreen> createState() => _SyringeScreenState();
}

class _SyringeScreenState extends State<SyringeScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-syringe.html المعتمد) ──
  static const double vmax = 20; // ml
  static const double am = 176; // mm² مساحة المكبس
  double f = 0; // N
  double d = 0.25; // mm قطر الإبرة
  double vol = 10; // ml
  int mode = 0; // 0 توقف · 1 دفع · -1 سحب
  double t = 0;
  bool won = false, started = false;
  double goalT0 = 0, goalV0 = 0;
  bool goalActive = false;

  double get an => math.pi * d * d / 4;
  double get vJet => mode == 1
      ? math.min(
          11, f * 0.42 * (an * 40 / (an * 40 + (0.05 / (d * d)) * 14)))
      : 0.0;
  double get q => vJet * an / 1000; // ml/s
  double get vPiston => q * 1000 / am * 10; // mm/s

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
        _data.labChallengeDays['syringe'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step(double dt) {
    t += dt;
    if (mode == 1) {
      vol = math.max(0, vol - q * dt);
      if (goalActive && !won && !_challengeDoneToday) {
        if (f <= 25 && vol - goalV0 >= 5 && t - goalT0 <= 3) {
          won = true;
          HapticFeedback.mediumImpact();
          _recordChallenge();
        } else if (t - goalT0 > 3 && vol - goalV0 < 5) {
          goalActive = false; // فات الوقت — أعد المحاولة
        }
      }
      if (!started) started = true;
    } else if (mode == -1) {
      vol = math.min(vmax, vol + q * dt * 1.6);
      goalActive = false;
    }
  }

  void _tick(Duration el) {
    final dt = _last == Duration.zero
        ? 1 / 240
        : math.min((el - _last).inMicroseconds / 1e6, 0.1);
    _last = el;
    _step(dt);
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'syringe': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'syringe'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _start(int m) {
    setState(() {
      mode = m;
      if (m == 1) {
        goalT0 = t;
        goalV0 = vol;
        goalActive = true;
      }
    });
  }

  void _reset() {
    setState(() {
      vol = 10;
      mode = 0;
      goalActive = false;
      won = false;
      started = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 330.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final cy = 200.0;
    final bodyL = w * 0.16, bodyR = w * 0.62;
    // جسم المحقن مع تدريج 20ml
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bodyL, cy - 34, bodyR - bodyL, 68),
            const Radius.circular(8)),
        Paint()
          ..color = const Color.fromRGBO(200, 220, 235, 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bodyL, cy - 34, bodyR - bodyL, 68),
            const Radius.circular(8)),
        Paint()..color = const Color.fromRGBO(180, 205, 225, 0.05));
    for (var ml = 0; ml <= 20; ml += 5) {
      final xx = bodyR - (bodyR - bodyL - 14) * ml / 20 - 4;
      c.drawLine(
          Offset(xx, cy - 34),
          Offset(xx, cy - (ml % 10 == 0 ? 46 : 41)),
          Paint()
            ..color = const Color.fromRGBO(205, 215, 230, 0.5)
            ..strokeWidth = 1.2);
      if (ml % 10 == 0) {
        _arabic(c, toAr(ml), Offset(xx, cy - 54), 10.5,
            const Color.fromRGBO(205, 215, 230, 0.55));
      }
    }
    // السائل داخل الجسم
    final fillW = (bodyR - bodyL - 8) * vol / 20;
    if (vol > 0.05) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bodyR - 4 - fillW, cy - 30, fillW, 60),
              const Radius.circular(6)),
          Paint()..color = const Color.fromRGBO(120, 190, 225, 0.28));
    }
    // المكبس + جذعه
    final pistonX = bodyR - 4 - (bodyR - bodyL - 8) * vol / 20;
    c.drawRect(
        Rect.fromLTWH(pistonX - 6, cy - 30, 12, 60),
        Paint()..color = const Color(0xFFB8BEC4));
    c.drawLine(
        Offset(pistonX, cy),
        Offset(bodyL - 40, cy),
        Paint()
          ..color = const Color(0xFF9A9A94)
          ..strokeWidth = 7);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bodyL - 62, cy - 16, 24, 32),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFF6E6E68));
    // سهم القوة على المكبس
    if (f > 0.5 && mode != 0) {
      final dir = mode == 1 ? -1.0 : 1.0;
      final len = 14 + f * 2.2;
      c.drawLine(
          Offset(bodyL - 70, cy),
          Offset(bodyL - 70 + dir * len, cy),
          Paint()
            ..color = const Color.fromRGBO(240, 150, 74, 0.95)
            ..strokeWidth = 5);
      _arabic(c, 'F = ${toAr(f.toStringAsFixed(0))}N',
          Offset(bodyL - 70 + dir * (len + 26), cy - 18), 12.5,
          const Color(0xFFF0964A));
    }
    // الإبرة
    final hubW = 26.0;
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bodyR, cy - 10, hubW, 20),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFFC89A5A));
    final needleL = 120.0;
    final nThick = (d / 0.8).clamp(1.2, 5.0);
    c.drawLine(
        Offset(bodyR + hubW, cy),
        Offset(bodyR + hubW + needleL, cy),
        Paint()
          ..color = const Color(0xFFC9C9C4)
          ..strokeWidth = nThick);
    // النفاثة
    if (mode == 1 && vJet > 0.2 && vol > 0) {
      final drops = (vJet / 2.2).clamp(1, 7).round();
      for (var k = 0; k < drops; k++) {
        final ph = ((t * vJet * 0.35) + k / drops) % 1;
        c.drawCircle(
            Offset(bodyR + hubW + needleL + ph * 90,
                cy + math.sin(k * 2.2 + t * 3) * 3 * ph),
            2.6 - 1.2 * ph,
            Paint()
              ..color = Color.fromRGBO(140, 200, 235, (0.9 - 0.55 * ph).toDouble()));
      }
    }
    _arabic(
        c,
        'Q = ${toAr(q.toStringAsFixed(2))}ml/s · v(إبرة) = ${toAr(vJet.toStringAsFixed(1))}mm/s · v(مكبس) = ${toAr(vPiston.toStringAsFixed(2))}mm/s',
        Offset(w / 2, 26),
        12.5,
        const Color(0xFFE8E2D0));
    _arabic(
        c,
        'd(إبرة) = ${toAr(d.toStringAsFixed(2))}mm · An/Am = 1/${toAr((am / an).round())}',
        Offset(w / 2, 48),
        12,
        const Color.fromRGBO(232, 226, 208, 0.75));
    _arabic(c, 'V = ${toAr(vol.toStringAsFixed(1))}ml',
        Offset(w * 0.5, cy + 92), 14, const Color(0xFF9CC3DF));
    _arabic(
        c,
        goalActive
            ? 'الهدف: ${toAr((vol - goalV0).clamp(0, 10).toStringAsFixed(1))}/٥ml خلال ${toAr((t - goalT0).toStringAsFixed(1))}/٣s'
            : mode == 1
                ? 'يدفع…'
                : mode == -1
                    ? 'يسحب (ملء)…'
                    : 'توقف — اختر دفع/سحب',
        Offset(w / 2, size.height - 16),
        13,
        goalActive ? const Color(0xFF8CFFAA) : const Color.fromRGBO(156, 195, 223, 0.85));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    // المحقن أفقية على المحور x: الجسم من -200 إلى 60، الإبرة إلى 190
    final frac = vol / 20;
    final pistonX = -200 + 250 * frac;
    // جسم المحقن: 4 حواف طولية + حلقتا نهاية
    ring3(c, cam, size, -200, 26, const Color.fromRGBO(180, 205, 225, 0.55), 2);
    ring3(c, cam, size, 50, 26, const Color.fromRGBO(180, 205, 225, 0.55), 2);
    for (final zz in [-26.0, 26.0]) {
      line3(c, cam, size, P3(-200, 60, zz), P3(50, 60, zz),
          const Color.fromRGBO(180, 205, 225, 0.35), 1.4);
      line3(c, cam, size, P3(-200, -8, zz), P3(50, -8, zz),
          const Color.fromRGBO(180, 205, 225, 0.35), 1.4);
    }
    // السائل: أسطوانة جزئية من طرف الإبرة حتى المكبس
    if (vol > 0.05) {
      final fillEnd = pistonX;
      for (final zz in [-20.0, 20.0]) {
        line3(c, cam, size, P3(fillEnd, 54, zz), P3(46, 54, zz),
            const Color.fromRGBO(120, 190, 225, 0.5), 3);
        line3(c, cam, size, P3(fillEnd, -2, zz), P3(46, -2, zz),
            const Color.fromRGBO(120, 190, 225, 0.5), 3);
      }
    }
    // المكبس
    final p0 = cam.project(P3(pistonX, 62, -26), size);
    final p1 = cam.project(P3(pistonX, 62, 26), size);
    final p2 = cam.project(P3(pistonX, -10, 26), size);
    final p3 = cam.project(P3(pistonX, -10, -26), size);
    final plume = Path()
      ..moveTo(p0.x, p0.y)
      ..lineTo(p1.x, p1.y)
      ..lineTo(p2.x, p2.y)
      ..lineTo(p3.x, p3.y)
      ..close();
    c.drawPath(plume, Paint()..color = const Color(0xE6B8BEC4));
    line3(c, cam, size, P3(pistonX, 26, 0), P3(pistonX - 90, 26, 0),
        const Color(0xFF9A9A94), 6);
    // الرأس والإبرة
    line3(c, cam, size, const P3(50, 26, 0), const P3(76, 26, 0),
        const Color(0xFFC89A5A), 6);
    final nThick = (d / 0.8).clamp(1.0, 4.0);
    line3(c, cam, size, const P3(76, 26, 0), const P3(190, 26, 0),
        const Color(0xFFC9C9C4), nThick);
    // النفاثة
    if (mode == 1 && vJet > 0.2 && vol > 0) {
      for (var k = 0; k < 5; k++) {
        final ph = ((t * vJet * 0.35) + k / 5) % 1;
        final dp = cam.project(
            P3(190 + ph * 120, 26 + math.sin(k * 2.2 + t * 3) * 6 * ph, 0),
            size);
        c.drawCircle(
            Offset(dp.x, dp.y),
            3 - 1.5 * ph,
            Paint()
              ..color =
                  Color.fromRGBO(140, 200, 235, (0.9 - 0.55 * ph).toDouble()));
      }
    }
    _arabic(
        c,
        'Q = ${toAr(q.toStringAsFixed(2))}ml/s · v(إبرة) = ${toAr(vJet.toStringAsFixed(1))}mm/s · V = ${toAr(vol.toStringAsFixed(1))}ml',
        Offset(size.width / 2, 26),
        12,
        const Color(0xFFE8E2D0));
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
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
      appBar: AppBar(title: const Text('المختبر: المحقن والإبرة — التدفق')),
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
                painter: _SyringePainter(this),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              LabSlider(
                  label: 'القوة F',
                  value: f,
                  min: 0, max: 30, divisions: 30,
                  display: '${toAr(f.round())}N',
                  onChanged: (x) => setState(() => f = x)),
              LabSlider(
                  label: 'قطر الإبرة d',
                  value: d,
                  min: 0.15, max: 0.8, divisions: 13,
                  display: '${toAr(d.toStringAsFixed(2))}mm',
                  onChanged: (x) => setState(() => d = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => _start(1), child: const Text('⬅ دفع مستمر')),
                OutlinedButton(
                    onPressed: () => _start(-1), child: const Text('➡ سحب (ملء)')),
                OutlinedButton(
                    onPressed: () => setState(() => mode = 0),
                    child: const Text('⏹ توقف')),
                OutlinedButton(onPressed: _reset, child: const Text('↺ إعادة')),
              ]),
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
                    'سرعة السائل داخل الإبرة مقارنةً بسرعته داخل جسم المحقن؟',
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
                          'أقل — الإبرة تعيق',
                          'مئات الأمثال — مساحة الإبرة أصغر بقلب المساحة',
                          'نفس السرعة — Q واحد',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — الاستمرارية Q=A·v: صغر المساحة ⇒ عظّمت السرعة'
                        : '✘ Q ثابت: v ∝ 1/A — وAn/Am يصل 1/٤٥٠٠ بالإبرة الدقيقة',
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
              _chip('Q = ${toAr(q.toStringAsFixed(2))}ml/s'),
              _chip('V = ${toAr(vol.toStringAsFixed(1))}ml'),
              _chip('An/Am = 1/${toAr((am / an).round())}'),
              if (!_challengeDoneToday)
                _chip(
                    won
                        ? '🎯 منجز!'
                        : '🎯 أدخل ٥ml خلال ≤ ٣s بقوة ≤ ٢٥N',
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
                child: Text('Q = A·v = ثابت · p + ½ρv² + ρgh = ثابت',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 16)),
              ),
              const SizedBox(height: 6),
              _explainLine('الاستمرارية: ما يدخل المكبس يخرج من الإبرة — صغر المساحة بقلب النسبة ⇒ السرعة بعكسها.'),
              _explainLine('الإبرة الأدق تعني مقاومة أكبر: نفس F يعطي vJet أصغر — عامل (0.05/d²) يعاقب الأقطار الصغيرة.'),
              _explainLine('سرعة المكبس صغيرة جداً (أجزاء mm/s) لأن Am كبيرة — لهذا الدفع يبدو هادئاً والنفاثة سريعة.'),
              _explainLine('التحدي موازنة: قوة كافية قبل نفاد الوقت، دون تجاوز ٢٥N — هكذا يفعل الممرّض فعلاً.'),
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

class _SyringePainter extends CustomPainter {
  _SyringePainter(this.st);
  final _SyringeScreenState st;

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
          '🔒 يُفتح الشرح بعد أول دفع — اضغط «دفع مستمر» وراقب النفاثة!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
