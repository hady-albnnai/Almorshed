import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-17/18/19 الأوسيلوسكوب: قراءة U₀ وT من الشبكة (نمط موحّد معتمد).
/// ثلاث تجارب متدرجة: خط مستقيم (DC 6V) → موجة جيبية (6V/50Hz) → إشارة 100Hz (4V).
/// كويز قراءة لكل تجربة — إتمام الثلاث ⇒ 🏆 (+١٠) بمفتاح 'oscilloscope'.
/// منظور واقعي (أنبوب CRT بأخضر فوسفوري) + منظور 3D (وشيعة مضيئة وشعاع ينحرف).
class OscilloscopeScreen extends StatefulWidget {
  const OscilloscopeScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<OscilloscopeScreen> createState() => _OscilloscopeScreenState();
}

class _OscilloscopeScreenState extends State<OscilloscopeScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-oscilloscope.html المعتمد) ──
  int mode = 1;
  double u = 6;
  double fq = 50;
  int vd = 2, td = 10;
  bool sweep = true;
  double sweepX = 0;

  static const List<int> vdOpt = [1, 2, 5];
  static const List<int> tdOpt = [5, 10, 25];

  double uOf(double ttMs) {
    if (mode == 1) return u;
    return u * math.sin(2 * math.pi * fq * ttMs / 1000);
  }

  String get modeTitle {
    if (mode == 1) return 'تج١: توتر مستمر DC — اقرأ U₀ من الإزاحة الرأسية';
    if (mode == 2) return 'تج٢: موجة جيبية — اقرأ U₀ (المطال) وT (عرض موجة كاملة)';
    return 'تج٣: إشارة 100Hz — T أصغر: أين الدورة الكاملة؟';
  }

  // ── الكويز ──
  final Set<int> _quizDone = <int>{};
  int? _pick;
  String _feedback = '';

  // ── الكاميرا والنجوم ──
  final OrbitCam cam = OrbitCam(dist: 620, fov: 620);
  final List<Star> stars = makeStars();
  bool view3d = false;
  bool _orbiting = false;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _challengeDoneToday = false;
  bool _announced = false;
  late TrainingData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['oscilloscope'] == dateKeyOf(DateTime.now());
    if (_challengeDoneToday) {
      _quizDone.addAll(const [1, 2, 3]);
    }
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
    sweepX = (sweepX + dt * 0.22) % 1;
    if (_quizDone.length == 3 && !_announced && !_challengeDoneToday) {
      _announced = true;
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
        'oscilloscope': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'oscilloscope'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _setMode(int m) {
    setState(() {
      mode = m;
      sweepX = 0;
      _pick = null;
      _feedback = '';
      if (m == 1) {
        u = 6;
        fq = 50;
      }
      if (m == 2) {
        u = 6;
        fq = 50;
      }
      if (m == 3) {
        u = 4;
        fq = 100;
      }
    });
  }

  // ══ الرسّام الواقعي — أنبوب CRT ══
  void _paintReal(Canvas c, Size size) {
    // أنبوب داكن + توهج مركزي
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF07130C));
    final vg = Paint()
      ..shader = ui.Gradient.radial(
          size.center(Offset(0, -10)),
          size.width * 0.62,
          [const Color.fromRGBO(140, 255, 205, 0.05), const Color(0x8C000000)]);
    c.drawRect(Offset.zero & size, vg);
    // الشبكة: 10 × 8 خانات + تقسيمات فرعية
    final gx0 = size.width * 0.0625, gx1 = size.width * 0.9375;
    final gy0 = size.height * 0.083, gy1 = size.height * 0.875;
    final gw = gx1 - gx0, gh = gy1 - gy0;
    final sub = Paint()
      ..color = const Color(0x12B2FFD7)
      ..strokeWidth = 0.5;
    for (var k = 0; k <= 50; k++) {
      final x = gx0 + gw * k / 50;
      c.drawLine(Offset(x, gy0), Offset(x, gy1), sub);
    }
    for (var k = 0; k <= 40; k++) {
      final y = gy0 + gh * k / 40;
      c.drawLine(Offset(gx0, y), Offset(gx1, y), sub);
    }
    for (var k = 0; k <= 10; k++) {
      final x = gx0 + gw * k / 10;
      c.drawLine(
          Offset(x, gy0),
          Offset(x, gy1),
          Paint()
            ..color = k == 5
                ? const Color(0x66B2FFD7)
                : const Color(0x24B2FFD7)
            ..strokeWidth = 1);
    }
    for (var k = 0; k <= 8; k++) {
      final y = gy0 + gh * k / 8;
      c.drawLine(
          Offset(gx0, y),
          Offset(gx1, y),
          Paint()
            ..color = k == 4
                ? const Color(0x66B2FFD7)
                : const Color(0x24B2FFD7)
            ..strokeWidth = 1);
    }
    _arabic(c, 'V/div = ${toAr(vd)}', Offset(gx0, gy0 - 14), 12.5,
        const Color(0xFF9CD9BC));
    _arabic(c, 'ms/div = ${toAr(td)}', Offset(gx1, gy0 - 14), 12.5,
        const Color(0xFF9CD9BC));
    final cy0 = (gy0 + gy1) / 2;
    final pxPerV = gh / (8 * vd);
    final secPerX = 10 * td / 1000;
    // المسار الفوسفوري المتوهج
    final trace = Path();
    for (var i = 0; i <= 200; i++) {
      final xx = gx0 + gw * i / 200;
      final tt = (i / 200) * secPerX;
      final yy = cy0 - uOf(tt) * pxPerV;
      i == 0 ? trace.moveTo(xx, yy) : trace.lineTo(xx, yy);
    }
    final glow = mode == 1 ? 0.7 : 0.9;
    c.drawPath(
        trace,
        Paint()
          ..color = const Color.fromRGBO(190, 255, 230, 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter =
              const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
    c.drawPath(
        trace,
        Paint()
          ..color = Color.lerp(const Color(0x8CC8FFE6),
                  const Color(0xE6C8FFE6), glow)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6);
    // نقطة المسح
    if (sweep) {
      final sx = gx0 + sweepX * gw;
      final sy = cy0 - uOf(sweepX * secPerX) * pxPerV;
      c.drawCircle(
          Offset(sx, sy),
          9,
          Paint()
            ..color = const Color.fromRGBO(150, 255, 205, 0.25)
            ..maskFilter =
                const ui.MaskFilter.blur(ui.BlurStyle.normal, 6));
      c.drawCircle(Offset(sx, sy), 4, Paint()..color = const Color(0xFFEAFFF5));
    }
    c.drawRect(
        Rect.fromLTWH(gx0, gy0, gw, gh),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x4DB2FFD7)
          ..strokeWidth = 1.5);
    _arabic(c, modeTitle, Offset(size.width / 2, size.height - 18), 13.5,
        const Color(0xFF9CD9BC));
    _arabic(
        c,
        'الإزاحة الرأسية: ${toAr((uOf(0) / vd).toStringAsFixed(1))} خانة ⇒ U₀ = ${toAr(uOf(0).abs().round())}V',
        Offset(size.width / 2, gy1 + 18),
        12.5,
        const Color.fromRGBO(156, 217, 188, 0.55));
  }

  // ══ منظور 3D — وشيعة مضيئة وشعاع ينحرف ══
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
    const sx0 = 250.0;
    final spX = 10 * td / 1000;
    // وشيعة الشاشة الخضراء
    final screen = [
      const P3(sx0, -120, -160),
      const P3(sx0, 120, -160),
      const P3(sx0, 120, 160),
      const P3(sx0, -120, 160),
    ];
    _fillPoly3(c, size, screen, const Color.fromRGBO(90, 140, 110, 0.16));
    stroke3(c, cam, size, screen, const Color.fromRGBO(160, 220, 180, 0.6), 2,
        close: true);
    for (var i = 1; i < 8; i++) {
      final zz = -160.0 + i * 40;
      line3(c, cam, size, P3(sx0, -120, zz), P3(sx0, 120, zz),
          const Color.fromRGBO(120, 180, 140, 0.22), 1);
    }
    for (var i = 1; i < 6; i++) {
      final yy = -120.0 + i * 40;
      line3(c, cam, size, P3(sx0, yy, -160), P3(sx0, yy, 160),
          const Color.fromRGBO(120, 180, 140, 0.22), 1);
    }
    double yV(double uv) =>
        -uv.clamp(-vd * 3, vd * 3) * (120 / (vd * 3));
    // المسار على الوشيعة
    const n = 96;
    final pts = <P3>[];
    for (var i = 0; i <= n; i++) {
      final tt = (i / n) * spX;
      pts.add(P3(sx0, yV(uOf(tt)), -160 + i * (320 / n)));
    }
    stroke3(c, cam, size, pts, const Color.fromRGBO(190, 255, 230, 0.5), 5);
    stroke3(c, cam, size, pts, const Color.fromRGBO(190, 255, 230, 0.9), 2.2);
    if (sweep) {
      final bp = cam.project(
          P3(sx0, yV(uOf(sweepX * spX)), -160 + sweepX * 320), size);
      c.drawCircle(Offset(bp.x, bp.y), 3.4,
          Paint()..color = const Color(0xF2DCFFF0));
    }
    // أنبوب الإلكترونات والصفيحتا الانحراف
    _fillPoly3(
        c,
        size,
        const [P3(-46, -36, -22), P3(8, -30, -22), P3(8, -30, 22), P3(-46, -36, 22)],
        const Color(0xE6969691));
    _fillPoly3(
        c,
        size,
        const [P3(-46, 36, -22), P3(8, 30, -22), P3(8, 30, 22), P3(-46, 36, 22)],
        const Color(0xE6969691));
    _fillPoly3(
        c,
        size,
        const [P3(-280, -10, -14), P3(-140, -6, -10), P3(-140, 6, -10), P3(-280, 10, -14)],
        const Color(0xF282827D));
    line3(c, cam, size, const P3(-46, -33, 0), const P3(-280, -9, 0),
        const Color.fromRGBO(150, 150, 145, 0.5), 1.5);
    line3(c, cam, size, const P3(-46, 33, 0), const P3(-280, 9, 0),
        const Color.fromRGBO(150, 150, 145, 0.5), 1.5);
    _arabic(c,
        '${modeTitle.split(':')[0]} · U = ${toAr(u.round())}V · f = ${toAr(fq.round())}Hz',
        Offset(size.width / 2, 26), 12, const Color(0xFFE8E2D0));
    _arabic(c,
        'V/div = ${toAr(vd)} · T/div = ${toAr(td)}ms${sweep ? ' · المسح يعمل' : ' · مسح متوقف'}',
        Offset(size.width / 2, 46), 11.5,
        const Color.fromRGBO(232, 226, 208, 0.8));
    _arabic(c, 'الشعاع الإلكتروني ينحرف بين الصفيحتين → يرسم الإشارة على الوشيعة المضيئة',
        Offset(size.width / 2, size.height - 34), 11.5,
        const Color.fromRGBO(205, 198, 182, 0.45));
    _arabic(c, 'اسحب لتدوير الكاميرا', Offset(size.width / 2, size.height - 14),
        12, const Color.fromRGBO(205, 198, 182, 0.5));
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

  // ── بيانات الكويز (نسخ من المعتمد) ──
  String get _quizQ {
    if (mode == 1) return 'اقرأ U₀ من الشبكة (بـV):';
    if (mode == 2) return 'ما T بالميلي ثانية؟ (الوقت/الخانة معروض)';
    return 'ما تواتر الإشارة f = 1/T (بـHz)؟';
  }

  List<String> get _quizAns {
    if (mode == 1) return const ['2', '4', '6', '8'];
    if (mode == 2) return const ['10', '20', '25', '50'];
    return const ['25', '50', '100', '200'];
  }

  String get _quizOk {
    if (mode == 1) return '6';
    if (mode == 2) return '20';
    return '100';
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar:
          AppBar(title: const Text('المختبر: الأوسيلوسكوب — قراءة U₀ وT')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 960 / 480,
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
                painter: _OscilloscopePainter(this),
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
                for (var m = 1; m <= 3; m++)
                  ChoiceChip(
                    label: Text(const [
                      'تج١ · DC',
                      'تج٢ · جيبية 50Hz',
                      'تج٣ · 100Hz',
                    ][m - 1]),
                    selected: mode == m,
                    onSelected: (_) => _setMode(m),
                  ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() {
                          vd = vdOpt[(vdOpt.indexOf(vd) + 1) % vdOpt.length];
                        }),
                    child: Text('V/div: ${toAr(vd)}V')),
                OutlinedButton(
                    onPressed: () => setState(() {
                          td = tdOpt[(tdOpt.indexOf(td) + 1) % tdOpt.length];
                        }),
                    child: Text('T/div: ${toAr(td)}ms')),
                OutlinedButton(
                    onPressed: () => setState(() => sweep = !sweep),
                    child: Text(sweep ? 'المسح: يعمل' : 'المسح: متوقف')),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (!_quizDone.contains(mode))
          Card(
            color: const Color(0xFFFFFDF7),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('سؤال التجربة ${toAr(mode)} 🎯',
                    style: txt.titleSmall),
                const SizedBox(height: 4),
                Text(_quizQ, style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final a in _quizAns)
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _pick = int.tryParse(a);
                        if (a == _quizOk) {
                          _quizDone.add(mode);
                          _feedback = '✔ إجابة صحيحة';
                          HapticFeedback.mediumImpact();
                        } else {
                          _feedback = '✘ أعد العد — خانات × قيمة/خانة';
                        }
                      }),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _pick.toString() == a
                                ? (a == _quizOk
                                    ? const Color(0xFF538065)
                                    : const Color(0xFFBB5A45))
                                : const Color(0xFFDCD8CC)),
                      ),
                      child: Text(toAr(a)),
                    ),
                ]),
                if (_feedback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_feedback,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _feedback.startsWith('✔')
                                ? const Color(0xFF538065)
                                : const Color(0xFFBB5A45))),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              for (final m in [1, 2, 3])
                _chip(
                    m == 1
                        ? 'تج١: ${_quizDone.contains(1) ? 'U₀=٦V ✓' : '—'}'
                        : m == 2
                            ? 'تج٢: ${_quizDone.contains(2) ? 'T=٢٠ms ✓' : '—'}'
                            : 'تج٣: ${_quizDone.contains(3) ? 'f=١٠٠Hz ✓' : '—'}',
                    ok: _quizDone.contains(m)),
              if (_challengeDoneToday)
                _chip('🏆 التجارب الثلاث مكتملة (+١٠)', ok: true)
              else
                _chip('🎯 أكمل قراءات التجارب الثلاث', ok: false),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اشرح — قراءة الشبكة', style: txt.titleSmall),
              const SizedBox(height: 6),
              const Center(
                child: Text('U₀ = خانات رأسية × V/div · T = خانات أفقية × ms/div',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('المستمر يرسم خطاً مستقيماً: ارتفاعه عن المحور هو U₀ مباشرة.'),
              _explainLine('الجيبية: من قمة لقمة مقابل = T؛ والمطال = عدد الخانات × V/div.'),
              _explainLine('إذا صغرت T/div دخل عدد أكبر من الدورات على الشاشة — نفس الإشارة بمقياس أدق.'),
              _explainLine('بمنظور 3D: الشعاع الإلكتروني ينحرف رأسياً بين صفيحتين ويرسم على وشيعة مضيئة.'),
              if (_quizDone.isEmpty && !_challengeDoneToday) const _LockedVeil(),
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

class _OscilloscopePainter extends CustomPainter {
  _OscilloscopePainter(this.st);
  final _OscilloscopeScreenState st;

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
          '🔒 يُفتح الشرح بعد أول قراءة صحيحة من الشبكة — جاوب سؤال التجربة!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
