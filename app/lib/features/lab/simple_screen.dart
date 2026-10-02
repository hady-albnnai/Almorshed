import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U1-5 النواس البسيط: T ~ √l نقطة-نقطة (نمط موحّد معتمد).
/// g = 9.81 · T₀ = 2π√(l/g) · مؤقت ١٠ نوسات · إطلاق/إمساك.
/// تحدّي: قياسان نسقةما ٢٫٠ ±٠٫١ ⇒ T ∝ √l مثبتة (+١٠) بمفتاح 'simple'.
class SimpleScreen extends StatefulWidget {
  const SimpleScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<SimpleScreen> createState() => _SimpleScreenState();
}

class _SimpleScreenState extends State<SimpleScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-simple.html المعتمد) ──
  static const double g = 9.81;
  double l = 1.0;
  double amp = 12 * math.pi / 180;
  double th = 0, thV = 0;
  bool swinging = false, holding = false;
  double t = 0;
  bool timingOn = false;
  double timingT0 = 0;
  int timingN = 0;
  double timingT10 = 0;
  final List<double> meas = <double>[];
  String measText = 'المؤقت: —';
  bool won = false;

  double get tOf => 2 * math.pi * math.sqrt(l / g);

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
        _data.labChallengeDays['simple'] == dateKeyOf(DateTime.now());
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
      if (swinging && !holding) {
        thV += -(g / l) * math.sin(th) * st;
        final prev = th;
        th += thV * st;
        if (timingOn && timingN < 10 && prev <= 0 && th > 0) {
          timingN++;
          if (timingN >= 10) {
            timingT10 = t;
            _endTiming();
          }
        }
      }
    }
  }

  void _endTiming() {
    final t10 = timingT10 - timingT0;
    final tOne = t10 / 10;
    meas.add(tOne);
    measText = '10T = ${toAr(t10.toStringAsFixed(2))}s ⇒ T = ${toAr(tOne.toStringAsFixed(3))}s';
    if (meas.length >= 2 && !_challengeDoneToday && !won) {
      final a = meas[meas.length - 2], b = meas[meas.length - 1];
      if ((a / b - 2).abs() < 0.1) {
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
        'simple': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'simple'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _release() {
    setState(() {
      swinging = true;
      holding = false;
      th = amp;
      thV = 0;
      timingOn = true;
      timingT0 = t;
      timingN = 0;
    });
  }

  void _reset() {
    setState(() {
      swinging = false;
      holding = false;
      th = 0;
      thV = 0;
      meas.clear();
      measText = 'المؤقت: —';
      won = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 356.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final pivot = Offset(w * 0.5, 64.0);
    final pxl = l * 230.0;
    // حامل الحائط
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(pivot.dx - 90, pivot.dy - 26, 180, 16),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF232320));
    c.drawLine(Offset(pivot.dx, pivot.dy - 10), Offset(pivot.dx, pivot.dy),
        Paint()
          ..color = const Color(0xFF8F8F8A)
          ..strokeWidth = 4);
    // الخيط + الكرة
    final ang = holding || !swinging ? amp : th;
    final bob = Offset(
        pivot.dx + math.sin(ang) * pxl, pivot.dy + math.cos(ang) * pxl);
    c.drawLine(pivot, bob,
        Paint()
          ..color = const Color(0xFFC9C2A8)
          ..strokeWidth = 1.8);
    c.drawCircle(bob, 17,
        Paint()..color = const Color(0xFF8A8578)..maskFilter = null);
    c.drawCircle(
        bob.translate(-5, -6), 5, Paint()..color = const Color(0xFFB9B3A4));
    // قوس السعة + عمودي مرجعي
    c.drawArc(
        Rect.fromCircle(center: pivot, radius: pxl + 24),
        -math.pi / 2 - amp,
        2 * amp,
        false,
        Paint()
          ..color = const Color.fromRGBO(240, 150, 74, 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    c.drawLine(
        pivot,
        Offset(pivot.dx, pivot.dy + pxl + 40),
        Paint()
          ..color = const Color.fromRGBO(156, 195, 223, 0.25)
          ..strokeWidth = 1);
    // مسطرة الطول على الجدار
    for (var lm = 0.0; lm <= 1.6; lm += 0.2) {
      final yy = pivot.dy + lm * 230.0;
      c.drawLine(
          Offset(pivot.dx + 130, yy),
          Offset(pivot.dx + (lm * 10 % 2 == 0 ? 150 : 142), yy),
          Paint()
            ..color = const Color.fromRGBO(156, 195, 223, 0.35)
            ..strokeWidth = 1);
    }
    _arabic(c, 'l = ${toAr(l.toStringAsFixed(2))}m · T₀ نظري = ${toAr(tOf.toStringAsFixed(3))}s',
        Offset(w / 2, 26), 13, const Color(0xFFE8E2D0));
    _arabic(c, holding ? '✋ ممسوك — حرّك l ثم أطلق' : (swinging ? 'يتأرجح…' : 'اضغط «إطلاق»'),
        Offset(w / 2, 48), 12, const Color.fromRGBO(232, 226, 208, 0.75));
    _arabic(c, measText, Offset(w / 2, size.height - 16), 13.5,
        meas.isNotEmpty ? const Color(0xFF8CFFAA) : const Color.fromRGBO(156, 195, 223, 0.8));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const pivotY = 150.0;
    final pxl = l * 190.0;
    final ang = holding || !swinging ? amp : th;
    // حامل علوي
    line3(c, cam, size, const P3(-60, pivotY, 0), const P3(60, pivotY, 0),
        const Color(0xFF232320), 6);
    final bob = P3(math.sin(ang) * pxl, pivotY - math.cos(ang) * pxl, 0);
    line3(c, cam, size, const P3(0, pivotY, 0), bob, const Color(0xFFC9C2A8), 2);
    final bp = cam.project(bob, size);
    c.drawCircle(Offset(bp.x, bp.y), 11 * bp.s / cam.fov * 640,
        Paint()..color = const Color(0xFF8A8578));
    // قوس السعة
    final arc = <P3>[];
    for (var k = 0; k <= 20; k++) {
      final a = -amp + 2 * amp * k / 20;
      arc.add(P3(math.sin(a) * (pxl + 26), pivotY - math.cos(a) * (pxl + 26), 0));
    }
    stroke3(c, cam, size, arc, const Color.fromRGBO(240, 150, 74, 0.55), 1.6);
    _arabic(c, 'l = ${toAr(l.toStringAsFixed(2))}m · T₀ = ${toAr(tOf.toStringAsFixed(3))}s',
        Offset(size.width / 2, 26), 12, const Color(0xFFE8E2D0));
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(c, measText, Offset(size.width / 2, 46), 12,
        meas.isNotEmpty ? const Color(0xFF8CFFAA) : const Color.fromRGBO(232, 226, 208, 0.8));
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
      appBar: AppBar(title: const Text('المختبر: النواس البسيط — T ~ √l')),
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
                painter: _SimplePainter(this),
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
                  label: 'الطول l',
                  value: l,
                  min: 0.4, max: 1.6, divisions: 24,
                  display: '${toAr(l.toStringAsFixed(2))}m',
                  onChanged: (x) => setState(() {
                        l = x;
                        swinging = false;
                        th = 0;
                      })),
              LabSlider(
                  label: 'السعة',
                  value: amp * 180 / math.pi,
                  min: 5, max: 20, divisions: 15,
                  display: '${toAr((amp * 180 / math.pi).round())}°',
                  onChanged: (x) =>
                      setState(() => amp = x * math.pi / 180)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(onPressed: _release, child: const Text('↻ إطلاق')),
                OutlinedButton(
                    onPressed: () => setState(() => holding = !holding),
                    child: Text(holding ? '✋ إمساك: نعم' : '✋ إمساك')),
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
                    'جعلنا الطول أربعة أمثال (l ← 4l) — ماذا يحدث للدور T؟',
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
                          'أربعة أمثال',
                          'الضعف — لأن T ∝ √l',
                          'ثمانية أمثال',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — T = 2π√(l/g): الجذر يخفف التضاعف إلى ×٢'
                        : '✘ T ∝ √l: أربعة أمثال في الطول ⇒ ضعفان في الدور',
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
              _chip('T₀ نظري = ${toAr(tOf.toStringAsFixed(3))}s'),
              _chip(measText),
              if (meas.length == 1)
                _chip('القياس الأول: ${toAr(meas.first.toStringAsFixed(3))}s — قسّم ٤l وقِس ثانية'),
              if (!_challengeDoneToday)
                _chip(won ? '🎯 منجز! النسبة ٢٫٠' : '🎯 قِس عند l ثم ٤l — نسبة الدورين ٢٫٠ ±٠٫١',
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
                child: Text('T₀ = 2π√(l/g) — لا يعتمد على الكتلة ولا على السعة الصغيرة',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('الميل يتناسب مع g/l: طول أكبر ⇒ ميل أصغر ⇒ دور أبطأ — وهذا كل سرّ √l.'),
              _explainLine('الكرة الأثقل لا تغيّر شيئاً: القوة والعطالة يتضاعفان معاً فيلغياني.'),
              _explainLine('زوايا صغيرة فقط: عند ١٥° يبدأ الانحراف عن √l بالأنحاء الكبيرة.'),
              _explainLine('قياس ١٠ نوسات وقسمتها يقلل خطأ ردّ الفعل الزمني عشرة أمثال.'),
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

class _SimplePainter extends CustomPainter {
  _SimplePainter(this.st);
  final _SimpleScreenState st;

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
          '🔒 يُفتح الشرح بعد أول قياس — «إطلاق» وانتظر العدّ!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
