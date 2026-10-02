import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-6/7 القوة على سلك يمر به تيار + دولاب بارلو (نمط موحّد معتمد).
/// F = B·I·L · القوة ⊥ B ⊥ I (قاعدة اليد اليمنى) · تحدّي: أظهر انعكاس القوة
/// بقلب I وحده (سلك) أو انعكاس الدوران بقلب القطبية (بارلو) — (+١٠).
/// منظور واقعي (حدوة مدرسية / قرص بارلو) + منظور 3D مداري بنفس الحالة.
class FbilScreen extends StatefulWidget {
  const FbilScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<FbilScreen> createState() => _FbilScreenState();
}

class _FbilScreenState extends State<FbilScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-fbil.html المعتمد) ──
  int mode = 1;
  double i = 3, b = 0.8;
  int iD = 1, bD = 1;
  double t = 0, wy = 0, wv = 0, phi = 0, om = 0;
  bool started = false, won = false, won2 = false, view3d = false;
  bool sawUp = false, sawDown = false;
  int? dirBefore;

  static const double lWire = 0.08;
  double get fMag => i * b * lWire * iD * bD;
  double get rpm => om.abs() * 60 / (2 * math.pi);

  // ── الكاميرا والنجوم ──
  final OrbitCam cam = OrbitCam(dist: 640, fov: 640);
  final List<Star> stars = makeStars();
  bool _orbiting = false;
  Offset _lastPan = Offset.zero;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _acc = 0;
  bool _challengeDoneToday = false;
  bool _predictDone = false;
  int? _predictPick;
  late TrainingData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['fbil'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step(double dt0) {
    const st = 1 / 240;
    final f = fMag;
    if (mode == 1) {
      if (f > 0.02) started = true;
      final target = started ? f * 130 : 0.0;
      final a = (target - wy) * 30 - 8 * wv;
      wv += a * st;
      wy += wv * st;
      if (f > 0.05) sawUp = true;
      if (f < -0.05) sawDown = true;
      if (sawUp && sawDown && !won && !_challengeDoneToday) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    } else {
      final tau = i * b * 0.06 * iD * bD - 0.02 * om;
      om += tau * st * 22;
      phi += om * st;
      if (dirBefore == null && om.abs() > 0.5) {
        dirBefore = om.sign;
      } else if (dirBefore != null &&
          om.sign != dirBefore &&
          om.abs() > 0.5 &&
          !won2 &&
          !_challengeDoneToday) {
        won2 = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    }
    t += dt0;
  }

  void _tick(Duration el) {
    final dt = _last == Duration.zero
        ? 1 / 240
        : math.min((el - _last).inMicroseconds / 1e6, 0.1);
    _last = el;
    _acc += dt;
    while (_acc >= 1 / 240) {
      _acc -= 1 / 240;
      _step(dt);
    }
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'fbil': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'fbil'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      iD = 1;
      bD = 1;
      wy = 0;
      wv = 0;
      phi = 0;
      om = 0;
      sawUp = false;
      sawDown = false;
      won = false;
      won2 = false;
      dirBefore = null;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 320.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    if (mode == 1) {
      // حدوة حذاء مدرسية: قطبان + قوس خلفي
      final nx = w * 0.375, sx = w * 0.625, gy = benchTop - 10;
      c.drawOval(
          Rect.fromCenter(
              center: Offset(w / 2, benchTop + 10), width: 300, height: 24),
          Paint()..color = const Color(0x801E0F05));
      c.drawArc(
          Rect.fromCircle(center: Offset(w / 2, 180), radius: 150),
          math.pi * 0.98, math.pi * 1.04, false,
          Paint()
            ..color = const Color(0xFFB3372B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 34
            ..strokeCap = StrokeCap.round);
      final pn = Paint()
        ..shader = ui.Gradient.linear(
            Offset(nx - 17, 0), Offset(nx + 17, 0), const [
          Color(0xFF8C281D),
          Color(0xFFCE4436),
          Color(0xFF8C281D),
        ]);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(nx - 17, 150, 34, gy - 150),
              const Radius.circular(6)),
          pn);
      final ps = Paint()
        ..shader = ui.Gradient.linear(
            Offset(sx - 17, 0), Offset(sx + 17, 0), const [
          Color(0xFF24497C),
          Color(0xFF3E6FA8),
          Color(0xFF24497C),
        ]);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(sx - 17, 150, 34, gy - 150),
              const Radius.circular(6)),
          ps);
      _arabic(c, 'N', Offset(nx, 142), 16, const Color(0xFFFFD9CE));
      _arabic(c, 'S', Offset(sx, 142), 16, const Color(0xFFCFE3F7));
      // نافذة الحقل
      c.drawRect(
          Rect.fromLTWH(nx + 17, 150, sx - nx - 34, gy - 150),
          Paint()..color = const Color.fromRGBO(240, 150, 74, 0.06));
      // حامل + خيوط تعليق + السلك
      final yw = 228.0 - wy;
      c.drawLine(Offset(w * 0.73, 96), Offset(w * 0.73, gy),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 10);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.71 - 14, 88, 50, 14),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFF3A3A38));
      for (final hx in [0.583, 0.417]) {
        c.drawLine(Offset(w * 0.735, 102), Offset(w * hx, yw),
            Paint()
              ..color = const Color.fromRGBO(210, 205, 190, 0.8)
              ..strokeWidth = 1.4);
      }
      c.drawLine(
          Offset(w * 0.385, yw),
          Offset(w * 0.615, yw),
          Paint()
            ..color = const Color(0xFFD9D9D4)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
      // سهم القوة
      if (fMag.abs() > 0.01) {
        final dF = -fMag.sign;
        final fl = 20 + wy.abs() * 0.45;
        final y0 = yw + 10, y1 = y0 + dF * fl;
        c.drawLine(Offset(w / 2, y0), Offset(w / 2, y1),
            Paint()
              ..color = const Color.fromRGBO(240, 150, 74, 0.95)
              ..strokeWidth = 4.5);
        final tip = Offset(w / 2, y0 + dF * (fl + 9));
        _arrowHead(c, Offset(w / 2, y1), tip,
            const Color.fromRGBO(240, 150, 74, 0.95));
        _arabic(
            c,
            'F = ${toAr(fMag.abs().toStringAsFixed(2))}N',
            Offset(w / 2, y0 + dF * (fl + 24)),
            13,
            const Color(0xFFF0964A));
      }
      _arabic(
          c,
          'I = ${toAr(i.toStringAsFixed(1))}A · B = ${toAr(b.toStringAsFixed(1))}T',
          Offset(w / 2, 52),
          12.5,
          const Color(0xFFE8E2D0));
      _arabic(
          c,
          iD * bD > 0 ? 'قلبت I وB معاً — الاتجاه بقى' : 'انعكاس القوة!',
          Offset(w / 2, 72),
          12,
          iD * bD > 0
              ? const Color.fromRGBO(232, 226, 208, 0.6)
              : const Color(0xFFF0964A));
    } else {
      // دولاب بارلو
      final bx = w * 0.448, by = 225.0, r = 118.0;
      c.drawOval(
          Rect.fromCenter(
              center: Offset(bx, 342), width: 300, height: 22),
          Paint()..color = const Color(0x801E0F05));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx - 70, 334, 140, 12),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF1E1B16));
      c.drawLine(Offset(bx - 5, 282), Offset(bx - 5, 336),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 10);
      // مغناطيس U يلف قاع القرص
      c.drawArc(Rect.fromCircle(center: Offset(bx, 238), radius: r + 34),
          math.pi * 0.32, math.pi * 0.36, false,
          Paint()
            ..color = const Color(0xFFB3372B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 26
            ..strokeCap = StrokeCap.round);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx - r - 30, 272, 30, 52),
              const Radius.circular(6)),
          Paint()
            ..shader = ui.Gradient.linear(Offset(bx - r - 26, 0),
                Offset(bx - r + 26, 0), const [
              Color(0xFF8C281D),
              Color(0xFFCE4436),
            ]));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx + r, 272, 30, 52), const Radius.circular(6)),
          Paint()
            ..shader = ui.Gradient.linear(Offset(bx + r - 26, 0),
                Offset(bx + r + 26, 0), const [
              Color(0xFF3E6FA8),
              Color(0xFF24497C),
            ]));
      _arabic(c, 'N', Offset(bx - r - 15, 266), 13, const Color(0xFFFFD9CE));
      _arabic(c, 'S', Offset(bx + r + 15, 266), 13, const Color(0xFFCFE3F7));
      // القرص النحاسي الدوار
      c.drawCircle(Offset(bx, by), r + 10,
          Paint()..color = const Color.fromRGBO(205, 160, 90, 0.10));
      c.drawCircle(
          Offset(bx, by),
          r,
          Paint()
            ..color = const Color(0xFFC89A5A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..maskFilter = const ui.MaskFilter.blur(
                ui.BlurStyle.solid, 4));
      c.drawCircle(
          Offset(bx, by),
          r - 16,
          Paint()
            ..color = const Color.fromRGBO(205, 160, 90, 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      for (var k = 0; k < 4; k++) {
        final a = phi + k * math.pi / 2;
        c.drawLine(
            Offset(bx + math.cos(a) * 14, by + math.sin(a) * 14),
            Offset(bx + math.cos(a) * (r - 6),
                by + math.sin(a) * (r - 6)),
            Paint()
              ..color = const Color.fromRGBO(205, 160, 90, 0.6)
              ..strokeWidth = 4.5);
      }
      c.drawCircle(Offset(bx, by), 13, Paint()..color = const Color(0xFF8F8F8A));
      c.drawCircle(Offset(bx, by), 5, Paint()..color = const Color(0xFF3A3A38));
      // سهم الدوران
      if (om.abs() > 0.1) {
        final dd = om.sign;
        c.drawArc(Rect.fromCircle(center: Offset(bx, by), radius: r * 0.45),
            dd > 0 ? -1.2 : 2.2, dd > 0 ? 2.2 : -2.4, false,
            Paint()
              ..color = const Color.fromRGBO(240, 150, 74, 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5);
      }
      _arabic(c, 'بارلو — أول محرك كهربائي', Offset(bx, 58), 12.5,
          const Color.fromRGBO(232, 226, 208, 0.65));
      _arabic(
          c,
          'ω = ${toAr(rpm.round())}rpm · اتجاه: ${om > 0 ? '↻' : '↺'}',
          Offset(bx, 78),
          12.5,
          const Color(0xFFF0964A));
    }
    _readout(c, size, [
      'F = BIL = ${toAr(fMag.abs().toStringAsFixed(3))}N',
      'iD = ${iD > 0 ? '+١' : '−١'} · bD = ${bD > 0 ? '+١' : '−١'} · L = ٨cm',
    ]);
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    if (mode == 1) {
      const p = 64.0;
      final nCol = const Color(0xF2B23A34), sCol = const Color(0xF23E6FA8);
      for (final sgn in [-1.0, 1.0]) {
        final xx = sgn * 120;
        final col = sgn < 0 ? nCol : sCol;
        stroke3(c, cam, size, [
          P3(xx, 60, -p), P3(xx, -60, -p), P3(xx, -60, p), P3(xx, 60, p),
        ], col, 8, close: true);
        final q = cam.project(P3(xx, 64, 0), size);
        _arabic(c, sgn < 0 ? 'N' : 'S', Offset(q.x, q.y - 14), 15,
            sgn < 0 ? const Color(0xFFFFD9CE) : const Color(0xFFCFE3F7));
      }
      for (var k = 0; k < 8; k++) {
        final a = (k + 0.5) / 8 * math.pi;
        final x0 = -120 * math.cos(a), y0 = 60 + 150 * math.sin(a);
        line3(c, cam, size, P3(x0, y0, -p), P3(x0, y0, p),
            k % 2 == 1
                ? const Color(0xB3B23A34)
                : const Color(0xB396281E),
            8);
      }
      // السلك الفضي بين القطبين يتحرك بwy
      final yw = 10.0 - wy * 0.5;
      line3(c, cam, size, P3(-110, yw, 0), P3(110, yw, 0),
          const Color(0xFFD9D9D4), 6);
      // سهم القوة
      if (fMag.abs() > 0.01) {
        final dF = fMag.sign;
        final y1 = yw + dF * (30 + wy.abs() * 0.35);
        line3(c, cam, size, P3(0, yw, 0), P3(0, y1, 0),
            const Color(0xF2F0964A), 5);
        final ap = cam.project(P3(0, y1, 0), size);
        _arrowHead(
            c,
            Offset(ap.x, ap.y),
            Offset(ap.x, ap.y + (dF > 0 ? -9 : 9)),
            const Color.fromRGBO(240, 150, 74, 0.95));
      }
    } else {
      const r = 110.0;
      ring3(c, cam, size, 0, r, const Color(0xE6CDA05A), 4);
      for (var k = 0; k < 4; k++) {
        final a = phi + k * math.pi / 2;
        line3(c, cam, size, P3(0, 10, 0),
            P3(0, 10 + math.cos(a) * r, math.sin(a) * r),
            const Color(0x8CCDA05A), 3);
      }
      line3(c, cam, size, P3(0, 10, -16), P3(0, 10, 16),
          const Color(0xE6C8C8C3), 6);
      for (final sgn in [-1.0, 1.0]) {
        final xx = sgn * 46;
        final col =
            sgn < 0 ? const Color(0xE6B23A34) : const Color(0xE63E6FA8);
        stroke3(c, cam, size, [
          P3(xx, -140, -56), P3(xx, -66, -56), P3(xx, -66, 56), P3(xx, -140, 56),
        ], col, 7, close: true);
        final q = cam.project(P3(xx, -70, 0), size);
        _arabic(c, sgn < 0 ? 'N' : 'S', Offset(q.x, q.y - 10), 14,
            sgn < 0 ? const Color(0xFFFFD9CE) : const Color(0xFFCFE3F7));
      }
      if (om.abs() > 0.1) {
        final dd = om.sign;
        final p0 = cam.project(const P3(0, 10, 0), size);
        c.drawArc(
            Rect.fromCircle(
                center: Offset(p0.x, p0.y),
                radius: r * 0.72 * p0.s / cam.fov * 640 * 0.7),
            dd > 0 ? -1.1 : 2.0,
            dd > 0 ? 2.5 : -2.5,
            false,
            Paint()
              ..color = const Color.fromRGBO(240, 150, 74, 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      }
    }
    _arabic(c, 'اسحب الخلفية لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _readout(c, size, [
      'F = ${toAr(fMag.abs().toStringAsFixed(3))}N · I = ${toAr(i.toStringAsFixed(1))}A · B = ${toAr(b.toStringAsFixed(1))}T',
      iD * bD > 0
          ? 'F باتجاه اليد اليمنى (+)'
          : 'F معكوس (−) — انعكاس!',
    ]);
  }

  void _arrowHead(Canvas c, Offset base, Offset tip, Color col) {
    final dir = (tip - base);
    if (dir.distance < 1) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + n.dx * 7, base.dy + n.dy * 7)
      ..lineTo(base.dx - n.dx * 7, base.dy - n.dy * 7)
      ..close();
    c.drawPath(p, Paint()..color = col);
  }

  void _readout(Canvas c, Size size, List<String> lines) {
    final r = Rect.fromLTWH(16, 12, 240, 18 + lines.length * 22);
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = const Color(0xD20D1016));
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(205, 215, 230, 0.3));
    for (var i0 = 0; i0 < lines.length; i0++) {
      _arabic(c, lines[i0], Offset(r.left + r.width / 2, r.top + 22 + i0 * 22),
          12, i0 == 0 ? kInkLight : kGlow);
    }
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
      appBar: AppBar(title: const Text('المختبر: القوة على سلك — F = BIL')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 440,
            child: GestureDetector(
              onPanStart: view3d ? (_) {
                _orbiting = true;
                _lastPan = Offset.zero;
              } : null,
              onPanUpdate: view3d ? (d) {
                if (!_orbiting) return;
                cam.yaw += d.delta.dx * 0.008;
                cam.pitch =
                    (cam.pitch + d.delta.dy * 0.008).clamp(-0.05, 1.0);
              } : null,
              onPanEnd: (_) => _orbiting = false,
              child: CustomPaint(
                painter: _FbilPainter(this),
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
              Row(children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('U2-6 · سلك بين قطبين'),
                    selected: mode == 1,
                    onSelected: (_) => setState(() => mode = 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('U2-7 · دولاب بارلو'),
                    selected: mode == 2,
                    onSelected: (_) => setState(() => mode = 2),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'التيار I',
                  value: i,
                  min: 0, max: 6, divisions: 12,
                  display: '${toAr(i.toStringAsFixed(1))}A',
                  onChanged: (x) => setState(() => i = x)),
              LabSlider(
                  label: 'الحقل B',
                  value: b,
                  min: 0.2, max: 1.2, divisions: 10,
                  display: '${toAr(b.toStringAsFixed(1))}T',
                  onChanged: (x) => setState(() => b = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                ViewToggle(view3d: view3d, onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => iD = -iD),
                    child: const Text('⇄ قلب I')),
                OutlinedButton(
                    onPressed: () => setState(() => bD = -bD),
                    child: const Text('⇄ قلب B')),
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
                    'السلك يدفع للأعلى. اقلبنا اتجاه التيار I فقط — ماذا يحدث للقوة؟',
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
                              color: _predictPick == k
                                  ? (k == 1
                                      ? const Color(0xFF538065)
                                      : const Color(0xFFBB5A45))
                                  : const Color(0xFFDCD8CC)),
                        ),
                        child: Text(const [
                          'تتباعد — تنعكس للأسفل',
                          'تبقى للأعلى — الشدة لم تتغير',
                          'تصف — يعلق السلك',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 1
                        ? '✔ صحيح — F ∝ I×B: قلب I يعكس F. اقلب فعلاً وشاهد!'
                        : '✘ F = BIL: الاتجاه يعتمد إشارة I×B — قلب I ينعكسه',
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
              _chip('F = ${toAr(fMag.abs().toStringAsFixed(3))}N'),
              _chip(mode == 1
                  ? 'الاتجاه: ${fMag.abs() < 0.01 ? '—' : fMag > 0 ? 'لأعلى ↑' : 'لأسفل ↓'}'
                  : 'الاتجاه: ${om.abs() < 0.05 ? 'متوقف' : om > 0 ? 'عقارب الساعة ↻' : 'عكس العقارب ↺'} · rpm = ${toAr(rpm.round())}'),
              if (!_challengeDoneToday)
                _chip(
                    mode == 1
                        ? '🎯 أظهر انعكاس القوة بقلب I وحده'
                        : '🎯 شغّل القرص ثم اقلب القطبية — ينعكس الدوران',
                    ok: mode == 1 ? won : won2)
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
                child: Text('F = B·I·L · القوة ⊥ B ⊥ I (قاعدة اليد اليمنى)',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 16)),
              ),
              const SizedBox(height: 6),
              _explainLine('قلب I وحده أو B وحده ينقلب اتجاه F — قلبهما معاً يبقيه (جرّب!).'),
              _explainLine('شدّة القوة خطية: مضاعفة I تضاعف F — السلك الأطول في الحقل يقوى.'),
              _explainLine('بارلو: نفس القوة على أذرع القرص تعمل عزماً — قلب القطبية ينعكس الدوران. أول محرك كهربائي!'),
              if (!started) const _LockedVeil(),
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

class _FbilPainter extends CustomPainter {
  _FbilPainter(this.st);
  final _FbilScreenState st;

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
          color: Theme.of(context).colorScheme.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(8)),
      child: const Text(
          '🔒 يُفتح الشرح بعد أول قوة تلاحظها — ارفع I أو B!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
