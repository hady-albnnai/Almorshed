import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U4-2 أنبوب كروكس: من الشرارة إلى الحزمة المهبطية (نمط موحّد معتمد).
/// ضغط لوغاريتمي 760→0.01 torr · مراحل: شرارة → توهج وردي → ظلام + حزمة
/// + تألق أخضر وظل الصليب · تحدّي: وصل للتألق ثم انحرف الحزمة بمغناطيس (+١٠).
/// منظور واقعي (أنبوب تفريغ أفقي) + منظور 3D بنفس الحالة.
class CrookesScreen extends StatefulWidget {
  const CrookesScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<CrookesScreen> createState() => _CrookesScreenState();
}

class _CrookesScreenState extends State<CrookesScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-crookes.html المعتمد) ──
  double pSlider = 100; // 0..100 → 760..0.01 torr لوغاريتمياً
  bool hv = true, mag = false;
  double t = 0;
  bool won = false, started = false;

  double get torr => math.max(0.01, 760 * math.pow(10, -(pSlider / 100) * 4.88));

  int get stage {
    final p = torr;
    if (!hv) return 0;
    if (p > 200) return 1;
    if (p > 2) return 2;
    if (p > 0.05) return 3;
    return 4;
  }

  String get stageLabel => const [
        'التوتر: OFF — شغّله لبدء التفريغ',
        'المرحلة ١: شرارة فقط (الضغط الجوي)',
        'المرحلة ٢: توهج وردي يمتد بإنقاص الضغط',
        'المرحلة ٣: توهج يملأ الأنبوب',
        'المرحلة ٤: ظلام + حزمة مهبطية + تألق أخضر',
      ][stage];

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

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['crookes'] == dateKeyOf(DateTime.now());
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
    if (stage == 4 && !started) started = true;
    if (stage == 4 && mag && !won && !_challengeDoneToday) {
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
        'crookes': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'crookes'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  // ══ الرسّام الواقعي — أنبوب تفريغ أفقي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 360.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    final w = size.width, h = size.height;
    final st = stage, p = torr;
    // جسم الأنبوب الزجاجي
    final tube = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 0.69,
        height: h * 0.44);
    c.drawOval(
        tube.inflate(20),
        Paint()..color = const Color.fromRGBO(120, 160, 190, 0.06));
    c.drawOval(
        tube.inflate(20),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(150, 190, 215, 0.4)
          ..strokeWidth = 3);
    // توهج الغاز الوردي — طوله يزداد بإنقاص الضغط حتى المرحلة ٣
    if (st == 2 || st == 3) {
      final frac =
          st == 3 ? 1.0 : (200 - p).clamp(8.0, 170.0) / 198;
      final gl = tube.width * frac;
      final g = Paint()
        ..shader = ui.Gradient.linear(
            Offset(tube.left, 0),
            Offset(tube.left + gl, 0),
            const [
              Color(0x8CFF6EAA),
              Color(0x0DFF6EAA),
            ]);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(tube.left + gl * 0.5, tube.center.dy),
              width: gl,
              height: tube.height - 16),
          g);
    }
    // شرارة عند الضغط الجوي
    if (st == 1 && hv) {
      final fl = math.sin(t * 40) > 0.4 ? 1.0 : 0.2;
      final spark = Path()..moveTo(tube.left + 6, tube.center.dy);
      for (var k = 1; k < 6; k++) {
        spark.lineTo(tube.left + 6 + k * 8,
            tube.center.dy + (math.Random(t.round() + k).nextDouble() - 0.5) * 22);
      }
      c.drawPath(
          spark,
          Paint()
            ..color = Color.fromRGBO(200, 225, 255, fl)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..maskFilter =
                const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
    }
    // المهبط
    c.drawRect(
        Rect.fromLTWH(tube.left - 2, tube.center.dy - 26, 10, 52),
        Paint()..color = const Color.fromRGBO(220, 230, 240, 0.85));
    if (st == 4) {
      // تألق أخضر على قاعدة الزجاج اليمنى
      final glowC = Offset(tube.right + 8, tube.center.dy);
      c.drawOval(
          Rect.fromCenter(
              center: glowC, width: 68, height: tube.height - 12),
          Paint()
            ..shader = ui.Gradient.radial(glowC, 90, const [
              Color(0xCC8CFFAA),
              Color(0x008CFFAA),
            ]));
      // انحراف بالمغناطيس
      final shift = mag ? 34 * math.sin(t * 1.4) : 0.0;
      // جسيمات الحزمة المستقيمة مع انحراف تدريجي
      for (var k = 0; k < 14; k++) {
        final prog = (t * 0.9 + k / 14) % 1;
        final x = tube.left + prog * tube.width;
        final y = tube.center.dy + prog * prog * shift;
        c.drawCircle(
            Offset(x, y),
            4.6,
            Paint()
              ..color = const Color.fromRGBO(170, 255, 200, 0.30)
              ..maskFilter =
                  const ui.MaskFilter.blur(ui.BlurStyle.normal, 3));
        c.drawCircle(Offset(x, y), 2.2,
            Paint()..color = const Color.fromRGBO(220, 255, 235, 0.9));
      }
      // الصليب المالطي (حاجز) وظله على الزجاج
      final crx = tube.left + tube.width * 0.83;
      _maltese(c, Offset(crx, tube.center.dy + shift * 0.55), 26,
          const Color.fromRGBO(200, 215, 230, 0.9));
      _maltese(c, Offset(tube.right + 4, tube.center.dy + shift), 54,
          const Color(0xED080E0A));
    }
    _arabic(c, 'P = ${toAr(p < 1 ? p.toStringAsFixed(2) : p.round().toString())} torr',
        Offset(w / 2, 26), 14, const Color(0xFF9CC3DF));
    _arabic(c, stageLabel, Offset(w / 2, h - 16), 13.5,
        st == 4 ? const Color(0xFF8CFFAA) : const Color(0xFF9CC3DF));
  }

  void _maltese(Canvas c, Offset at, double r, Color col) {
    final p = Path();
    for (final qx in [1.0, -1.0]) {
      for (final qy in [1.0, -1.0]) {
        p.moveTo(at.dx, at.dy);
        p.lineTo(at.dx + qx * r, at.dy);
        p.lineTo(at.dx + qx * r, at.dy + qy * r);
        p.close();
      }
    }
    c.drawPath(p, Paint()..color = col);
  }

  // ══ منظور 3D ══
  void _fillPoly3(Canvas c, Size size, List<P3> pts, Color col) {
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final q = cam.project(pts[i], size);
      i == 0 ? p.moveTo(q.x, q.y) : p.lineTo(q.x, q.y);
    }
    p.close();
    c.drawPath(p, Paint()..color = col);
  }

  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    final st = stage, p = torr;
    const tx0 = -280.0, tx1 = 240.0, rTube = 62.0, cyy = 10.0;
    ring3(c, cam, size, tx0, rTube, const Color.fromRGBO(180, 210, 230, 0.5), 2);
    ring3(c, cam, size, tx1, rTube, const Color.fromRGBO(180, 210, 230, 0.5), 2);
    line3(c, cam, size, P3(tx0, cyy + rTube, 0), P3(tx1, cyy + rTube, 0),
        const Color.fromRGBO(180, 210, 230, 0.32), 1.6);
    line3(c, cam, size, P3(tx0, cyy - rTube, 0), P3(tx1, cyy - rTube, 0),
        const Color.fromRGBO(180, 210, 230, 0.32), 1.6);
    // المهبط
    _fillPoly3(
        c,
        size,
        const [
          P3(tx0 + 8, cyy - rTube * 0.8, -20),
          P3(tx0 + 14, cyy - rTube * 0.8, -20),
          P3(tx0 + 14, cyy + rTube * 0.8, -20),
          P3(tx0 + 8, cyy + rTube * 0.8, -20),
        ],
        const Color(0xE6969696));
    // قاعدة الأنبوب
    _fillPoly3(
        c,
        size,
        const [
          P3(-120, -148, -75),
          P3(120, -148, -75),
          P3(120, -64, -75),
          P3(-120, -64, -75),
        ],
        const Color(0xEB232320));
    _fillPoly3(
        c,
        size,
        const [
          P3(-120, -148, -75),
          P3(-120, -148, 75),
          P3(-120, -64, 75),
          P3(-120, -64, -75),
        ],
        const Color(0xE6191917));
    line3(c, cam, size, P3(tx0 + 12, cyy, 0), const P3(-60, -110, 0),
        const Color.fromRGBO(150, 150, 145, 0.4), 1.5);
    line3(c, cam, size, P3(tx1 - 12, cyy, 0), const P3(60, -110, 0),
        const Color.fromRGBO(150, 150, 145, 0.4), 1.5);
    // شرارة عند الضغط الجوي
    if (hv && st == 1) {
      final spark = Path();
      final p0 = cam.project(P3(tx0 + 12, cyy, 0), size);
      spark.moveTo(p0.x, p0.y);
      for (var k = 0; k < 3; k++) {
        final q = cam.project(
            P3(tx0 + 12 + (math.Random(t.round() * 7 + k).nextDouble() * 22 - 6),
                cyy + (math.Random(t.round() * 11 + k).nextDouble() * 20 - 10),
                math.Random(t.round() * 13 + k).nextDouble() * 14 - 7),
            size);
        spark.lineTo(q.x, q.y);
      }
      c.drawPath(
          spark,
          Paint()
            ..color = const Color.fromRGBO(255, 200, 110, 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }
    // امتداد التوهج حسب المرحلة
    final reach = st == 0
        ? 0.07
        : st == 1
            ? 0.28
            : st == 2
                ? 0.6
                : 1.0;
    final rcol = st == 1
        ? '255,150,200'
        : st >= 2
            ? '140,255,190'
            : '200,220,255';
    for (var k = -2; k <= 2; k++) {
      final bend = mag ? k * 26.0 : 0.0;
      line3(
          c,
          cam,
          size,
          P3(tx0 + 16, cyy + k * 9, 0),
          P3(tx0 + 16 + (tx1 - tx0 - 30) * reach, cyy + k * 9 + bend, 0),
          Color.fromRGBO(
              int.parse(rcol.split(',')[0]),
              int.parse(rcol.split(',')[1]),
              int.parse(rcol.split(',')[2]),
              st == 0 ? 0.2 : 0.55),
          1.8);
    }
    if (reach > 0.5) {
      final gp = cam.project(const P3(tx1 - 16, cyy, 0), size);
      c.drawOval(
          Rect.fromCenter(center: Offset(gp.x, gp.y), width: 32, height: 104),
          Paint()
            ..color = Color.fromRGBO(
                int.parse(rcol.split(',')[0]),
                int.parse(rcol.split(',')[1]),
                int.parse(rcol.split(',')[2]),
                0.5)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8));
    }
    // المغناطيس
    if (mag) {
      _fillPoly3(
          c,
          size,
          const [
            P3(-46, cyy + rTube + 52, -26),
            P3(46, cyy + rTube + 52, -26),
            P3(46, cyy + rTube + 52, 26),
            P3(-46, cyy + rTube + 52, 26),
          ],
          const Color(0xEBB23A34));
      final lp = cam.project(const P3(-24, cyy + rTube + 58, 0), size);
      _arabic(c, 'N', Offset(lp.x, lp.y + 4), 12, const Color(0xFFFFD9CE));
      final lp2 = cam.project(const P3(24, cyy + rTube + 58, 0), size);
      _arabic(c, 'S', Offset(lp2.x, lp2.y + 4), 12, const Color(0xFFE8E2D0));
    }
    _arabic(
        c,
        'p ≈ ${toAr(p < 0.1 ? p.toStringAsFixed(2) : p.round().toString())} torr · المرحلة ${toAr(stage)} من ٤',
        Offset(size.width / 2, 26),
        12,
        const Color(0xFFE8E2D0));
    _arabic(
        c,
        stage == 0
            ? 'شرارة فقط — ضعف التفريغ'
            : stage == 1
                ? 'توهج وردي يمتد'
                : stage == 2
                    ? 'التوهج ينكمش'
                    : mag
                        ? 'أشعة كاثودية تنحرف بالمغناطيس'
                        : 'أشعة كاثودية واضحة',
        Offset(size.width / 2, 46),
        12,
        mag ? const Color(0xFFF0964A) : const Color.fromRGBO(232, 226, 208, 0.8));
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
      appBar: AppBar(title: const Text('المختبر: أنبوب كروكس — أشعة مهبطية')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 430,
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
                painter: _CrookesPainter(this),
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
                  label: 'ضغط الغاز',
                  value: pSlider,
                  min: 0, max: 100, divisions: 100,
                  display:
                      '${toAr(torr < 1 ? torr.toStringAsFixed(2) : torr.round().toString())} torr',
                  onChanged: (x) => setState(() => pSlider = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => hv = !hv),
                    child: Text(hv ? 'التوتر العالي: ON' : 'التوتر العالي: OFF')),
                OutlinedButton(
                    onPressed: () {
                      if (stage < 4) return;
                      setState(() => mag = !mag);
                    },
                    child: const Text('🧲 مغناطيس قرب الأنبوب')),
                OutlinedButton(
                    onPressed: () => setState(() {
                          pSlider = 100;
                          hv = true;
                          mag = false;
                        }),
                    child: const Text('↺ إعادة')),
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
                    'ما الذي يسافر من المهبط السالب نحو الزجاج فيلوّنه؟',
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
                        child: const [
                          Text('ضوء ينتشر بكل الاتجاهات'),
                          Text('جسيمات سالبة في خطوط مستقيمة'),
                          Text('صوت عبر الغاز المتبقي'),
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — أشعة مهبطية: جسيمات سالبة تسير مستقيمة'
                        : '✘ في الظلام التام لا ضوء ولا صوت — إنها جسيمات سالبة',
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
              _chip('المرحلة: ${toAr(stage)} من ٤'),
              _chip(stage == 4 ? 'تألق أخضر ✓' : 'لا تألق بعد'),
              if (!_challengeDoneToday)
                _chip(stage == 4 && mag
                    ? '🎯 منجز!'
                    : '🎯 وصل للتألق الزجاجي ثم انحرف الحزمة بمغناطيس',
                    ok: stage == 4 && mag)
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
              _explainLine('عند الضغط الجوي: مسافة التوهج أقصر من الأنبوب ⇒ شرارة فقط. بإنقاص الضغط يطول مسار التوهج الوردي حتى يملأ الأنبوب.'),
              _explainLine('عند ضغط منخفض جداً: يخلو الأنبوب (ظلام) وتصبح الجسيمات حرة في السير: حزمة مهبطية مستقيمة ⇒ تألق أخضر حيث تصيب الزجاج.'),
              _explainLine('الصليب المالطي يرمي ظلاً حاداً ⇒ الجسيمات تسير في خطوط مستقيمة — الضوء لا ينحرف بالمغناطيس، هذه تنحرف ⇒ جسيمات سالبة (إلكترونات).'),
              _explainLine('المغناطيس يحرف الحزمة والظل معها — الدليل الحاسم على طبيعتها الشحنة.'),
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

class _CrookesPainter extends CustomPainter {
  _CrookesPainter(this.st);
  final _CrookesScreenState st;

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
          '🔒 يُفتح الشرح عند وصول المرحلة ٤ — أنزل الضغط تدريجياً!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
