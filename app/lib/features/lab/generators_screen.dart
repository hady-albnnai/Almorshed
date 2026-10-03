import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-14/15/16 المولد والمحرك والتحريض الذاتي (نمط موحّد معتمد).
/// دينامو: τ=pwr·1.5−(إمساك?12:0.35ω)−0.25ω · ε=ω·kE·14 (kE=0.09) · ميزان طاقة
/// W_يد=pwr·0.09 = E=ε·0.02 · محرك: I=(Vb·pwr/10−ε)/Rm واندفاع عند الإمساك
/// · ذاتي: di=(V−i·1.1)/0.5 وشرارة الفتح · تحدّي ميزان ثم اندفاع (+١٠) 'generators'.
class GeneratorsScreen extends StatefulWidget {
  const GeneratorsScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<GeneratorsScreen> createState() => _GeneratorsScreenState();
}

class _GeneratorsScreenState extends State<GeneratorsScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-generators.html المعتمد) ──
  static const double kE = 0.09, rm = 1.6, vb = 6;
  int mode = 1; // 1 مولد · 2 محرك · 3 ذاتي
  double pwr = 5;
  double t = 0;
  double om = 0, phi = 0, ii = 0;
  bool holding = false, swOpen = false;
  bool won = false, started = false;
  bool sawGen = false, sawSurge = false;

  double get emf => om * kE * 14;
  double get iArm => (vb * pwr / 10 - emf) / rm;

  // ── الكاميرا والنجوم ──
  final OrbitCam cam = OrbitCam(dist: 660, fov: 660);
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
        _data.labChallengeDays['generators'] == dateKeyOf(DateTime.now());
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
      if (mode == 1) {
        final tau = pwr * 1.5 -
            (holding ? 12.0 : 0.35 * om) -
            om * 0.25;
        om += tau * st;
        om = om.clamp(0.0, 30.0);
        if (emf > 1 && !started) started = true;
      } else if (mode == 2) {
        final tau2 = holding
            ? -9.0
            : ((pwr / 10 * vb - emf) * 0.9).clamp(-8.0, 9.0);
        om += tau2 * st;
        om = om.clamp(0.0, 30.0);
        if (holding && iArm.abs() > 2.5) sawSurge = true;
        if (!holding && om > 6) sawGen = true;
        if (sawGen && sawSurge && !won && !_challengeDoneToday) {
          won = true;
          HapticFeedback.mediumImpact();
          _recordChallenge();
        }
        if (emf > 1 && !started) started = true;
      } else {
        final v = swOpen ? 0.0 : pwr / 10 * vb;
        final di = (v - ii * 1.1) / 0.5;
        ii += di * st * 1.4;
        if (ii > 0.1 && !started) started = true;
      }
      phi += om * st * 0.6;
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
        'generators': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'generators'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      om = 0;
      phi = 0;
      ii = 0;
      holding = false;
      swOpen = false;
      sawGen = false;
      sawSurge = false;
      won = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 348.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final cx0 = w * 0.5, cy = 225.0;
    // دينامو دوّار مشترك
    c.drawCircle(Offset(cx0, cy), 6, Paint()..color = const Color(0xFF3A3A38));
    final rot = phi % (2 * math.pi);
    for (var k = 0; k < 4; k++) {
      final a = rot + k * math.pi / 2;
      c.drawLine(
          Offset(cx0 + math.cos(a) * 10, cy + math.sin(a) * 10),
          Offset(cx0 + math.cos(a) * 74, cy + math.sin(a) * 74),
          Paint()
            ..color = const Color(0xFFC89A5A)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
    }
    c.drawCircle(Offset(cx0, cy), 84,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(205, 160, 90, 0.35)
          ..strokeWidth = 3);
    if (mode == 1) {
      // مقود/دوّاسات + عدّاد جهد
      _arabic(c, '⚙️ دوّر (قدرة يدك)', Offset(cx0, cy - 120), 13,
          const Color(0xFFE8E2D0));
      final mx = w * 0.78, my = 120.0;
      c.drawArc(Rect.fromCircle(center: Offset(mx, my), radius: 52),
          math.pi / 6, 2 * math.pi / 3, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color.fromRGBO(230, 228, 220, 0.4)
            ..strokeWidth = 2);
      final na = (emf / 20).clamp(0.0, 1.0) * (2 * math.pi / 3) - math.pi / 3;
      c.drawLine(
          Offset(mx, my),
          Offset(mx + math.sin(na) * 46, my - math.cos(na) * 46),
          Paint()
            ..color = const Color(0xFFE86A4A)
            ..strokeWidth = 2.8);
      _arabic(c, 'ε = ${toAr(emf.toStringAsFixed(1))}V', Offset(mx, my + 74),
          12.5, const Color(0xFF9CD9BC));
      _arabic(c, 'ω = ${toAr(om.toStringAsFixed(1))}rad/s', Offset(cx0, cy + 110),
          12.5, const Color(0xFF9CC3DF));
      _arabic(
          c,
          'W_يد = ${toAr((pwr * 0.09).toStringAsFixed(2))}J/s · E_كهربائية = ${toAr((emf * 0.02).toStringAsFixed(2))}J/s ⇒ متساويان!',
          Offset(w / 2, 26),
          13,
          const Color(0xFF8CFFAA));
      _arabic(c, holding ? '✋ ممسك بالمحور — عزم مقاوم' : 'يدور بحرية',
          Offset(w / 2, 48), 12,
          holding ? const Color(0xFFF0964A) : const Color.fromRGBO(232, 226, 208, 0.75));
    } else if (mode == 2) {
      // محرك: بطارية + عداد تيار
      _arabic(c, '🔋 محرك — تيار يقود الدوران', Offset(cx0, cy - 120), 13,
          const Color(0xFFE8E2D0));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx0 + 100, cy - 20, 70, 40),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFF232320));
      _arabic(c, 'ε₋=${toAr(emf.toStringAsFixed(1))}V', Offset(cx0 + 135, cy),
          10.5, const Color(0xFF9CC3DF));
      final surge = holding && iArm.abs() > 2.5;
      _arabic(
          c,
          'I المحرك = ${toAr(iArm.toStringAsFixed(2))}A${surge ? ' ⚠ اندفاع!' : ''}',
          Offset(w / 2, 26),
          13.5,
          surge ? const Color(0xFFF0964A) : const Color(0xFFE8E2D0));
      _arabic(c, 'ε المعاكسة تمنع اندفاع التيار — إلا إذا أوقفته (إمساك)!',
          Offset(w / 2, 48), 12, const Color(0xFF9CD9BC));
      _arabic(c, holding ? '✋ المحور ممسوك — الدوران يهبط' : 'يدور',
          Offset(w / 2, size.height - 16), 13,
          holding ? const Color(0xFFF0964A) : const Color(0xFF8CFFAA));
    } else {
      // وشيعة ذاتية + مفتاح + شرارة
      final sx = cx0 + 150;
      c.drawLine(Offset(sx - 26, cy - 60), Offset(sx - 8, cy - 52),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.6);
      c.drawLine(Offset(sx + 8, cy - 48), Offset(sx + 26, cy - 40),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.6);
      if (swOpen && ii > 0.2) {
        final fl = math.sin(t * 30) > 0 ? 1.0 : 0.4;
        c.drawCircle(
            Offset(sx, cy - 52),
            10,
            Paint()
              ..color = Color.fromRGBO(255, 220, 140, (0.6 * fl).toDouble())
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6));
        _arabic(c, '⚡ شرارة!', Offset(sx + 40, cy - 70), 13,
            const Color(0xFFF0964A));
      }
      _arabic(
          c,
          'i = ${toAr(ii.toStringAsFixed(2))}A${swOpen ? ' · ε ذاتية = ${toAr((ii * 8).toStringAsFixed(0))}V' : ''}',
          Offset(w / 2, 26),
          13.5,
          const Color(0xFFE8E2D0));
      _arabic(c, swOpen ? 'المفتاح مفتوح — L تدفع بجهد كبير' : 'يمرّ تيار مستقر',
          Offset(w / 2, 48), 12, const Color(0xFF9CD9BC));
      _arabic(c, 'L تعارض التغيّر — لذلك الشرارة عند القطع لا عند الوصل',
          Offset(w / 2, size.height - 16), 13,
          const Color.fromRGBO(156, 195, 223, 0.85));
    }
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    // دوّار: محور + حلقة دوارة
    line3(c, cam, size, const P3(0, -120, 0), const P3(0, 120, 0),
        const Color(0xFF8F8F8A), 5);
    for (var k = 0; k < 4; k++) {
      final a = phi + k * math.pi / 2;
      line3(c, cam, size, const P3(0, 0, 0),
          P3(math.cos(a) * 90, 0, math.sin(a) * 90),
          const Color(0xFFC89A5A), 4);
    }
    ring3(c, cam, size, 0, 90, const Color.fromRGBO(205, 160, 90, 0.4), 2);
    if (mode == 3) {
      // وشيعة ذاتية بجانب المحور
      for (var k = 0; k < 6; k++) {
        final zz = -50.0 + k * 20;
        line3(c, cam, size, P3(160, -40, zz), P3(160, 40, zz),
            const Color(0xB3C89A5A), 2.6);
      }
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        mode == 1
            ? 'ε = ${toAr(emf.toStringAsFixed(1))}V · ω = ${toAr(om.toStringAsFixed(1))}'
            : mode == 2
                ? 'I = ${toAr(iArm.toStringAsFixed(2))}A · ε₋ = ${toAr(emf.toStringAsFixed(1))}V'
                : 'i = ${toAr(ii.toStringAsFixed(2))}A',
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
      appBar: AppBar(title: const Text('المختبر: المولد والمحرك والذاتي')),
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
                painter: _GeneratorsPainter(this),
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
                ChoiceChip(
                    label: const Text('U2-14 · مبدأ المولد'),
                    selected: mode == 1,
                    onSelected: (_) => setState(() => mode = 1)),
                ChoiceChip(
                    label: const Text('U2-15 · مبدأ المحرك'),
                    selected: mode == 2,
                    onSelected: (_) => setState(() => mode = 2)),
                ChoiceChip(
                    label: const Text('U2-16 · التحريض الذاتي'),
                    selected: mode == 3,
                    onSelected: (_) => setState(() => mode = 3)),
              ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'القدرة pwr',
                  value: pwr,
                  min: 0, max: 10, divisions: 20,
                  display: '${toAr(pwr.toStringAsFixed(1))}',
                  onChanged: (x) => setState(() => pwr = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                    ViewToggle(
                        view3d: view3d,
                        onChanged: (x) => setState(() => view3d = x)),
                    if (mode == 2)
                      OutlinedButton(
                          onPressed: () => setState(() => holding = !holding),
                          child: Text(holding ? '✋ أفلتب المحور' : '✋ أمسك المحور')),
                    if (mode == 3)
                      OutlinedButton(
                          onPressed: () => setState(() => swOpen = !swOpen),
                          child: Text(swOpen ? '🔑 أغلق المفتاح' : '🔑 افتح المفتاح')),
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
                    'لماذا تقفز شرارة عند فتح مفتاح وشيعة تحمل تياراً؟',
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
                          'لأن البطارية تفريغها أخيراً',
                          'لأن L تعارض الانقطاع المفاجئ بجهد كبير',
                          'لأن المفتاح يصنع احتكاكاً',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — ε = −L·di/dt: القطع السريع يولّد جهداً هائلاً'
                        : '✘ ε = −L·di/dt: di/dt ضخم لحظة القطع ⇒ جهد شرارة',
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
              if (mode == 1) ...[
                _chip('W_يد = ${toAr((pwr * 0.09).toStringAsFixed(2))}J/s'),
                _chip('E = ${toAr((emf * 0.02).toStringAsFixed(2))}J/s'),
                _chip('ε = ${toAr(emf.toStringAsFixed(1))}V'),
              ] else if (mode == 2) ...[
                _chip('I = ${toAr(iArm.toStringAsFixed(2))}A'),
                _chip('ε معاكسة = ${toAr(emf.toStringAsFixed(1))}V'),
              ] else ...[
                _chip('i = ${toAr(ii.toStringAsFixed(2))}A'),
                if (swOpen && ii > 0.2) _chip('⚡ شرارة', ok: true),
              ],
              if (!_challengeDoneToday)
                _chip(
                    won ? '🎯 منجز!' : '🎯 دوّر بمقودك (ω>٦) ثم أمسك المحور — قارن التيارين',
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
                child: Text('ε = N·A·B·ω · ε₋ = kE·ω · ε_ذاتية = −L·di/dt',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('المولد: شغلك الميكانيكي يتحول كهرباء — الميزان W_يد = E_كهربائية يثبت حفظ الطاقة.'),
              _explainLine('المحرك: ε المعاكسة تحدّ من التيار؛ إيقاف الدوران (إمساك) يهشمها ⇒ اندفاع تيار خطِر.'),
              _explainLine('الذاتي: الوشيعة تعارض الصعود والهبوط — عند القطع تدفع بجهد الشرارة.'),
              _explainLine('نفس الأسلاك تصلح مولداً ومحركاً — الفرق من حيث تسوق الطاقة فقط.'),
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

class _GeneratorsPainter extends CustomPainter {
  _GeneratorsPainter(this.st);
  final _GeneratorsScreenState st;

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
          '🔒 يُفتح الشرح بعد أول دوران أو تيار — ارفع القدرة!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
