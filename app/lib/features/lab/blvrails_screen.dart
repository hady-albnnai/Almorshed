import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-13 السكتان التحريضية: ε = B·L·v (نمط موحّد معتمد).
/// قضيب يسحب/يدفع على سكتين داخل حقل — القراءة فقط أثناء الحركة: v=0 ⟹ ε=0
/// · إبرة عدّاد RK4 نفس معاملات المعتمد (60·εN −30·ang −7·angV) · ذروات ±٦٠٪
/// · تحدّي انحرافان متعاكسان فوق ٦٠٪ (+١٠) بمفتاح 'blvrails' · إعادة بطيئة ×٠٫٢٥.
class _BufS {
  _BufS(this.t, this.e, this.ang);
  final double t, e, ang;
}

class BlvrailsScreen extends StatefulWidget {
  const BlvrailsScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<BlvrailsScreen> createState() => _BlvrailsScreenState();
}

class _BlvrailsScreenState extends State<BlvrailsScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-blvrails.html المعتمد) ──
  static const double pxm = 300; // بكسل لكل متر
  static const double wCan = 960;
  double bt = 0.8, dm = 0.4;
  int bsign = 1;
  double t = 0;
  double rx = 480, rv = 0;
  int? drive; // -1 يسار · +1 يمين
  double ang = 0, angV = 0; // إبرة العدّاد ±1V
  double peakP = 0, peakN = 0;
  bool won = false, started = false;
  bool dragging = false;
  double canvasW = wCan; // يُلتقط من LayoutBuilder
  final List<_BufS> buf = <_BufS>[];
  static const int maxB = 6 * 240;
  // إعادة بطيئة ×٠٫٢٥
  bool replaying = false;
  double replayP = 0;
  double replayT0 = 0;

  double get eps => bsign * bt * dm * (rv / pxm);
  double get epsN {
    final e = eps / 0.35;
    return e.clamp(-1.0, 1.0);
  }

  // ── الكاميرا والنجوم ──
  final OrbitCam cam = OrbitCam(dist: 620, fov: 620);
  final List<Star> stars = makeStars();
  bool view3d = false;
  bool _orbiting = false;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _challengeDoneToday = false;
  bool _predictDone = false;
  int? _predictPick;
  late TrainingData _data;
  Duration? _lastStamp;
  double _lastDragX = 0;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['blvrails'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step(double dt) {
    const st = 1 / 240;
    var acc = dt;
    while (acc >= st) {
      acc -= st;
      t += st;
      if (!dragging) {
        if (drive != null) {
          rv = drive == -1 ? -350.0 : 350.0;
        } else {
          rv *= math.exp(-2.2 * st);
        }
        rx += rv * st;
        const lo = 180.0, hi = wCan - 180;
        if (rx <= lo) {
          rx = lo;
          rv = 0;
          drive = null;
        }
        if (rx >= hi) {
          rx = hi;
          rv = 0;
          drive = null;
        }
      }
      final tg = epsN;
      // إبرة العدّاد — RK4 بنفس معاملات المعتمد
      double accF(double a, double av) => 60 * tg - 30 * a - 7 * av;
      final k1a = angV, k1w = accF(ang, angV);
      final k2a = angV + st / 2 * k1w,
          k2w = accF(ang + st / 2 * k1a, angV + st / 2 * k1w);
      final k3a = angV + st / 2 * k2w,
          k3w = accF(ang + st / 2 * k2a, angV + st / 2 * k2w);
      final k4a = angV + st * k3w,
          k4w = accF(ang + st * k3a, angV + st * k3w);
      ang += st / 6 * (k1a + 2 * k2a + 2 * k3a + k4a);
      angV += st / 6 * (k1w + 2 * k2w + 2 * k3w + k4w);
      buf.add(_BufS(t, epsN, ang));
      if (buf.length > maxB) buf.removeAt(0);
      final e = epsN;
      if (e > peakP) peakP = e;
      if (e < peakN) peakN = e;
      if (!started && ang.abs() > 0.15) started = true;
      if (peakP >= 0.6 && peakN <= -0.6 && !won && !_challengeDoneToday) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    }
  }

  void _tick(Duration el) {
    if (replaying) {
      replayP += (_lastStamp == null
              ? 1 / 240
              : math.min((el - _lastStamp!).inMicroseconds / 1e6, 0.1)) *
          0.25;
      _lastStamp = el;
      if (replayP >= 3) {
        replaying = false;
      }
      if (mounted) setState(() {});
      return;
    }
    final dt = _last == Duration.zero
        ? 1 / 240
        : math.min((el - _last).inMicroseconds / 1e6, 0.1);
    _last = el;
    _lastStamp = el;
    _step(dt);
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'blvrails': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'blvrails'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _startReplay() {
    setState(() {
      replaying = true;
      replayP = 0;
      replayT0 = t;
    });
  }

  /// قيمة الإبرة المعروضة (إعادة بطيئة أو حية)
  double get shownAng {
    if (!replaying) return ang;
    final tTarget = replayT0 - 3 + replayP;
    _BufS? best;
    var bestD = 1e9;
    for (final s in buf) {
      final d = (s.t - tTarget).abs();
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best?.ang ?? ang;
  }

  void _impulse(int dir) {
    setState(() {
      drive = dir;
      started = true;
    });
  }

  void _reset() {
    setState(() {
      rx = 480;
      rv = 0;
      drive = null;
      ang = 0;
      angV = 0;
      peakP = 0;
      peakN = 0;
      buf.clear();
      won = false;
      replaying = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    final k = size.width / wCan;
    final railY1 = 150.0, railY2 = 380.0;
    // منطقة الحقل
    c.drawRect(
        Rect.fromLTWH(160 * k, (railY1 - 40) * k, (wCan - 320) * k,
            (railY2 - railY1 + 80) * k),
        Paint()..color = const Color.fromRGBO(74, 109, 140, 0.10));
    for (var x = 180.0; x < wCan - 180; x += 46) {
      for (var y = railY1 - 20; y < railY2 + 20; y += 40) {
        if (bsign > 0) {
          final s = 7.0;
          c.drawLine(Offset(x * k - s, y * k - s), Offset(x * k + s, y * k + s),
              Paint()
                ..color = const Color.fromRGBO(138, 170, 195, 0.35)
                ..strokeWidth = 1.6);
          c.drawLine(Offset(x * k + s, y * k - s), Offset(x * k - s, y * k + s),
              Paint()
                ..color = const Color.fromRGBO(138, 170, 195, 0.35)
                ..strokeWidth = 1.6);
        } else {
          c.drawCircle(Offset(x * k, y * k), 2.2,
              Paint()..color = const Color.fromRGBO(138, 170, 195, 0.45));
        }
      }
    }
    // السكتان + التغذية للعدّاد
    c.drawLine(Offset(140 * k, railY1 * k), Offset((wCan - 140) * k, railY1 * k),
        Paint()
          ..color = const Color.fromRGBO(203, 183, 158, 0.85)
          ..strokeWidth = 6);
    c.drawLine(Offset(140 * k, railY2 * k), Offset((wCan - 140) * k, railY2 * k),
        Paint()
          ..color = const Color.fromRGBO(203, 183, 158, 0.85)
          ..strokeWidth = 6);
    c.drawLine(Offset(140 * k, railY1 * k), Offset(96 * k, railY1 * k),
        Paint()
          ..color = const Color.fromRGBO(203, 183, 158, 0.6)
          ..strokeWidth = 4);
    c.drawLine(Offset(96 * k, railY1 * k), Offset(96 * k, 265 * k),
        Paint()
          ..color = const Color.fromRGBO(203, 183, 158, 0.6)
          ..strokeWidth = 4);
    c.drawLine(Offset(96 * k, 265 * k), Offset(140 * k, railY2 * k),
        Paint()
          ..color = const Color.fromRGBO(203, 183, 158, 0.6)
          ..strokeWidth = 4);
    // القضيب المتحرك
    final rodX = rx * k;
    c.drawLine(
        Offset(rodX, (railY1 - 14) * k),
        Offset(rodX, (railY2 + 14) * k),
        Paint()
          ..color = const Color(0xFFD9B45A)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    c.drawCircle(Offset(rodX, 265 * k), 6,
        Paint()..color = const Color(0xFFB8BEC4));
    // عدّاد مركزي (قوس ±60°) بإبرة shownAng
    final mx = w / 2, my = 60.0;
    c.drawArc(Rect.fromCircle(center: Offset(mx, my), radius: 40),
        math.pi / 6, 2 * math.pi / 3, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(230, 228, 220, 0.4)
          ..strokeWidth = 2);
    final na = shownAng.clamp(-1.0, 1.0) * (math.pi / 3);
    c.drawLine(
        Offset(mx, my),
        Offset(mx + math.sin(na) * 36, my - math.cos(na) * 36),
        Paint()
          ..color = const Color(0xFFE86A4A)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round);
    _arabic(c, 'ε = ${toAr(eps.toStringAsFixed(3))}V', Offset(mx + 70, my), 13,
        const Color(0xFF9CD9BC));
    _arabic(
        c,
        'B = ${toAr(bt.toStringAsFixed(1))}T ${bsign > 0 ? '(إلى الداخل ×)' : '(نحو الخارج ·)'} · L = ${toAr(dm.toStringAsFixed(2))}m · v = ${toAr((rv / pxm).abs().toStringAsFixed(2))}m/s',
        Offset(w / 2, 26),
        12.5,
        const Color(0xFF8AAAC3));
    _arabic(
        c,
        'ذروة + : ${toAr(peakP.toStringAsFixed(2))} · ذروة − : ${toAr(peakN.toStringAsFixed(2))}${replaying ? ' · إعادة بطيئة ×٠٫٢٥' : ''}',
        Offset(w / 2, size.height - 16),
        13,
        replaying ? const Color(0xFFF0964A) : const Color.fromRGBO(156, 195, 223, 0.85));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    // سكتان بمستوى الأرض y=-40، من z=-140 إلى 140، القضيب يتحرك بx
    final railX = (rx - 480) / pxm * 200;
    line3(c, cam, size, const P3(-260, -40, -140), const P3(260, -40, -140),
        const Color.fromRGBO(203, 183, 158, 0.85), 4);
    line3(c, cam, size, const P3(-260, -40, 140), const P3(260, -40, 140),
        const Color.fromRGBO(203, 183, 158, 0.85), 4);
    // القضيب
    line3(c, cam, size, P3(railX, -40, -150), P3(railX, -40, 150),
        const Color(0xFFD9B45A), 5);
    // أسهم الحقل
    for (var x = -240.0; x <= 240; x += 120) {
      for (var z = -100.0; z <= 100; z += 100) {
        if (bsign > 0) {
          line3(c, cam, size, P3(x, -20, z), P3(x, -60, z),
              const Color.fromRGBO(138, 170, 195, 0.4), 1.6);
          final ap = cam.project(P3(x, -60, z), size);
          c.drawCircle(Offset(ap.x, ap.y), 2,
              Paint()..color = const Color.fromRGBO(138, 170, 195, 0.5));
        } else {
          line3(c, cam, size, P3(x, -60, z), P3(x, -20, z),
              const Color.fromRGBO(138, 170, 195, 0.4), 1.6);
        }
      }
    }
    _arabic(
        c,
        'ε = ${toAr(eps.toStringAsFixed(3))}V · v = ${toAr((rv / pxm).abs().toStringAsFixed(2))}m/s',
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
      appBar: AppBar(title: const Text('المختبر: السكتان التحريضية — ε = BLv')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 430,
            child: GestureDetector(
              onPanStart: view3d
                  ? (_) => _orbiting = true
                  : (d) {
                      // سحب القضيب مباشرة بالمنظور الواقعي
                      dragging = true;
                      _lastDragX =
                          d.localPosition.dx / canvasW * wCan;
                      _lastStamp = null;
                    },
              onPanUpdate: view3d
                  ? (d) {
                      if (!_orbiting) return;
                      cam.yaw += d.delta.dx * 0.008;
                      cam.pitch =
                          (cam.pitch + d.delta.dy * 0.008).clamp(-0.05, 1.0);
                    }
                  : (d) {
                      if (!dragging) return;
                      final nowX =
                          d.localPosition.dx / canvasW * wCan;
                      final dt = _lastStamp == null
                          ? 1 / 240
                          : math.min(0.05, 1 / 60);
                      rv = ((nowX - _lastDragX) / dt).clamp(-900.0, 900.0);
                      rx = nowX.clamp(180.0, wCan - 180);
                      _lastDragX = rx;
                      started = true;
                    },
              onPanEnd: (_) => dragging = false,
              child: LayoutBuilder(builder: (context, cons) {
                canvasW = cons.maxWidth;
                return CustomPaint(
                  painter: _BlvrailsPainter(this),
                  child: const SizedBox.expand(),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              LabSlider(
                  label: 'الحقل B',
                  value: bt,
                  min: 0.2, max: 1.5, divisions: 13,
                  display: '${toAr(bt.toStringAsFixed(1))}T',
                  onChanged: (x) => setState(() => bt = x)),
              LabSlider(
                  label: 'طول القضيب L',
                  value: dm,
                  min: 0.2, max: 0.6, divisions: 8,
                  display: '${toAr(dm.toStringAsFixed(2))}m',
                  onChanged: (x) => setState(() => dm = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => bsign = -bsign),
                    child: const Text('⇅ قلب اتجاه الحقل')),
                OutlinedButton(
                    onPressed: () => _impulse(-1),
                    child: const Text('دفعة يسار')),
                OutlinedButton(
                    onPressed: () => _impulse(1),
                    child: const Text('دفعة يمين')),
                OutlinedButton(
                    onPressed: _startReplay,
                    child: const Text('⏺ إعادة بطيئة ×٠٫٢٥')),
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
                    'القضيب واقفة داخل الحقل دون حركة — ماذا يقرأ العدّاد؟',
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
                          'قراءة ثابتة ما دامت القضيب داخل الحقل',
                          'صفر — لا تغيّر في التدفق بلا حركة',
                          'قراءة متذبذبة',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — ε = B·L·v: بلا حركة لا تغيّر تدفق ولا ق.د.ك'
                        : '✘ ε = B·L·v: النصيب من التدفق ثابت بلا حركة ⇒ ε = 0',
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
              _chip('ε = ${toAr(eps.toStringAsFixed(3))}V'),
              _chip('الذروات: ${toAr(peakP.toStringAsFixed(2))} / ${toAr(peakN.toStringAsFixed(2))}'),
              if (!_challengeDoneToday)
                _chip(
                    won
                        ? '🎯 منجز!'
                        : '🎯 انحرافان متعاكسان ≥ ٦٠٪ (دفعة يمين ثم يسار)',
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
                child: Text('ε = B·L·v — القضيب يقصّ خطوط الحقل بمعدل B·L·v ويبر',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('القراءة تظهر فقط أثناء الحركة وتنعدم لحظة التوقف — v=0 ⟹ ε=0 (جرّب!).'),
              _explainLine('مضاعفة v أو B أو L تضاعف ε خطياً — القضيب الأطول يقصّ خطوطاً أكثر.'),
              _explainLine('قلب اتجاه الحقل (أو الحركة) ينعكس الإبر — اتجاه الحركة يحدد قطبية ε بقاعدة اليد اليمنى.'),
              _explainLine('الإطار: قوة لورنتس على شحنات القضيب تكدّسها عند طرفيه — العدّاد يقيس ناتج هذا الفصل.'),
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

class _BlvrailsPainter extends CustomPainter {
  _BlvrailsPainter(this.st);
  final _BlvrailsScreenState st;

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
          '🔒 يُفتح الشرح بعد أول حركة تُقرأ — ادفع القضيب أو اسحبه!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
