import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٤ — U2-5 ⭐ ملفا هلمهولتز (نمط موحّد معتمد).
/// r(cm)=0.45·√(U/I) · مسار دائري حي · تحدّي r=4.0±0.3cm (+١٠).
/// منظور واقعي (ملفان + حزمة خضراء متوهجة) + منظور 3D مداري بنفس الحالة.
class HelmholtzScreen extends StatefulWidget {
  const HelmholtzScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<HelmholtzScreen> createState() => _HelmholtzScreenState();
}

class _HelmholtzScreenState extends State<HelmholtzScreen>
    with SingleTickerProviderStateMixin {
  double u = 250, isA = 1.5;
  double ang = 0, t = 0; // طور دوران الإلكترون
  bool beam = true, view3d = false, started = false, won = false;

  static const double pxPerCm = 12;

  double get rCm => 0.45 * math.sqrt(u) / isA;
  double get rPx => rCm * pxPerCm;
  bool get inChallenge => (rCm - 4.0).abs() <= 0.3;

  final OrbitCam cam = OrbitCam(dist: 660, fov: 660);
  final List<Star> stars = makeStars();
  bool _orbiting = false;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _challengeDoneToday = false;
  late TrainingData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['helmholtz'] == dateKeyOf(DateTime.now());
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
    if (beam) ang = (ang + 1.6 * dt) % 1;
    if (beam && inChallenge && !won && !_challengeDoneToday) {
      won = true;
      HapticFeedback.mediumImpact();
      _recordChallenge();
    }
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'helmholtz': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'helmholtz'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _paintReal(Canvas c, Size size) {
    const benchTop = 320.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final cxw = size.width / 2, cyw = 205.0;

    // الملفان (قطع أمامي): طوقان بيضاويان نحاسيان
    for (final s in [-1.0, 1.0]) {
      final ex = cxw + s * 135;
      c.drawOval(Rect.fromCenter(center: Offset(ex, cyw), width: 56, height: 260),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..color = const Color(0xFFB98A4A));
      c.drawOval(Rect.fromCenter(center: Offset(ex, cyw), width: 56, height: 260),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = kBrass);
    }
    // أسهم الحقل بين الملفين
    for (var k = -2; k <= 2; k++) {
      final ax = cxw + k * 54.0;
      c.drawLine(Offset(ax, cyw - 118), Offset(ax, cyw - 78),
          Paint()
            ..color = const Color.fromRGBO(120, 160, 220, .5)
            ..strokeWidth = 2);
      c.drawTriangle(
          Offset(ax, cyw - 72), 7, const Color.fromRGBO(120, 160, 220, .55));
    }
    // بندقية الإلكترون
    c.drawRect(Rect.fromCenter(center: Offset(cxw - rPx - 34, cyw), width: 44, height: 26),
        Paint()..color = const Color(0xFF8C8C86));
    // المسار الدائري المتوهج
    if (beam) {
      c.drawCircle(Offset(cxw, cyw), rPx,
          Paint()..color = const Color.fromRGBO(120, 255, 190, 0.06));
      c.drawCircle(Offset(cxw, cyw), rPx,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFF78FFBE)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));
      final a = ang * 2 * math.pi;
      c.drawCircle(Offset(cxw + math.cos(a) * rPx, cyw + math.sin(a) * rPx), 4.5,
          Paint()..color = const Color(0xFFD6FFE9));
      c.drawLine(
          Offset(cxw, cyw),
          Offset(cxw + math.cos(a) * rPx, cyw + math.sin(a) * rPx),
          Paint()
            ..color = const Color.fromRGBO(120, 255, 190, .3)
            ..strokeWidth = 1);
    }
    _arabic(c, 'r = ${toAr(rCm.toStringAsFixed(2))}cm',
        Offset(cxw, cyw - rPx - 18), 14, kGlow);
    _readout(c, size, [
      'r = ${toAr(rCm.toStringAsFixed(2))}cm · U = ${toAr(u.round())}V · I = ${toAr(isA.toStringAsFixed(1))}A',
      inChallenge ? '🏆 ضمن 4.0±0.3cm' : 'r = 0.45·√(U/I) · هدف: 4.0±0.3cm',
    ]);
  }

  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const cyc = 30.0, rc = 130.0, dx = 135.0;
    // الملفان
    for (final s in [-1.0, 1.0]) {
      final pts = <P3>[];
      for (var i = 0; i <= 64; i++) {
        final a = i / 64 * 2 * math.pi;
        pts.add(P3(s * dx, cyc + math.cos(a) * rc, math.sin(a) * rc));
      }
      stroke3(c, cam, size, pts, const Color(0x80C89A5A), 4, close: true);
      stroke3(c, cam, size, pts, kBrass, 1.6, close: true);
    }
    // أسهم الحقل
    if (beam) {
      for (var k = -2; k <= 2; k++) {
        line3(c, cam, size, P3(k * 90.0, cyc + rc + 46, 0),
            P3(k * 90.0, cyc + rc + 16, 0),
            const Color.fromRGBO(120, 160, 220, 0.45), 1.8);
      }
    }
    // المدار المتوهج (مستوى y-z)
    if (beam) {
      final pts = <P3>[];
      for (var i = 0; i <= 72; i++) {
        final a = i / 72 * 2 * math.pi;
        pts.add(P3(0, cyc + math.cos(a) * rPx, math.sin(a) * rPx));
      }
      stroke3(c, cam, size, pts, const Color(0xD978FFBE), 2.5, close: true);
      final a0 = ang * 2 * math.pi;
      final ep = cam.project(P3(0, cyc + math.cos(a0) * rPx, math.sin(a0) * rPx), size);
      c.drawCircle(Offset(ep.x, ep.y), 4, Paint()..color = const Color(0xFFD6FFE9));
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 12), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _readout(c, size, [
      'r = ${toAr(rCm.toStringAsFixed(2))}cm · U = ${toAr(u.round())}V · I = ${toAr(isA.toStringAsFixed(1))}A',
      inChallenge ? '🏆 ضمن 4.0±0.3cm' : 'الهدف: 4.0±0.3cm',
    ]);
  }

  void _readout(Canvas c, Size size, List<String> lines) {
    final r = Rect.fromLTWH(16, 12, 260, 18 + lines.length * 22);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = const Color(0xD20D1016));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(205, 215, 230, 0.3));
    for (var i = 0; i < lines.length; i++) {
      _arabic(c, lines[i], Offset(r.left + r.width / 2, r.top + 22 + i * 22),
          12, i == 0 ? kInkLight : kGlow);
    }
  }

  void _arabic(Canvas c, String s, Offset at, double size, Color col) {
    final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(fontSize: size, color: col, fontFamily: 'Tahoma')),
        textDirection: TextDirection.rtl)
      ..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المختبر: ملفا هلمهولتز — المسار الدائري')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 440,
            child: GestureDetector(
              onPanStart: view3d ? (_) {
                _orbiting = true;
              } : null,
              onPanUpdate: view3d ? (d) {
                if (!_orbiting) return;
                cam.yaw += d.delta.dx * 0.008;
                cam.pitch = (cam.pitch + d.delta.dy * 0.008).clamp(-0.05, 1.0);
              } : null,
              onPanEnd: (_) => _orbiting = false,
              child: CustomPaint(painter: _HPainter(this), child: const SizedBox.expand()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              LabSlider(
                  label: 'توتر التسريع U',
                  value: u, min: 100, max: 400, divisions: 60,
                  display: '${toAr(u.round())}V',
                  onChanged: (x) => setState(() => u = x)),
              LabSlider(
                  label: 'تيار الملفين I',
                  value: isA, min: 0.6, max: 3, divisions: 24,
                  display: '${toAr(isA.toStringAsFixed(1))}A',
                  onChanged: (x) => setState(() => isA = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                ViewToggle(view3d: view3d, onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => beam = !beam),
                    child: Text(beam ? 'إطفاء الحزمة' : 'إشعال الحزمة')),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('r = ${toAr(rCm.toStringAsFixed(2))}cm'),
              _chip('U = ${toAr(u.round())}V · I = ${toAr(isA.toStringAsFixed(1))}A'),
              if (!_challengeDoneToday)
                _chip(inChallenge ? '🎯 منجز!' : '🎯 اضبط r = 4.0±0.3cm', ok: inChallenge)
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
                  child: Text('r = mv/(qB) ⇒ r(cm) = 0.45·√(U/I)',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16))),
              const SizedBox(height: 6),
              _line('الحزمة تدخل عمودياً على حقل منتظم بين الملفين فترسم دائرة — نصف قطرها مقياس للسرعة.'),
              _line('مضاعفة U تضاعف السرعة ⇒ r يكبر بـ√؛ مضاعفة I تكبّر B ⇒ r يصغر بالعكس.'),
              _line('هلمهولتز ينتجان حقل شبه منتظم في المركز — لهذا نستطيع قياس e/m بهذا الجهاز.'),
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
          border: Border.all(
              color: ok ? const Color(0xFF538065) : const Color(0xFFDCD8CC)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(s,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: ok ? FontWeight.w700 : FontWeight.w400,
                color: ok ? const Color(0xFF538065) : null)),
      );

  Widget _line(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('• $s', style: const TextStyle(fontSize: 13.5)),
      );
}

extension _Tri on Canvas {
  void drawTriangle(Offset top, double r, Color col) {
    final p = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx - r, top.dy + r * 1.6)
      ..lineTo(top.dx + r, top.dy + r * 1.6)
      ..close();
    drawPath(p, Paint()..color = col);
  }
}

class _HPainter extends CustomPainter {
  _HPainter(this.st);
  final _HelmholtzScreenState st;

  @override
  void paint(Canvas c, Size size) =>
      st.view3d ? st._paint3D(c, size) : st._paintReal(c, size);

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
      child: const Text('🔒 يُفتح الشرح بعد أول مسار دائري تراه (شغّل الحزمة).',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
