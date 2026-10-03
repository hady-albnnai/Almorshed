import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-20/21 القيمة الفعّالة + R/L/C أمام AC/DC (نمط موحّد معتمد).
/// Ueff = U₀/√٢ ≈ ٠٫٧٠٧·U₀ (دارتان متساويتا التوهج) · سطوع المعتمد:
/// R→U₀/8 · AC: C→U₀·f/240+0.25 ، L→U₀/(8+f·0.02) · DC: C→0 ، L→0.95.
/// تحدّي: طابِق التوهجين ثم اقرأ Ueff (+١٠) بمفتاح 'ac'.
class AcScreen extends StatefulWidget {
  const AcScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<AcScreen> createState() => _AcScreenState();
}

class _AcScreenState extends State<AcScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-ac.html المعتمد) ──
  int mode = 1; // 1 القيمة الفعّالة · 2 R/L/C
  double u0 = 6, f = 50;
  String elem = 'R';
  bool ac = true;
  double t = 0;
  bool won = false, started = false;
  bool matched = false;

  double uOf(double tt) => ac ? u0 * math.sin(2 * math.pi * f * tt / 1000) : u0;

  double bright() {
    if (mode == 1) return 1;
    if (elem == 'R') return (u0 / 8).clamp(0.0, 1.0);
    if (ac) {
      return elem == 'C'
          ? (u0 * f / 240 + 0.25).clamp(0.0, 1.0)
          : (u0 / (8 + f * 0.02)).clamp(0.0, 0.8);
    }
    return elem == 'C' ? 0 : 0.95;
  }

  double get uEff => u0 / math.sqrt2;

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
        _data.labChallengeDays['ac'] == dateKeyOf(DateTime.now());
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
    if (mounted) setState(() {});
  }

  void _match() {
    if (matched) return;
    setState(() {
      matched = true;
      started = true;
      if (!won && !_challengeDoneToday) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    });
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'ac': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'ac'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      won = false;
      matched = false;
      started = false;
    });
  }

  String get elemText {
    if (elem == 'R') return 'R: يمرّ بالحالتين';
    if (elem == 'C') return 'C: يمنع DC · يمرّر AC';
    return 'L: سلك بالDC · يعارض AC';
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 340.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    if (mode == 1) {
      // دارتان: AC (ذروة U₀) ومرجعية (Ueff) — التوهج يطابق عند المطابقة
      final glow = matched ? 1.0 : 0.0;
      final acB = (0.35 + 0.55 * u0 / 12).clamp(0.0, 1.0);
      final dcB = (0.35 + 0.55 * (uEff * math.sqrt2) / 12 * 0.707).clamp(0.0, 1.0);
      for (final spec in [
        (x: w * 0.30, b: acB, label: 'مصدر AC (ذروة U₀)'),
        (x: w * 0.70, b: dcB, label: 'مرجع Ueff'),
      ]) {
        c.drawCircle(
            Offset(spec.x, 150),
            20,
            Paint()
              ..color = Color.fromRGBO(
                  255, 214, 130, (0.10 + 0.6 * spec.b + 0.25 * glow).toDouble()));
        c.drawCircle(
            Offset(spec.x, 150),
            11,
            Paint()
              ..color = Color.fromRGBO(
                  255, 232, 160, (0.2 + 0.65 * spec.b + 0.15 * glow).toDouble()));
        c.drawLine(
            Offset(spec.x, 178),
            Offset(spec.x, 210),
            Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.4);
        _arabic(c, spec.label, Offset(spec.x, 232), 11.5,
            const Color.fromRGBO(232, 226, 208, 0.75));
      }
      // شاشة مصغّرة: جيبية U₀ مع خط Ueff
      final sx = w * 0.5, sy = 300.0, sw = 300.0, sh = 84.0;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(sx - sw / 2, sy - sh / 2, sw, sh),
              const Radius.circular(8)),
          Paint()..color = const Color(0xE607130C));
      Offset? prev;
      for (var k = 0; k <= 60; k++) {
        final uu = u0 * math.sin(2 * math.pi * f * (k / 60) * (40.0 / f) / 1000);
        final pt = Offset(
            sx - sw / 2 + sw * k / 60,
            sy - uu / u0 * (sh / 2 - 8));
        if (prev != null) {
          c.drawLine(prev, pt,
              Paint()..color = const Color(0xFF9CD9BC)..strokeWidth = 1.8);
        }
        prev = pt;
      }
      final uey = sy - (uEff / u0) * (sh / 2 - 8);
      c.drawLine(
          Offset(sx - sw / 2, uey),
          Offset(sx + sw / 2, uey),
          Paint()
            ..color = const Color(0xFFF0964A)
            ..strokeWidth = 1.6);
      _arabic(c, 'Ueff', Offset(sx + sw / 2 - 26, uey - 10), 10.5,
          const Color(0xFFF0964A));
      _arabic(c, 'U₀ = ${toAr(u0.round())}V · Ueff المقاسة = ${toAr(uEff.toStringAsFixed(2))}V',
          Offset(w / 2, 26), 13.5, const Color(0xFFE8E2D0));
      _arabic(
          c,
          matched ? '→ نفس التوهج ⇒ نفس القيمة الفعّالة' : 'انقر «طابِق التوهجين» للمقارنة',
          Offset(w / 2, 48),
          12.5,
          matched ? const Color(0xFF8CFFAA) : const Color(0xFFF0964A));
      _arabic(c, 'Ueff = U₀/√٢ = ${toAr((u0 / math.sqrt2).toStringAsFixed(2))}V',
          Offset(w / 2, size.height - 16), 13.5,
          matched ? const Color(0xFF8CFFAA) : const Color.fromRGBO(156, 195, 223, 0.85));
    } else {
      // عنصر R/L/C أمام مصدر AC/DC
      final b = bright();
      final lx = w * 0.5;
      c.drawCircle(
          Offset(lx, 160),
          20,
          Paint()
            ..color = Color.fromRGBO(255, 214, 130, (0.08 + 0.75 * b).toDouble()));
      c.drawCircle(
          Offset(lx, 160),
          11,
          Paint()
            ..color = Color.fromRGBO(255, 232, 160, (0.15 + 0.7 * b).toDouble()));
      // رمز العنصر
      final ex = w * 0.5, ey = 250.0;
      c.drawLine(Offset(ex - 90, ey), Offset(ex - 34, ey),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.6);
      c.drawLine(Offset(ex + 34, ey), Offset(ex + 90, ey),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.6);
      if (elem == 'R') {
        c.drawRect(Rect.fromLTWH(ex - 34, ey - 12, 68, 24),
            Paint()..color = const Color(0xFFC89A5A));
      } else if (elem == 'C') {
        c.drawLine(Offset(ex - 8, ey - 20), Offset(ex - 8, ey + 20),
            Paint()..color = const Color(0xFF9CD9BC)..strokeWidth = 4);
        c.drawLine(Offset(ex + 8, ey - 20), Offset(ex + 8, ey + 20),
            Paint()..color = const Color(0xFF9CD9BC)..strokeWidth = 4);
      } else {
        for (var k = 0; k < 4; k++) {
          c.drawArc(
              Rect.fromLTWH(ex - 30 + k * 16, ey - 16, 16, 32),
              math.pi,
              math.pi,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = const Color(0xFFC89A5A)
                ..strokeWidth = 3.2);
        }
      }
      _arabic(
          c,
          'المصدر: ${ac ? 'AC ${toAr(f.round())}Hz' : 'DC'} · العنصر: $elem · السطوع ${toAr((b * 100).round())}٪',
          Offset(w / 2, 26),
          13.5,
          const Color(0xFFE8E2D0));
      _arabic(c, elemText, Offset(w / 2, 48), 12.5, const Color(0xFF9CD9BC));
      _arabic(
          c,
          b > 0.05 ? 'يمرّ — المصباح يضيء' : 'محجوب — المصباح منطفئ',
          Offset(w / 2, size.height - 16),
          13,
          b > 0.05 ? const Color(0xFF8CFFAA) : const Color(0xFFE86A4A));
    }
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    final b = mode == 1 ? (matched ? 1.0 : 0.5) : bright();
    // مصباح كرة متوهجة
    final lp = cam.project(const P3(0, 30, 0), size);
    c.drawCircle(
        Offset(lp.x, lp.y),
        26 * lp.s / cam.fov * 640 + 8 * b,
        Paint()
          ..color = Color.fromRGBO(255, 214, 130, (0.15 + 0.6 * b).toDouble()));
    c.drawCircle(Offset(lp.x, lp.y), 10,
        Paint()..color = Color.fromRGBO(255, 232, 160, (0.3 + 0.6 * b).toDouble()));
    line3(c, cam, size, const P3(0, 4, 0), const P3(0, -60, 0),
        const Color(0xFF8F8F8A), 3);
    if (mode == 2) {
      if (elem == 'C') {
        line3(c, cam, size, const P3(-60, -80, 0), const P3(-45, -80, 0),
            const Color(0xFF9CD9BC), 5);
        line3(c, cam, size, const P3(45, -80, 0), const P3(60, -80, 0),
            const Color(0xFF9CD9BC), 5);
      } else if (elem == 'L') {
        ring3(c, cam, size, 0, 14, const Color(0xE6C89A5A), 3);
      } else {
        line3(c, cam, size, const P3(-45, -80, 0), const P3(45, -80, 0),
            const Color(0xFFC89A5A), 8);
      }
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        mode == 1
            ? 'U₀ = ${toAr(u0.round())}V · Ueff = ${toAr(uEff.toStringAsFixed(2))}V'
            : '$elem · ${ac ? 'AC' : 'DC'} · سطوع ${toAr((b * 100).round())}٪',
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
      appBar: AppBar(title: const Text('المختبر: القيمة الفعّالة + R/L/C')),
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
              onDoubleTap: mode == 1 ? _match : null,
              child: CustomPaint(
                painter: _AcPainter(this),
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
                    label: const Text('U2-20 · القيمة الفعّالة'),
                    selected: mode == 1,
                    onSelected: (_) => setState(() => mode = 1)),
                ChoiceChip(
                    label: const Text('U2-21 · R/L/C'),
                    selected: mode == 2,
                    onSelected: (_) {
                      setState(() {
                        mode = 2;
                        started = true;
                      });
                    }),
              ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'U₀',
                  value: u0,
                  min: 2, max: 12, divisions: 10,
                  display: '${toAr(u0.round())}V',
                  onChanged: (x) => setState(() => u0 = x)),
              LabSlider(
                  label: 'التواتر f',
                  value: f,
                  min: 20, max: 120, divisions: 20,
                  display: '${toAr(f.round())}Hz',
                  onChanged: (x) => setState(() => f = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                    ViewToggle(
                        view3d: view3d,
                        onChanged: (x) => setState(() => view3d = x)),
                    if (mode == 2)
                      for (final e in const ['R', 'C', 'L'])
                        ChoiceChip(
                            label: Text(e),
                            selected: elem == e,
                            onSelected: (_) =>
                                setState(() { elem = e; started = true; })),
                    if (mode == 2)
                      OutlinedButton(
                          onPressed: () =>
                              setState(() { ac = !ac; started = true; }),
                          child: Text(ac ? '~ بدّل إلى DC' : '~ بدّل إلى AC')),
                    if (mode == 1)
                      OutlinedButton(
                          onPressed: _match, child: const Text('🔆 طابِق التوهجين')),
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
                    'دارتان متساويتا التوهج: واحدة AC بذروة U₀ وواحدة DC — علاقة U₀ بقيمة DC؟',
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
                          'U₀ = Ueff',
                          'U₀ = Ueff·√٢ — الفعّالة أصغر',
                          'U₀ = Ueff/√٢',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — الجيبية تنفق جزءاً من زمنها قرب الصفر ⇒ Ueff = U₀/√٢'
                        : '✘ القيمة الفعّالة أصغر من الذروة: Ueff = U₀/√٢ ≈ ٠٫٧٠٧·U₀',
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
              _chip('U₀ = ${toAr(u0.round())}V'),
              _chip('Ueff = ${toAr(uEff.toStringAsFixed(2))}V'),
              if (mode == 2) _chip(elemText),
              if (!_challengeDoneToday)
                _chip(
                    mode == 1
                        ? (won ? '🎯 منجز!' : '🎯 طابِق التوهجين ثم اقرأ Ueff')
                        : '🎯 جرب كل عنصر مع DC ثم AC — من يمرّ ومن يمنع؟',
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
                child: Text('Ueff = U₀/√٢ ≈ ٠٫٧٠٧·U₀ · C يمنع DC · L تعارض AC',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('الفعّالة تعني «ما ينتج نفس الطاقة الحرارية»: الجيبية توازي مستمراً ٠٫٧٠٧× ذروتها.'),
              _explainLine('المكثف يشحن مرة واحدة فيقف أمام DC، لكنه يتنفّس مع AC فيمرّر — ويزيد تمريره مع f.'),
              _explainLine('الوشيعة تمرّر DC كأنها سلك، وتعارض تغيّر AC — ويزيد تعارضها مع f (X_L = 2πfL).'),
              _explainLine('لذلك المصانع توصّل المحركات بالـAC لأنه سهل التوليد وموتراته تعمل بقيمة فعّالة ثابتة.'),
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

class _AcPainter extends CustomPainter {
  _AcPainter(this.st);
  final _AcScreenState st;

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
          '🔒 يُفتح الشرح بعد المطابقة أو أول تجربة عنصر — جرّب!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
