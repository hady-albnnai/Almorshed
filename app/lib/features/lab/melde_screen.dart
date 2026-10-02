import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U3-1 ملد: وتر + رنانة + كفة أثقال (نمط موحّد معتمد).
/// v=√(FT/μ) · f₁=v/2L · رنين |r−n|≤4% · تحدّي n=٣ بالضبط (+١٠).
/// منظور واقعي (هزّاز/بكرة/أثقال مشقوقة/وتر متوهج) + منظور 3D مداري
/// بنفس الحالة — التبديل لا يوقف القراءة.
class MeldeScreen extends StatefulWidget {
  const MeldeScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<MeldeScreen> createState() => _MeldeScreenState();
}

class _MeldeScreenState extends State<MeldeScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-melde.html المعتمد) ──
  double f = 60, m = 0.2, L = 1.2, mu = 2.0, t = 0;
  bool showEnv = true, view3d = false, started = false, won = false;

  double get ft => m * 10;
  double get v => math.sqrt(ft / (mu * 1e-3));
  double get f1 => v / (2 * L);
  double get ratio => f / f1;
  int get nModes => math.max(1, ratio.round());
  bool get resonant {
    final rr = ratio, nn = nModes;
    return (rr - nn).abs() <= 0.04 * nn;
  }

  double get amp {
    final rr = ratio, nn = nModes, d = rr - nn;
    return 1 / math.sqrt(1 + (d * 22) * (d * 22));
  }

  double disp(double xi) =>
      amp * 60 * 0.5 *
      math.sin(nModes * math.pi * xi) *
      math.cos(2 * math.pi * f * 0.25 * t);

  // ── الكاميرا والنجوم ──
  final OrbitCam cam = OrbitCam(dist: 640, fov: 640);
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
        _data.labChallengeDays['melde'] == dateKeyOf(DateTime.now());
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
    if (resonant && !started) started = true;
    if (resonant && nModes == 3 && !won && !_challengeDoneToday) {
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
        'melde': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'melde'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 320.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    const yStr = 205.0;
    final x0 = size.width * 0.22, x1 = size.width * 0.80;
    // البكرة
    c.drawLine(Offset(x0, yStr + 8), Offset(x0, benchTop),
        Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 8);
    c.drawCircle(Offset(x0, yStr), 18,
        Paint()..color = const Color(0xFF9A9A94));
    c.drawCircle(Offset(x0, yStr), 5, Paint()..color = const Color(0xFF55554F));
    // الأثقال المشقوقة على حامل
    final hx = x0 + 26.0;
    c.drawLine(Offset(hx, yStr + 10), Offset(hx, benchTop + 34),
        Paint()..color = const Color.fromRGBO(150, 135, 105, .9)..strokeWidth = 2.2);
    final masses = (m / 0.05).round().clamp(0, 10);
    for (var i = 0; i < masses; i++) {
      final my = benchTop + 34 - i * 8.2;
      c.drawOval(
          Rect.fromCenter(center: Offset(hx, my), width: 52, height: 11),
          Paint()..color = const Color(0xFFC6C0AE));
      c.drawOval(
          Rect.fromCenter(
              center: Offset(hx, my + 2), width: 52, height: 4.4),
          Paint()..color = const Color(0x591E190F));
    }
    // الهزّاز
    final vx = x1 + 46;
    c.drawRect(Rect.fromCenter(center: Offset(vx, benchTop - 50), width: 84, height: 96),
        Paint()..color = const Color(0xFF232320));
    c.drawCircle(Offset(vx - 14, benchTop - 88), 5.5,
        Paint()..color = const Color(0xFFB3372B));
    c.drawCircle(Offset(vx + 12, benchTop - 88), 5.5,
        Paint()..color = const Color(0xFF1E1E1C));
    _arabic(c, 'هزّاز', Offset(vx, benchTop + 20), 12, const Color(0xFFC9BFA8));
    // الوتر
    final res = resonant;
    final base = Paint()
      ..color = res ? const Color(0xFFC87A28) : const Color(0xFFB0956A)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    if (res) {
      c.drawCircle(Offset((x0 + x1) / 2, yStr), 120,
          Paint()..color = const Color.fromRGBO(200, 110, 40, 0.06));
    }
    final path = Path();
    for (var i = 0; i <= 200; i++) {
      final xi = i / 200;
      final p = Offset(x0 + xi * (x1 - x0), yStr - disp(xi * L));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, base);
    // العقد
    for (var k = 0; k <= nModes; k++) {
      final xi = k / nModes;
      c.drawCircle(Offset(x0 + xi * (x1 - x0), yStr), 3.6,
          Paint()..color = const Color(0xFF4A4038));
    }
    // ظرف المطال
    if (showEnv) {
      final env = Paint()
        ..color = const Color.fromRGBO(210, 190, 150, 0.4)
        ..strokeWidth = 1.2;
      for (final sgn in [1.0, -1.0]) {
        final p2 = Path();
        for (var i = 0; i <= 160; i++) {
          final xi = i / 160;
          final y = yStr -
              sgn * amp * 30 *
                  math.sin(nModes * math.pi * xi).abs();
          final pt = Offset(x0 + xi * (x1 - x0), y);
          i == 0 ? p2.moveTo(pt.dx, pt.dy) : p2.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(p2, env);
      }
    }
    if (res) {
      _arabic(c, 'رنين! n = ${toAr(nModes)}',
          Offset(size.width / 2, 60), 15, const Color(0xFFF0964A));
    }
    // لوحة قراءات
    _readout(c, size, [
      'v = ${toAr(v.toStringAsFixed(1))} m/s',
      'λ = ${toAr((L / nModes).toStringAsFixed(2))}m · f₁ = ${toAr(f1.toStringAsFixed(1))}Hz',
    ]);
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    final res = resonant;
    const wireLen = 340.0;
    for (var i = 0; i <= 200; i++) {
      final xi = i / 200;
      final p = cam.project(P3(xi * wireLen - 170, 40, disp(xi * L) * 0.9), size);
      if (res) {
        c.drawCircle(Offset(p.x, p.y), 2.8,
            Paint()..color = const Color(0xFFC87A28));
      } else {
        c.drawCircle(Offset(p.x, p.y), 2.2,
            Paint()..color = const Color(0xFF8A7350));
      }
    }
    for (var k = 0; k <= nModes; k++) {
      final xi = k / nModes;
      final p = cam.project(P3(xi * wireLen - 170, 40, 0), size);
      c.drawCircle(Offset(p.x, p.y), 3.6,
          Paint()..color = const Color(0xFF4A4038));
    }
    // كفة معلقة
    final pw = cam.project(const P3(-170, 0, 0), size);
    c.drawLine(Offset(pw.x, pw.y), Offset(pw.x, pw.y + 40),
        Paint()..color = const Color.fromRGBO(90, 80, 60, .6)..strokeWidth = 2);
    c.drawOval(Rect.fromCenter(center: Offset(pw.x, pw.y + 48), width: 40, height: 12),
        Paint()..color = const Color(0xFFC6C0AE));
    if (res) {
      _arabic(c, 'رنين! n = ${toAr(nModes)}',
          Offset(size.width / 2, 52), 15, const Color(0xFFF0964A));
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _readout(c, size, [
      'v = ${toAr(v.toStringAsFixed(1))} m/s · n = ${toAr(nModes)}',
      'f₁ = ${toAr(f1.toStringAsFixed(1))}Hz',
    ]);
  }

  void _readout(Canvas c, Size size, List<String> lines) {
    final r = Rect.fromLTWH(16, 12, 230, 18 + lines.length * 22);
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = const Color(0xD20D1016));
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
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
      appBar: AppBar(title: const Text('المختبر: ملد — الوتر والرنانة')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 440,
            child: GestureDetector(
              onPanStart: view3d ? (_) => _orbiting = true : null,
              onPanUpdate: view3d ? (d) {
                if (!_orbiting) return;
                cam.yaw += d.delta.dx * 0.008;
                cam.pitch =
                    (cam.pitch + d.delta.dy * 0.008).clamp(-0.05, 1.0);
              } : null,
              onPanEnd: (_) => _orbiting = false,
              child: CustomPaint(
                painter: _MeldePainter(this),
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
                  label: 'التواتر f',
                  value: f,
                  min: 10, max: 120, divisions: 110,
                  display: '${toAr(f.round())}Hz',
                  onChanged: (x) => setState(() => f = x)),
              LabSlider(
                  label: 'الأثقال m',
                  value: m,
                  min: 0.05, max: 1, divisions: 19,
                  display: '${toAr(m.toStringAsFixed(2))}kg',
                  onChanged: (x) => setState(() => m = x)),
              LabSlider(
                  label: 'الطول L',
                  value: L,
                  min: 0.5, max: 2, divisions: 15,
                  display: '${toAr(L.toStringAsFixed(1))}m',
                  onChanged: (x) => setState(() => L = x)),
              LabSlider(
                  label: 'μ',
                  value: mu,
                  min: 0.5, max: 5, divisions: 9,
                  display: '${toAr(mu.toStringAsFixed(1))}g/m',
                  onChanged: (x) => setState(() => mu = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                ViewToggle(view3d: view3d, onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => showEnv = !showEnv),
                    child: const Text('ظرف المطال')),
                OutlinedButton(
                    onPressed: () => setState(() => t = 0),
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
              _chip('المغازل: ${resonant ? toAr(nModes) : '— (غير رنين)'}'),
              _chip('v = ${toAr(v.toStringAsFixed(1))} m/s'),
              if (!_challengeDoneToday)
                _chip(resonant && nModes == 3 ? '🎯 منجز!' : '🎯 اجعل n = ٣ بالضبط',
                    ok: resonant && nModes == 3)
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
                child: Text('v = √(FT/μ) · fn = (n/2L)·√(FT/μ) · L = n·λ/2',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 16)),
              ),
              const SizedBox(height: 6),
              _explainLine('الرنين عندما يكون طول الوتر عدداً صحيحاً من أنصاف الأطوال الموجية: L = n·λ/2.'),
              _explainLine('مضاعفة FT أربعة أمثال ⇒ v تتضاعف ⇒ λ تتضاعف ⇒ عدد المغازل ينصف عند f ثابت.'),
              _explainLine('على المغازل سكون تام، وبينها بطون بسعة أعظمية — الطاقة لا تنتقل على طول الوتر.'),
              _explainLine('بالمنظور 3D: دوّر الكاميرا لترى اتساع البطن في عمق الصورة.'),
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

class _MeldePainter extends CustomPainter {
  _MeldePainter(this.st);
  final _MeldeScreenState st;

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
          '🔒 يُفتح الشرح بعد أول رنين تلاحظه — حرّك f أو الأثقال!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
