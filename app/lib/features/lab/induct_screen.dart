import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-11/12 وشيعتان + قانون لينز (نمط موحّد معتمد).
/// وضع ١: ε₂ = −M·dI₁/dt (M₀=0.9، قلب حديدي ×5.5) — وميض عند التبديل فقط
/// بإيعاء DC، وإضاءة مستمرة بـAC (3.4·sin(2π·2.2t)).
/// وضع ٢ لينز: φ(u)=(0.49/(0.49+u²))^1.5، ε₂=−pol·1.4·Δφ·0.055/Δt، عدّاد
/// (tg−ang)·62−32·angV — توقّع جهة الإبرة في ٤ سيناريوهات (+١٠) بمفتاح 'induct'.
class InductScreen extends StatefulWidget {
  const InductScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<InductScreen> createState() => _InductScreenState();
}

class _InductScreenState extends State<InductScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-induct.html المعتمد) ──
  static const double m0 = 0.9;
  int mode = 1; // 1 وشيعتان · 2 لينز
  bool key = false, ac = false, core = false;
  double t = 0;
  bool won = false;
  double i1 = 0, i1p = 0, eps2 = 0, lamp = 0;
  bool lampSeen = false, acSeen = false;
  // لينز
  int scen = 0; // 1 Nيقترب · 2 Nيبتعد · 3 Sيقترب · 4 Sيبتعد
  double mgx = 790, mgv = 0;
  int pol = 1;
  int guess = 0; // 1 يمين · -1 يسار
  int rights = 0, asked = 0;
  double ang = 0, angV = 0, phiP = 0;
  bool moving = false;
  String lensFb = '';

  double get mOf => m0 * (core ? 5.5 : 1.0);
  double get uOf => (mgx - 490) / 100;
  double phiOf(double ux) => math.pow(0.49 / (0.49 + ux * ux), 1.5).toDouble();

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
        _data.labChallengeDays['induct'] == dateKeyOf(DateTime.now());
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
        if (ac) {
          i1 = 3.4 * math.sin(2 * math.pi * 2.2 * t);
        } else {
          final target = key ? 3.4 : 0.0;
          i1 += (target - i1) * (st * 4.5).clamp(0.0, 1.0);
        }
        final dIdt = (i1 - i1p) / st;
        i1p = i1;
        eps2 = -mOf * dIdt * 0.12;
        lamp = (eps2.abs() * 0.9 - 0.06).clamp(0.0, 1.0);
        if (lamp > 0.5) {
          lampSeen = true;
          if (ac) acSeen = true;
        }
        if (lampSeen && acSeen && !won && !_challengeDoneToday) {
          won = true;
          HapticFeedback.mediumImpact();
          _recordChallenge();
        }
      } else {
        if (moving) {
          mgx += mgv * st;
          if (mgx < 360) {
            mgx = 360;
            mgv = 0;
            moving = false;
            _verify();
          }
          if (mgx > 790) {
            mgx = 790;
            mgv = 0;
            moving = false;
            _verify();
          }
          final phi = phiOf(uOf());
          eps2 = -pol * 1.4 * (phi - phiP) / st * 0.055;
          phiP = phi;
          final tg = (eps2 * 0.42).clamp(-1.0, 1.0);
          final a = (tg - ang) * 62 - 32 * angV;
          angV += a * st;
          ang += angV * st;
        } else {
          eps2 = 0;
        }
      }
    }
  }

  void _verify() {
    final truth = ang > 0.05 ? 1 : (ang < -0.05 ? -1 : 0);
    if (truth == guess) {
      rights++;
      lensFb = '✔ صحيح! (${toAr(rights)}/٤)';
    } else {
      lensFb = '✘ الحركة تعاكس التغيّر — أعد المشهد';
    }
    if (rights >= 4 && !won && !_challengeDoneToday) {
      won = true;
      HapticFeedback.mediumImpact();
      _recordChallenge();
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
        'induct': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'induct'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _pickScenario(int s) {
    setState(() {
      scen = s;
      moving = false;
      mgv = 0;
      guess = 0;
      ang = 0;
      angV = 0;
      lensFb = '';
      // نقطة البداية: المقترب من بعيد (٧٩٠) والمبتعد قرب الوشيعة (٣٦٠)
      mgx = (s == 1 || s == 3) ? 790 : 360;
    });
  }

  void _pickGuess(int g) {
    if (scen == 0 || moving || guess != 0) return;
    setState(() {
      guess = g;
      asked++;
      mgv = (scen == 1 || scen == 3) ? -120.0 : 120.0;
      pol = scen <= 2 ? 1 : -1;
      moving = true;
      phiP = phiOf(uOf());
    });
  }

  void _reset() {
    setState(() {
      key = false;
      ac = false;
      core = false;
      i1 = 0;
      i1p = 0;
      eps2 = 0;
      lamp = 0;
      lampSeen = false;
      acSeen = false;
      scen = 0;
      mgx = 790;
      mgv = 0;
      moving = false;
      guess = 0;
      rights = 0;
      asked = 0;
      ang = 0;
      angV = 0;
      won = false;
      lensFb = '';
    });
  }

  String get scenLabel => const [
        '— اختر سيناريو —',
        'N يقترب',
        'N يبتعد',
        'S يقترب',
        'S يبتعد',
      ][scen];

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 348.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final cy = 220.0;
    if (mode == 1) {
      // وشيعتان متقابلتان + قلب اختياري
      final x1 = w * 0.30, x2 = w * 0.68;
      if (core) {
        c.drawLine(Offset(x1 - 46, cy), Offset(x2 + 46, cy),
            Paint()..color = const Color(0xFF8A8F94)..strokeWidth = 12);
      }
      for (final spec in [
        (x: x1, col: const Color(0xFFC89A5A), label: 'أولية N=٢٠'),
        (x: x2, col: const Color(0xFF9A9A94), label: 'ثانوية'),
      ]) {
        for (var k = 0; k < 9; k++) {
          c.drawOval(
              Rect.fromCenter(
                  center: Offset(spec.x, cy - 60 + k * 15),
                  width: 96,
                  height: 13),
              Paint()
                ..style = PaintingStyle.stroke
                ..color = spec.col
                ..strokeWidth = 3);
        }
        _arabic(c, spec.label, Offset(spec.x, cy + 92), 11.5,
            const Color.fromRGBO(232, 226, 208, 0.7));
      }
      // بطارية ومفتاح (أولية)
      c.drawLine(Offset(x1, cy - 96), Offset(x1, cy - 128),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.5);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x1 - 34, cy - 152, 68, 26),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFF232320));
      _arabic(c, ac ? '~ AC' : (key ? '🔋 مفتاح مغلق' : '🔑 مفتاح مفتوح'),
          Offset(x1, cy - 139), 10.5,
          key || ac ? const Color(0xFF8CFFAA) : const Color(0xFFE8E2D0));
      // مصباح (ثانوية) يتوهج بlamp
      final glow = lamp.clamp(0.0, 1.0);
      c.drawCircle(Offset(x2, cy - 132), 16,
          Paint()
            ..color = Color.fromRGBO(
                255, 214, 130, (0.12 + 0.75 * glow).toDouble()));
      c.drawCircle(Offset(x2, cy - 132), 9,
          Paint()..color = Color.fromRGBO(255, 230, 160, (0.25 + 0.7 * glow).toDouble()));
      c.drawLine(Offset(x2, cy - 96), Offset(x2, cy - 116),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.2);
      _arabic(
          c,
          'I₁ = ${toAr(i1.abs().toStringAsFixed(2))}A${ac ? ' (AC)' : ' (DC)'} · ε₂ = ${toAr(eps2.toStringAsFixed(2))}V',
          Offset(w / 2, 26),
          13,
          const Color(0xFFE8E2D0));
      _arabic(c, 'M = ${toAr(mOf.toStringAsFixed(2))}${core ? ' · قلب حديدي' : ' · هواء'}',
          Offset(w / 2, 48), 12, const Color(0xFF9CC3DF));
      _arabic(
          c,
          lamp > 0.5 ? '💡 المصباح يضيء!' : 'المصباح مطفأ — غيّر I₁',
          Offset(w / 2, size.height - 16),
          13,
          lamp > 0.5 ? const Color(0xFF8CFFAA) : const Color.fromRGBO(156, 195, 223, 0.85));
    } else {
      // لينز: وشيعة + مغناطيس متحرك + عدّاد مركزي
      final cx0 = w * 0.32, cy0 = 230.0;
      for (var k = 0; k < 8; k++) {
        c.drawOval(
            Rect.fromCenter(
                center: Offset(cx0, cy0 - 52 + k * 15), width: 88, height: 12),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFFC89A5A)
              ..strokeWidth = 3);
      }
      // المغناطيس
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(mgx - 60, cy0 - 14, 60, 28),
              const Radius.circular(4)),
          Paint()..color = pol > 0 ? const Color(0xFFB23A34) : const Color(0xFF3E6FA8));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(mgx, cy0 - 14, 60, 28),
              const Radius.circular(4)),
          Paint()..color = pol > 0 ? const Color(0xFF3E6FA8) : const Color(0xFFB23A34));
      _arabic(c, pol > 0 ? 'N' : 'S', Offset(mgx - 30, cy0), 12,
          const Color(0xFFFFD9CE));
      _arabic(c, pol > 0 ? 'S' : 'N', Offset(mgx + 30, cy0), 12,
          const Color(0xFFCFE3F7));
      // عدّاد لينز
      final mx = w * 0.72, my = 120.0;
      c.drawArc(Rect.fromCircle(center: Offset(mx, my), radius: 52),
          math.pi / 6, 2 * math.pi / 3, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color.fromRGBO(230, 228, 220, 0.4)
            ..strokeWidth = 2);
      final na = ang.clamp(-1.0, 1.0) * (math.pi / 3);
      c.drawLine(
          Offset(mx, my),
          Offset(mx + math.sin(na) * 46, my - math.cos(na) * 46),
          Paint()
            ..color = const Color(0xFFE86A4A)
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round);
      _arabic(c, 'ε₂ = ${toAr(eps2.toStringAsFixed(2))}V', Offset(mx, my + 74),
          12.5, const Color(0xFF9CD9BC));
      _arabic(c, scenLabel, Offset(cx0, 60), 14, const Color(0xFFF0964A));
      if (guess != 0) {
        _arabic(c, 'توقعك: ${guess > 0 ? 'يمين' : 'يسار'}', Offset(mx, 40), 12,
            const Color.fromRGBO(232, 226, 208, 0.85));
      }
      if (lensFb.isNotEmpty) {
        _arabic(c, lensFb, Offset(w / 2, size.height - 16), 13,
            lensFb.startsWith('✔') ? const Color(0xFF8CFFAA) : const Color(0xFFE86A4A));
      }
    }
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    if (mode == 1) {
      for (final spec in [
        (x: -150.0, col: const Color(0xB3C89A5A)),
        (x: 150.0, col: const Color(0xB39A9A94)),
      ]) {
        for (var k = 0; k < 6; k++) {
          final xx = spec.x - 20 + k * 8;
          line3(c, cam, size, P3(xx, -46, 0), P3(xx, 46, 0), spec.col, 2.4);
        }
      }
      if (core) {
        line3(c, cam, size, const P3(-200, 0, 0), const P3(200, 0, 0),
            const Color(0xFF8A8F94), 10);
      }
      final glow = lamp.clamp(0.0, 1.0);
      final lp = cam.project(const P3(210, 90, 0), size);
      c.drawCircle(Offset(lp.x, lp.y), 10 + 6 * glow,
          Paint()..color = Color.fromRGBO(255, 214, 130, (0.15 + 0.7 * glow).toDouble()));
    } else {
      ring3(c, cam, size, -120, 60, const Color(0xE6C89A5A), 4);
      final mx = (mgx - 490) / 2;
      line3(c, cam, size, P3(mx - 30, 30, 0), P3(mx + 30, 30, 0),
          pol > 0 ? const Color(0xFFB23A34) : const Color(0xFF3E6FA8), 14);
      line3(c, cam, size, P3(mx + 30, 30, 0), P3(mx + 70, 30, 0),
          pol > 0 ? const Color(0xFF3E6FA8) : const Color(0xFFB23A34), 14);
      // إبرة العدّاد
      final na = ang.clamp(-1.0, 1.0) * (math.pi / 3);
      line3(c, cam, size, const P3(220, 40, 0),
          P3(220 + math.sin(na) * 70, 40 - math.cos(na) * 70, 0),
          const Color(0xFFE86A4A), 3);
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        mode == 1
            ? 'I₁ = ${toAr(i1.abs().toStringAsFixed(2))}A · ε₂ = ${toAr(eps2.toStringAsFixed(2))}V'
            : 'ε₂ = ${toAr(eps2.toStringAsFixed(2))}V · ${scenLabel}',
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
      appBar: AppBar(title: const Text('المختبر: وشيعتان + قانون لينز')),
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
                painter: _InductPainter(this),
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
                    label: const Text('U2-11 · وشيعتان'),
                    selected: mode == 1,
                    onSelected: (_) => setState(() => mode = 1)),
                ChoiceChip(
                    label: const Text('U2-12 · قانون لينز'),
                    selected: mode == 2,
                    onSelected: (_) => setState(() => mode = 2)),
              ]),
              const SizedBox(height: 6),
              if (mode == 2)
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                    children: [
                      for (var s = 1; s <= 4; s++)
                        OutlinedButton(
                          onPressed: () => _pickScenario(s),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: scen == s
                                    ? const Color(0xFFDD6E42)
                                    : const Color(0xFFDCD8CC)),
                          ),
                          child: Text(const [
                            'N يقترب',
                            'N يبتعد',
                            'S يقترب',
                            'S يبتعد',
                          ][s - 1]),
                        ),
                    ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                    ViewToggle(
                        view3d: view3d,
                        onChanged: (x) => setState(() => view3d = x)),
                    if (mode == 1) ...[
                      OutlinedButton(
                          onPressed: () => setState(() => key = !key),
                          child: Text(key ? '🔑 مفتاح مغلق' : '🔑 إغلاق المفتاح')),
                      OutlinedButton(
                          onPressed: () => setState(() => ac = !ac),
                          child: Text(ac ? '~ بدّل إلى DC' : '~ بدّل إلى AC')),
                      OutlinedButton(
                          onPressed: () => setState(() => core = !core),
                          child: Text(core ? '🧱 أخرج القلب' : '🧱 قلب حديدي')),
                    ] else ...[
                      OutlinedButton(
                          onPressed: () => _pickGuess(1),
                          child: const Text('يمين ➜')),
                      OutlinedButton(
                          onPressed: () => _pickGuess(-1),
                          child: const Text('⬅ يسار')),
                    ],
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
                    'أغلقنا المفتاح وتركنا التيار ثابتاً — لماذا انطفأ مصباح الوشيعة الثانية؟',
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
                          'لأن المصباح يقع مباشرة على البطارية',
                          'لأن التيار المتغيّر فقط يولّد dΦ/dt — وI يستقر فينطفئ التحريض',
                          'لأن المفتاح يضخ طاقة',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — ε = −M·dI/dt: بلا تغيّر لا تحريض. جرب AC!'
                        : '✘ ε = −M·dI/dt: التحريض يحتاج تغيّراً في I — الثابت لا يولّد شيئاً',
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
                _chip('I₁ = ${toAr(i1.abs().toStringAsFixed(2))}A'),
                _chip('ε₂ = ${toAr(eps2.toStringAsFixed(2))}V'),
                _chip(lamp > 0.5 ? '💡 يضيء' : 'مطفأ'),
                if (!_challengeDoneToday)
                  _chip(
                      won ? '🎯 منجز!' : '🎯 لمحة ببطارية ثم إضاءة مستمرة بـAC',
                      ok: won)
                else
                  _chip('🏆 التحدي منجز اليوم (+١٠)', ok: true),
              ] else ...[
                _chip('السيناريو: ${scenLabel}'),
                _chip('صحيح: ${toAr(rights)}/٤'),
                if (!_challengeDoneToday)
                  _chip(
                      won ? '🎯 منجز!' : '🎯 صحّح جهة الإبرة في السيناريوهات الأربعة',
                      ok: won)
                else
                  _chip('🏆 التحدي منجز اليوم (+١٠)', ok: true),
              ],
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
                child: Text('ε₂ = −M·dI₁/dt · لينز: التيار المُحرَّض يعاكس التغيّر الذي ولّده',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('وميض عند الإغلاق والفتح فقط: dI/dt كبير لحظة التبديل ثم يستقر I فيغيب التحريض.'),
              _explainLine('بـAC يظل I متغيّراً دائماً ⇒ ε₂ مستمرة والمصباح يضيء باستمرار.'),
              _explainLine('القلب الحديدي يرفع M أضعافاً (٥٫٥×) ⇒ وميض أقوى بوضوح.'),
              _explainLine('لينز: N يقترب ⇒ الإبرة تدفع تياراً يصدّه؛ N يبتعد ⇒ يلاحقه — عكسهما مع S.'),
              if (!lampSeen && !_challengeDoneToday && mode == 1)
                const _LockedVeil(),
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

class _InductPainter extends CustomPainter {
  _InductPainter(this.st);
  final _InductScreenState st;

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
          '🔒 يُفتح الشرح بعد أول وميض — أغلق المفتاح ثم بدّل إلى AC!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
