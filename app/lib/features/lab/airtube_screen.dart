import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U3-6 ⭐ قرصانة عمود الهواء (نمط موحّد معتمد).
/// V=343 · Ln=(2n−1)λ/4 · هدير يعلو قرب الرنين · علامات بالمواقع
/// وتحدّي L₂≈3L₁ ضمن ±٥٪ (+١٠). واقعي (أنبوب بماء + رنانة) + 3D.
class AirtubeScreen extends StatefulWidget {
  const AirtubeScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<AirtubeScreen> createState() => _AirtubeScreenState();
}

class _AirtubeScreenState extends State<AirtubeScreen>
    with SingleTickerProviderStateMixin {
  static const double vSound = 343;
  double f = 512, lCm = 20, t = 0, level = 0;
  bool forking = false, scanning = false, view3d = false;
  bool started = false, won = false;
  final List<double> marks = [];

  double get lam => vSound / f;
  double lamCm(int n) => (2 * n - 1) * lam / 4 * 100;
  double loudFn() {
    var s = 0.0;
    for (var n = 1; n <= 4; n++) {
      final d = (lCm - lamCm(n)) / 2.0;
      s += math.exp(-d * d / 0.35);
    }
    return s.clamp(0, 1);
  }

  final OrbitCam cam = OrbitCam(dist: 680, fov: 680);
  final List<Star> stars = makeStars();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _challengeDoneToday = false;
  late TrainingData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['airtube'] == dateKeyOf(DateTime.now());
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
    if (forking && scanning) {
      lCm += dt * 12;
      if (lCm >= 95) lCm = 95;
      if (lCm <= 5) lCm = 5;
    }
    level = level + (loudFn() - level) * math.min(dt * 10, 1);
    if (loudFn() > 0.3 && !started) started = true;
    if (marks.length >= 2 && !won && !_challengeDoneToday) {
      final a = marks[0], b = marks[1];
      if ((b - 3 * a).abs() <= 0.05 * 3 * a) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'airtube': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'airtube'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  // ── واقعي ──
  void _paintReal(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintWalnutTable(c, size, size.height - 60);
    final tubW = 70.0;
    final tubX = size.width * 0.42;
    const top = 55.0, bot = 372.0;
    double yOf(double cm) => bot - (cm / 100) * (bot - top);
    // جدارا الأنبوب
    c.drawRect(Rect.fromLTWH(tubX, top, 5, bot - top),
        Paint()..color = const Color(0xFFB9B9B2));
    c.drawRect(Rect.fromLTWH(tubX + tubW - 5, top, 5, bot - top),
        Paint()..color = const Color(0xFFB9B9B2));
    // الماء
    final wy = yOf(lCm);
    c.drawRect(Rect.fromLTWH(tubX + 5, wy, tubW - 10, bot - wy),
        Paint()..color = const Color.fromRGBO(74, 109, 140, .55));
    c.drawRect(Rect.fromLTWH(tubX + 5, wy, tubW - 10, 4),
        Paint()..color = const Color.fromRGBO(160, 200, 235, .8));
    // مقياس سم
    for (var cm = 0; cm <= 95; cm += 10) {
      c.drawLine(Offset(tubX - 8, yOf(cm.toDouble())),
          Offset(tubX, yOf(cm.toDouble())),
          Paint()
            ..color = const Color.fromRGBO(205, 215, 230, .4)
            ..strokeWidth = 1);
    }
    // الرنانة (شوك)
    final fx = tubX + tubW + 120, fy = top + (forking ? math.sin(t * 40) * 1.5 : 0);
    c.drawLine(Offset(fx, fy + 26), Offset(fx, fy + 52),
        Paint()..color = const Color(0xFF6E6E68)..strokeWidth = 5);
    for (final s in [-16.0, 16.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(fx + s, fy), width: 10, height: 58),
          Paint()..color = const Color(0xFF8F8F8A));
    }
    if (forking && level > 0.05) {
      for (var k = 0; k < 3; k++) {
        c.drawOval(
            Rect.fromCenter(
                center: Offset(fx, fy + 6),
                width: 24 + k * 22 + (t * 26 % 22),
                height: 40 + k * 34),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color.fromRGBO(200, 110, 40, .2 + .5 * level));
      }
    }
    // العلامات
    for (final mk in marks) {
      c.drawLine(Offset(tubX - 16, yOf(mk)), Offset(tubX + tubW + 16, yOf(mk)),
          Paint()
            ..color = const Color(0xFF78DC9A)
            ..strokeWidth = 2.5);
    }
    if (level > 0.55) {
      _arabic(c, 'قرصانة!', Offset(tubX + tubW / 2, top - 16), 16, kGlow);
    }
    _arabic(c, 'L = ${toAr(lCm.toStringAsFixed(1))}cm',
        Offset(tubX + tubW / 2, bot + 22), 12.5, kInkLight);
    _readout(c, size, [
      'f = ${toAr(f.round())}Hz · λ = ${toAr((lam * 100).toStringAsFixed(1))}cm',
      'L = ${toAr(lCm.toStringAsFixed(1))}cm · مستوى الصوت ${toAr((level * 100).round())}٪',
    ]);
  }

  // ── 3D ──
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const r = 52.0, yTop = 60.0, yBot = -140.0;
    double yOf(double cm) => yBot + (cm / 100) * (yTop - yBot);
    ring3(c, cam, size, 0, r, const Color(0x8CCDD7E6), 2);
    final yw = yOf(lCm);
    // قرص الماء
    final wpts = <P3>[];
    for (var i = 0; i <= 40; i++) {
      final a = i / 40 * 2 * math.pi;
      wpts.add(P3(math.cos(a) * r, yw, math.sin(a) * r));
    }
    c.drawPath(
        _pathOf(wpts, size),
        Paint()..color = const Color.fromRGBO(74, 109, 140, 0.55));
    stroke3(c, cam, size, wpts, const Color(0xA6C8EB), 2, close: true);
    // جسيمات الهدير
    if (forking) {
      final seg = 8;
      for (var i = 0; i <= seg; i++) {
        final y = yw - 2 - i * ((yw - yBot - 4) / seg);
        final ph = math.sin(i * 2.1) * 20;
        final p = cam.project(P3(ph, y, math.cos(i * 2.1) * 20), size);
        c.drawCircle(Offset(p.x, p.y), 1.8,
            Paint()..color = const Color.fromRGBO(226, 232, 240, .2 + .5 * level));
      }
      // أقواس الرنانة
      final fp = cam.project(const P3(0, yTop + 34, 0), size);
      for (var k = 0; k < 3; k++) {
        c.drawCircle(Offset(fp.x, fp.y - 6), 12.0 + k * 11 + (t * 26 % 11),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color.fromRGBO(200, 110, 40, .2 + .55 * level));
      }
    }
    // العلامات
    for (final mk in marks) {
      final pts = <P3>[];
      for (var i = 0; i <= 40; i++) {
        final a = i / 40 * 2 * math.pi;
        pts.add(P3(math.cos(a) * (r + 4), yOf(mk), math.sin(a) * (r + 4)));
      }
      stroke3(c, cam, size, pts, const Color(0xCC78DC9A), 3, close: true);
    }
    if (level > 0.55) {
      _arabic(c, 'قرصانة!', Offset(size.width / 2, 48), 16, kGlow);
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 12), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _readout(c, size, [
      'f = ${toAr(f.round())}Hz · λ = ${toAr((lam * 100).toStringAsFixed(1))}cm',
      'L = ${toAr(lCm.toStringAsFixed(1))}cm · مستوى ${toAr((level * 100).round())}٪',
    ]);
  }

  Path _pathOf(List<P3> pts, Size size) {
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final q = cam.project(pts[i], size);
      i == 0 ? p.moveTo(q.x, q.y) : p.lineTo(q.x, q.y);
    }
    p.close();
    return p;
  }

  void _readout(Canvas c, Size size, List<String> lines) {
    final r = Rect.fromLTWH(16, 12, 250, 18 + lines.length * 22);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = const Color(0xD20D1016));
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
      appBar: AppBar(title: const Text('المختبر: قرصانة عمود الهواء')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 440,
            child: GestureDetector(
              onPanUpdate: view3d
                  ? (d) {
                      cam.yaw += d.delta.dx * 0.008;
                      cam.pitch =
                          (cam.pitch + d.delta.dy * 0.008).clamp(-0.05, 1.0);
                    }
                  : null,
              child: CustomPaint(painter: _APainter(this), child: const SizedBox.expand()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              LabSlider(
                  label: 'تواتر الرنانة f',
                  value: f, min: 250, max: 700, divisions: 90,
                  display: '${toAr(f.round())}Hz',
                  onChanged: (x) => setState(() => f = x)),
              LabSlider(
                  label: 'طول عمود الهواء L',
                  value: lCm, min: 5, max: 95, divisions: 90,
                  display: '${toAr(lCm.toStringAsFixed(1))}cm',
                  onChanged: (x) => setState(() {
                        lCm = x;
                        scanning = false;
                      })),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                ViewToggle(view3d: view3d, onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() {
                          forking = true;
                          scanning = true;
                        }),
                    child: const Text('⏬ مسح تلقائي')),
                OutlinedButton(
                    onPressed: () => setState(() {
                          forking = true;
                          scanning = false;
                        }),
                    child: const Text('✋ ثبّت')),
                OutlinedButton(
                    onPressed: () => setState(() {
                          if (loudFn() < 0.3) return;
                          marks.add(lCm);
                        }),
                    child: const Text('📍 ضع علامة')),
                OutlinedButton(
                    onPressed: () => setState(() {
                          marks.clear();
                          t = 0;
                        }),
                    child: const Text('↺ إعادة')),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('العلامات: ${toAr(marks.length)}'
                  '${marks.isNotEmpty ? ' · آخرها ${toAr(marks.last.toStringAsFixed(1))}cm' : ''}'),
              _chip('الصوت: ${toAr((level * 100).round())}٪'),
              if (!_challengeDoneToday)
                _chip('🎯 علامتان بموقعَي L₁ و3L₁ (±٥٪)', ok: won)
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
                  child: Text('λ = v/f = 343/f · Ln = (2n−1)·λ/4',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16))),
              const SizedBox(height: 6),
              _line('القرصانة تتشكل عندما يكون عمود الهواء (2n−1)·λ/4 — عقدة بالماء وبطن بالفوهة.'),
              _line('المسح الآلي يهبط بماء الأنبوب؛ اصغِ للهدير وضع علامة عند أعلى صوت.'),
              _line('أول قرصانة L₁، والثانية 3L₁ — الفرق يقيس λ/2 ويستنتج v بمعرفة f.'),
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

class _APainter extends CustomPainter {
  _APainter(this.st);
  final _AirtubeScreenState st;

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
          color: Theme.of(context).colorScheme.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(8)),
      child: const Text('🔒 يُفتح الشرح بعد أول قرصانة تسمعها/تراها.',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
