import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U3-2/3/4 الوتر بين مسمارين + الرنانة + طليقة/مقيدة (نمط موحّد معتمد).
/// μ=1.2g/m · v=√(FT/μ) · f₁=v/2L · رنين |r−n|≤٤٫٥٪ وسعة 1/√(1+(d·24)²)
/// · نبضة c=260px/s بانعكاس: مقيدة مقلوبة / طليقة بنفس الوجه (PS=cos²).
/// تحدّي: اطرق وقس f₁ ثم أنصّف L — f₁ تتضاعف (+١٠) بمفتاح 'strings'.
class StringsScreen extends StatefulWidget {
  const StringsScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<StringsScreen> createState() => _StringsScreenState();
}

class _StringsScreenState extends State<StringsScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-strings.html المعتمد) ──
  static const double mu = 1.2e-3;
  static const double c2 = 260;
  int mode = 1; // 1 مطرقة · 2 رنانة · 3 طليقة/مقيدة
  double l = 1.0, ft = 70, f = 90;
  double t = 0, a1 = 0;
  double pulseT = -9;
  bool freeEnd = false;
  bool won = false, started = false, halfSeen = false;

  double get vOf => math.sqrt(ft / mu);
  double get f1 => vOf / (2 * l);
  double get rOf => f / f1;
  int get nOf => math.max(1, rOf.round());
  bool get reson {
    final r = rOf, n = nOf.toDouble();
    return (r - n).abs() <= 0.045 * n;
  }

  double get ampOf {
    final d = rOf - nOf;
    return 1 / math.sqrt(1 + (d * 24) * (d * 24));
  }

  /// شكل النبضة cos² بعرض 34px
  double ps(double u) {
    final w = 34.0;
    u = u.abs();
    return u > w ? 0 : math.cos(u / w * math.pi / 2) ** 2;
  }

  double disp(double xi) {
    if (mode == 1) {
      return a1 * 42 * math.sin(math.pi * xi) *
          math.cos(2 * math.pi * f1 * t);
    }
    if (mode == 2) {
      return ampOf * 40 * math.sin(nOf * math.pi * xi) *
          math.cos(2 * math.pi * f * t * 0.25);
    }
    final xPx = xi * l * 300;
    final u = xPx - (t - pulseT) * c2;
    final ur = 2 * l * 300 - (t - pulseT) * c2 - xPx;
    final pr = freeEnd ? ps(ur) : -ps(ur);
    return (ps(u) + pr) * 30;
  }

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
        _data.labChallengeDays['strings'] == dateKeyOf(DateTime.now());
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
    a1 *= math.pow(0.9965, dt * 240).toDouble();
    if (mode == 1) {
      if ((l - 0.5).abs() < 0.01 && (ft - 70).abs() < 1) halfSeen = true;
      if (halfSeen && (l - 1).abs() < 0.01 && !won && !_challengeDoneToday) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
    }
    if ((a1 > 0.2 ||
            (mode == 2 && reson) ||
            (mode == 3 && t - pulseT < 1)) &&
        !started) {
      started = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'strings': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'strings'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _act() {
    setState(() {
      if (mode == 1) {
        a1 = 1;
      } else if (mode == 3) {
        pulseT = t;
      }
    });
  }

  void _reset() {
    setState(() {
      a1 = 0;
      pulseT = -9;
      won = false;
      started = false;
      halfSeen = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 344.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final yStr = 200.0;
    final x0 = w * 0.12, x1 = w * 0.88;
    // مسمارا التثبيت
    for (final px in [x0, x1]) {
      c.drawLine(Offset(px, yStr - 26), Offset(px, benchTop),
          Paint()..color = const Color(0xFF6E6E68)..strokeWidth = 5);
      c.drawCircle(Offset(px, yStr - 28), 5,
          Paint()..color = const Color(0xFF9A9A94));
    }
    // الوتر النابض
    final path = Path();
    for (var i = 0; i <= 220; i++) {
      final xi = i / 220;
      final pt = Offset(x0 + xi * (x1 - x0), yStr - disp(xi));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..color = reson && mode == 2
              ? const Color(0xFFC87A28)
              : const Color(0xFFB0956A)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round);
    // عقد النمط بالرنين
    if (mode == 2 && reson) {
      for (var k = 0; k <= nOf; k++) {
        final xi = k / nOf;
        c.drawCircle(Offset(x0 + xi * (x1 - x0), yStr), 3.6,
            Paint()..color = const Color(0xFF4A4038));
      }
      _arabic(c, 'رنين! n = ${toAr(nOf)}', Offset(w / 2, 52), 14,
          const Color(0xFFF0964A));
    }
    // نهاية طليقة: حلقة على قضيب
    if (mode == 3) {
      c.drawLine(Offset(x1 + 14, yStr - 40), Offset(x1 + 14, yStr + 40),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 4);
      c.drawCircle(Offset(x1 + 4, yStr), 8,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFC9C9C4)
            ..strokeWidth = 2.4);
      _arabic(c, freeEnd ? 'نهاية حرة (حلقة)' : 'نهاية مقيدة (جدار)',
          Offset(x1 + 6, yStr + 62), 11.5,
          const Color.fromRGBO(232, 226, 208, 0.8));
    }
    // صندوق الرنانة
    if (mode == 2) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x0 - 40, yStr + 16, 120, 70),
              const Radius.circular(8)),
          Paint()..color = const Color(0xFF3A2A18));
      _arabic(c, 'رنانة', Offset(x0 + 20, yStr + 51), 11.5,
          const Color.fromRGBO(232, 226, 208, 0.7));
    }
    _arabic(
        c,
        mode == 2
            ? 'f الرنانة = ${toAr(f.round())}Hz · f₁ = ${toAr(f1.toStringAsFixed(1))}Hz'
            : 'f₁ = ${toAr(f1.toStringAsFixed(1))}Hz · v = ${toAr(vOf.toStringAsFixed(1))}m/s',
        Offset(w / 2, 26),
        13,
        const Color(0xFFE8E2D0));
    _arabic(
        c,
        mode == 1
            ? (halfSeen ? '✓ رأيت النصف — أعد L إلى ١m' : 'L = ${toAr(l.toStringAsFixed(2))}m — أنصّفه واسمع الفرق')
            : mode == 3
                ? (t - pulseT < 2.4 ? 'نبضة تعمل…' : '—')
                : 'النمط: ${toAr(nOf)}${reson ? ' — رنين!' : ' (بعيد)'}',
        Offset(w / 2, size.height - 16),
        13,
        const Color.fromRGBO(156, 195, 223, 0.85));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const len = 340.0;
    for (var i = 0; i <= 200; i++) {
      final xi = i / 200;
      final p = cam.project(P3(xi * len - 170, 40, disp(xi) * 0.9), size);
      c.drawCircle(
          Offset(p.x, p.y),
          reson && mode == 2 ? 2.8 : 2.2,
          Paint()
            ..color = reson && mode == 2
                ? const Color(0xFFC87A28)
                : const Color(0xFF8A7350));
    }
    for (final e in [-170.0, 170.0]) {
      line3(c, cam, size, P3(e, 66, 0), P3(e, -80, 0),
          const Color(0xFF6E6E68), 4);
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        mode == 2
            ? 'f = ${toAr(f.round())}Hz · n = ${toAr(nOf)}'
            : 'f₁ = ${toAr(f1.toStringAsFixed(1))}Hz',
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
      appBar: AppBar(title: const Text('المختبر: الوتر والرنانة والنهاية')),
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
                painter: _StringsPainter(this),
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
                    label: const Text('U3-2 · نابل المطرقة'),
                    selected: mode == 1,
                    onSelected: (_) => setState(() => mode = 1)),
                ChoiceChip(
                    label: const Text('U3-3 · صندوق الرنانة'),
                    selected: mode == 2,
                    onSelected: (_) => setState(() => mode = 2)),
                ChoiceChip(
                    label: const Text('U3-4 · طليقة/مقيدة'),
                    selected: mode == 3,
                    onSelected: (_) => setState(() => mode = 3)),
              ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'الطول L',
                  value: l,
                  min: 0.5, max: 1.5, divisions: 20,
                  display: '${toAr(l.toStringAsFixed(2))}m',
                  onChanged: (x) => setState(() => l = x)),
              LabSlider(
                  label: 'الشد FT',
                  value: ft,
                  min: 20, max: 150, divisions: 26,
                  display: '${toAr(ft.round())}N',
                  onChanged: (x) => setState(() => ft = x)),
              if (mode == 2)
                LabSlider(
                    label: 'تواتر الرنانة f',
                    value: f,
                    min: 40, max: 220, divisions: 180,
                    display: '${toAr(f.round())}Hz',
                    onChanged: (x) => setState(() => f = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                    ViewToggle(
                        view3d: view3d,
                        onChanged: (x) => setState(() => view3d = x)),
                    OutlinedButton(
                        onPressed: _act,
                        child: Text(mode == 3 ? '➤ أرسل نبضة' : '🔨 اطرق')),
                    if (mode == 3)
                      OutlinedButton(
                          onPressed: () => setState(() => freeEnd = !freeEnd),
                          child: Text(freeEnd
                              ? '⇄ النهاية: حرة'
                              : '⇄ النهاية: مقيدة')),
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
                    'نبضة تسافر نحو نهاية مقيدة (مثبتة) — كيف تعود بعد الانعكاس؟',
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
                              color: _predictPick == oi + 1
                                  ? (oi + 1 == 2
                                      ? const Color(0xFF538065)
                                      : const Color(0xFFBB5A45))
                                  : const Color(0xFFDCD8CC)),
                        ),
                        child: Text(const [
                          'مقلوبة (قمة تصير قاعاً)',
                          'بنفس الوجه — كأنها انعطفت',
                          'تتلاشى بلا انعكاس',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — النهاية الطليقة تعكس بنفس الوجه (بدون قلب الطور)'
                        : '✘ المقيدة هي المقلوبة — الطليقة تحافظ على الوجه',
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
              _chip('v = ${toAr(vOf.toStringAsFixed(1))}m/s'),
              _chip('f₁ = ${toAr(f1.toStringAsFixed(1))}Hz'),
              if (mode == 2)
                _chip(reson ? 'رنين n=${toAr(nOf)}' : 'بعيد عن الرنين', ok: reson),
              if (!_challengeDoneToday)
                _chip(
                    won
                        ? '🎯 منجز! f₁ تضاعفت بإنصاف L'
                        : '🎯 اطرق وقس f₁ ثم غيّر L إلى النصف — f₁ تتضاعف',
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
                child: Text('v = √(FT/μ) · f₁ = v/2L · L = n·λ/2',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 16)),
              ),
              const SizedBox(height: 6),
              _explainLine('إنصاف L يضاعف f₁ (علاقة عكسية مباشرة) — قارن القراءتين قبل وبعد.'),
              _explainLine('الرنانة تضخم الصوت عند f=n·f₁ فقط: خارج الرنين الصوت خافت بلا تضخيم.'),
              _explainLine('النهاية المثبتة تعكس مقلوبة (عقدة إجبارية) والحرة تعكس بنفس الوجه (بطن إجباري).'),
              _explainLine('مضاعفة FT أربعة أمثال ⇒ v تتضاعف ⇒ f₁ تتضاعف — الشد أقوى فعل من الطول.'),
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

class _StringsPainter extends CustomPainter {
  _StringsPainter(this.st);
  final _StringsScreenState st;

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
          '🔒 يُفتح الشرح بعد أول طرقة — اضغط «اطرق» واسمع!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
