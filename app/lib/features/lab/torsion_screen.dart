import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U1-1..4 نواس الفتل المخبري (نمط موحّد معتمد).
/// I = ½MR² + 2mr² · K = 0.1213/l · T₀ = 2π√(I/K) · مؤقت ١٠ نوسات.
/// أوضاع: توازن (θ=τ/K) · تج١ الدور والسعة · تج٢ الكتلتان (r) · تج٣ نصف السلك (l).
/// تحدّي: قياسان بسعتين مختلفتين وفرق الدور < ٢٪ (+١٠) بمفتاح 'torsion'.
class TorsionScreen extends StatefulWidget {
  const TorsionScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<TorsionScreen> createState() => _TorsionScreenState();
}

class _TorsionScreenState extends State<TorsionScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-torsion.html المعتمد) ──
  static const double mBig = 0.6, rBig = 0.15, mPt = 0.25;
  int mode = 2; // 1 توازن · 2 تج١ · 3 تج٢ · 4 تج٣
  double l = 1.0, r = 0.08, amp = 30 * math.pi / 180;
  double th = 0, thV = 0, thetaStatic = 0;
  bool rel = false;
  double t = 0;
  // مؤقت ١٠ نوسات
  bool timingOn = false;
  double timingT0 = 0;
  int timingN = 0;
  double timingT10 = 0;
  final List<({double tSec, double ampDeg})> meas = <({double tSec, double ampDeg})>[];
  String measText = 'المؤقت: —';
  bool won = false;

  double get iOf => 0.5 * mBig * rBig * rBig + 2 * mPt * r * r;
  double get kOf => 0.1213 / l;
  double get tOf => 2 * math.pi * math.sqrt(iOf / kOf);
  double get ampDeg => amp * 180 / math.pi;

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
        _data.labChallengeDays['torsion'] == dateKeyOf(DateTime.now());
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
      if (rel) {
        final thV2 = -(kOf / iOf) * th;
        thV += thV2 * st;
        final prev = th;
        th += thV * st;
        if (timingOn) {
          if (timingN < 10 && prev <= 0 && th > 0) {
            timingN++;
            if (timingN >= 10) {
              timingT10 = t;
              _endTiming();
            }
          }
        }
      } else {
        th = thetaStatic;
        thV = 0;
      }
    }
  }

  void _endTiming() {
    final t10 = timingT10 - timingT0;
    final tOne = t10 / 10;
    meas.add((tSec: tOne, ampDeg: ampDeg));
    measText = '10T = ${toAr(t10.toStringAsFixed(2))}s ⇒ T = ${toAr(tOne.toStringAsFixed(3))}s';
    if (meas.length >= 2 && !_challengeDoneToday && !won) {
      final a = meas[meas.length - 2], b = meas[meas.length - 1];
      if ((a.ampDeg - b.ampDeg).abs() >= 8 &&
          (a.tSec - b.tSec).abs() / a.tSec < 0.02) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    }
    timingOn = false;
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
        'torsion': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'torsion'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _release() {
    setState(() {
      rel = true;
      th = amp;
      thV = 0;
      timingOn = true;
      timingT0 = t;
      timingN = 0;
    });
  }

  void _stop() {
    setState(() {
      rel = false;
      thetaStatic = th;
      timingOn = false;
    });
  }

  void _reset() {
    setState(() {
      rel = false;
      th = amp;
      thetaStatic = amp;
      meas.clear();
      measText = 'المؤقت: —';
      won = false;
    });
  }

  String get modeHint {
    if (mode == 1) return 'اسحب القرص لتطبّق عزماً — الرجوعي −Kθ يوازنه';
    if (mode == 2) return 'تج١: غيّر السعة ثم «لف وأترك» — الدور ثابت';
    if (mode == 3) return 'تج٢: بعّد الكتلتين (r) — العطالة ترفع الدور';
    return 'تج٣: انصّف طول سلك الفتل (l) — الدور ينقص';
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 340.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final bx = w * 0.5, topY = 46.0, discY = 250.0, discR = 95.0;
    // حامل علوي + سلك الفتل
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx - 70, topY - 18, 140, 14),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF232320));
    c.drawLine(Offset(bx, topY - 4), Offset(bx, discY),
        Paint()
          ..color = const Color(0xFFC9C2A8)
          ..strokeWidth = 2);
    // لفات الفتل
    for (var k = 0; k < 5; k++) {
      c.drawLine(
          Offset(bx - 5, topY + 6.0 + k * 9),
          Offset(bx + 5, topY + 10.0 + k * 9),
          Paint()
            ..color = const Color(0xFF9A9A94)
            ..strokeWidth = 1.6);
    }
    // القرص النحاسي بزاوية th
    c.save();
    c.translate(bx, discY);
    c.rotate(th);
    c.drawCircle(Offset.zero, discR,
        Paint()..color = const Color.fromRGBO(205, 160, 90, 0.14));
    c.drawCircle(
        Offset.zero,
        discR,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFC89A5A)
          ..strokeWidth = 8);
    // قضيب الكتلتين + الكتلتان النقطيتان عند r
    final rrPx = r / 0.15 * discR * 1.35;
    c.drawLine(Offset(-discR + 10, 0), Offset(discR - 10, 0),
        Paint()
          ..color = const Color(0xFF8F8F8A)
          ..strokeWidth = 5);
    for (final sgn in [-1.0, 1.0]) {
      c.drawCircle(Offset(sgn * rrPx, 0), 11,
          Paint()..color = const Color(0xFF4A4540));
      c.drawCircle(Offset(sgn * rrPx, -2), 4,
          Paint()..color = const Color(0xFF7A746C));
    }
    c.drawCircle(Offset.zero, 9, Paint()..color = const Color(0xFF3A3A38));
    c.restore();
    // قوس السعة المرجعي
    c.drawArc(
        Rect.fromCircle(center: Offset(bx, discY), radius: discR + 16),
        -math.pi / 2 - amp,
        2 * amp,
        false,
        Paint()
          ..color = const Color.fromRGBO(240, 150, 74, 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    // إبرة الاتزان بالوضع ١
    if (mode == 1 && thetaStatic != 0) {
      c.drawArc(
          Rect.fromCircle(center: Offset(bx, discY), radius: 44),
          -math.pi / 2,
          thetaStatic,
          false,
          Paint()
            ..color = const Color.fromRGBO(240, 150, 74, 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      _arabic(c, 'عزم مُطبَّق ⇄ رجوعي −Kθ (اتزان)', Offset(bx, discY + 34), 12,
          const Color(0xFF7FB894));
    }
    _arabic(
        c,
        'I = ${toAr(iOf.toStringAsFixed(4))} kg·m² · T₀ نظري = ${toAr(tOf.toStringAsFixed(3))}s',
        Offset(w / 2, 26),
        13,
        const Color(0xFFE8E2D0));
    _arabic(c, measText, Offset(w / 2, size.height - 16), 13.5,
        timingOn || meas.isNotEmpty
            ? const Color(0xFF8CFFAA)
            : const Color.fromRGBO(156, 195, 223, 0.8));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const discY = -10.0, discR = 95.0;
    // سلك الفتل من الأعلى
    line3(c, cam, size, const P3(0, 220, 0), const P3(0, discY, 0),
        const Color(0xFFC9C2A8), 2);
    // القرص: حلقة خارجية + أقطار
    ring3(c, cam, size, 0, discR, const Color(0xE6C89A5A), 5);
    for (final rr in [discR * 0.33, discR * 0.66]) {
      line3(c, cam, size, P3(-rr, discY, 0), P3(rr, discY, 0),
          const Color.fromRGBO(205, 160, 90, 0.25), 1);
      line3(c, cam, size, P3(0, discY, -rr), P3(0, discY, rr),
          const Color.fromRGBO(205, 160, 90, 0.25), 1);
    }
    // قضيب الكتلتين يدور بth (دوران حول المحور الرأسي: x,z)
    final cs = math.cos(th), sn = math.sin(th);
    final rodA = P3(-discR * cs, discY, discR * sn);
    final rodB = P3(discR * cs, discY, -discR * sn);
    line3(c, cam, size, rodA, rodB, const Color(0xFF8F8F8A), 5);
    final rrPx = r / 0.15 * discR * 1.35;
    for (final sgn in [-1.0, 1.0]) {
      final p = cam.project(
          P3(sgn * rrPx * cs, discY, -sgn * rrPx * sn), size);
      c.drawCircle(Offset(p.x, p.y), 7.5,
          Paint()..color = const Color(0xFF4A4540));
    }
    final hub = cam.project(const P3(0, discY, 0), size);
    c.drawCircle(Offset(hub.x, hub.y), 5, Paint()..color = const Color(0xFF3A3A38));
    // قوس السعة
    final arcPts = <P3>[];
    for (var k = 0; k <= 20; k++) {
      final a = -amp + 2 * amp * k / 20;
      arcPts.add(P3(math.sin(a) * (discR + 18), discY, -math.cos(a) * (discR + 18)));
    }
    stroke3(c, cam, size, arcPts, const Color.fromRGBO(240, 150, 74, 0.55), 1.6);
    _arabic(c, modeHint, Offset(size.width / 2, size.height - 34), 12,
        const Color.fromRGBO(205, 198, 182, 0.6));
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        'I = ${toAr(iOf.toStringAsFixed(4))} · K = ${toAr(kOf.toStringAsFixed(3))}N·m/rad · T₀ = ${toAr(tOf.toStringAsFixed(3))}s',
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
      appBar: AppBar(title: const Text('المختبر: نواس الفتل المخبري')),
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
                painter: _TorsionPainter(this),
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
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                for (var m = 1; m <= 4; m++)
                  ChoiceChip(
                    label: Text(const [
                      'تمهيد: التوازن',
                      'تج١: الدور والسعة',
                      'تج٢: الكتلتان (r)',
                      'تج٣: نصف السلك (l)',
                    ][m - 1]),
                    selected: mode == m,
                    onSelected: (_) => setState(() {
                      mode = m;
                      rel = false;
                      if (m == 1) {
                        thetaStatic = th == 0 ? amp : th;
                      }
                    }),
                  ),
              ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'طول سلك الفتل l',
                  value: l,
                  min: 0.5, max: 1.5, divisions: 20,
                  display: '${toAr(l.toStringAsFixed(2))}m',
                  onChanged: (x) => setState(() {
                        l = x;
                        rel = false;
                        th = amp;
                      })),
              LabSlider(
                  label: 'بُعد الكتلتين r',
                  value: r,
                  min: 0.04, max: 0.14, divisions: 10,
                  display: '${toAr(r.toStringAsFixed(2))}m',
                  onChanged: (x) => setState(() {
                        r = x;
                        rel = false;
                        th = amp;
                      })),
              LabSlider(
                  label: 'السعة',
                  value: ampDeg,
                  min: 10, max: 45, divisions: 35,
                  display: '${toAr(ampDeg.round())}°',
                  onChanged: (x) => setState(() {
                        amp = x * math.pi / 180;
                        if (!rel) th = amp;
                      })),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(onPressed: _release, child: const Text('↻ لف وأترك')),
                OutlinedButton(onPressed: _stop, child: const Text('⏹ توقف')),
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
                    'بعّدنا الكتلتين النقطيتين للخارج (تضاعف r تقريباً) — ماذا يحدث لدور التذبذب T₀؟',
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
                          if (oi + 1 == 1) {
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
                                  ? (oi + 1 == 1
                                      ? const Color(0xFF538065)
                                      : const Color(0xFFBB5A45))
                                  : const Color(0xFFDCD8CC)),
                        ),
                        child: Text(const [
                          'يزداد — العطالة تزداد مع r²',
                          'يبقى ثابتاً — الكتلة لم تتغير',
                          'ينقص',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 1
                        ? '✔ صحيح — I = ½MR² + 2mr²: البعد يرفع العطالة ويبطّئ الدور'
                        : '✘ T₀ = 2π√(I/K): العطالة تزداد مع r² حتى لو ثابتة الكتلة',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _predictPick == 1
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
              _chip('T₀ نظري = ${toAr(tOf.toStringAsFixed(3))}s'),
              _chip('I = ${toAr(iOf.toStringAsFixed(4))}kg·m²'),
              _chip(measText),
              if (!_challengeDoneToday)
                _chip(
                    won
                        ? '🎯 منجز!'
                        : '🎯 تج١: قس عند سعتين مختلفتين — الفرق < ٢٪',
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
                child: Text('T₀ = 2π√(I/K) · I = ½MR² + 2mr² · K ∝ 1/l',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 16)),
              ),
              const SizedBox(height: 6),
              _explainLine('عزم العطالة: القرص ½MR² + الكتلتان النقطيتان 2mr² — البعد أقوى أثراً من الكتلة.'),
              _explainLine('ثابت الفتل K يزداد بقصر السلك: نصف l ⇒ K يتضاعف ⇒ T₀ ينقص إلى ≈ ٠٫٧١× (تج٣).'),
              _explainLine('تج١: الدور مستقل عن السعة (لزوايا صغيرة) — قِس بسعتين والفرق < ٢٪.'),
              _explainLine('المؤقت يقيس زمن ١٠ نوسات ويقسمها — قياس أدق من نوسة واحدة بعشرة أمثال.'),
              if (meas.isEmpty && !_challengeDoneToday) const _LockedVeil(),
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

class _TorsionPainter extends CustomPainter {
  _TorsionPainter(this.st);
  final _TorsionScreenState st;

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
          '🔒 يُفتح الشرح بعد أول قياس — «لف وأترك» وانتظر العدّ!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
