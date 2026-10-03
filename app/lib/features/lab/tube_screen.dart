import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// U2-4/U4-1 أنبوب الأشعة المهبطية (نمط موحّد معتمد).
/// torr = max(0.01, 760·10^(−(pp/100)·4.88)) · beamOn = hv>35 ∧ torr<8
/// · bend = mg/50·clamp(1−torr/8) · ألوان توهج لكل غاز.
/// تحدّي: خفّض الضغط، أشعل الأنبوب، ثم انحرف الشعاع بمغناطيس (+١٠) بمفتاح 'tube'.
class TubeScreen extends StatefulWidget {
  const TubeScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<TubeScreen> createState() => _TubeScreenState();
}

class _TubeScreenState extends State<TubeScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-tube.html المعتمد) ──
  double hv = 70, pp = 60, mg = 0;
  int gas = 0; // 0 هواء · 1 نيون · 2 هيليوم · 3 أرغون
  bool won = false, started = false;

  static const List<List<double>> gcol = [
    [200, 220, 255, 0.9], // هواء
    [255, 70, 60, 1.0], // نيون
    [255, 150, 190, 0.95], // هيليوم
    [170, 110, 255, 0.95], // أرغون
  ];

  double get torr =>
      math.max(0.01, 760 * math.pow(10, -(pp / 100) * 4.88).toDouble());
  bool get beamOn => hv > 35 && torr < 8;
  double get bend =>
      (mg / 50) * (1 - torr / 8).clamp(0.0, 1.0);

  Color gasGlow(double a) {
    final g = gcol[gas];
    return Color.fromRGBO(g[0].round(), g[1].round(), g[2].round(), a);
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
        _data.labChallengeDays['tube'] == dateKeyOf(DateTime.now());
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
    if (beamOn && !started) started = true;
    if (beamOn && bend.abs() > 0.1 && !won && !_challengeDoneToday) {
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
        'tube': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'tube'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      hv = 70;
      pp = 60;
      mg = 0;
      won = false;
      started = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 344.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    final cy = 190.0;
    final tx0 = w * 0.10, tx1 = w * 0.90; // جسم الأنبوب
    final r = 46.0;
    // حامل خشبي
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(tx0 + 40, cy + r + 6, tx1 - tx0 - 80, 14),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF5A4530));
    // زجاج الأنبوب
    final tube = RRect.fromRectAndRadius(
        Rect.fromLTWH(tx0, cy - r, tx1 - tx0, r * 2),
        const Radius.circular(r));
    c.drawRRect(tube, Paint()..color = const Color(0x14303A48));
    c.drawRRect(
        tube,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF8FA3B8)
          ..strokeWidth = 2.4);
    // مهبط سالب يسار وموجب يمين
    c.drawRect(Rect.fromLTWH(tx0 + 6, cy - 26, 10, 52),
        Paint()..color = const Color(0xFFB9C4CE));
    c.drawRect(Rect.fromLTWH(tx1 - 16, cy - 22, 10, 44),
        Paint()..color = const Color(0xFFC89A5A));
    _arabic(c, '−', Offset(tx0 + 11, cy - 38), 14, const Color(0xFFB9C4CE));
    _arabic(c, '+', Offset(tx1 - 11, cy - 34), 14, const Color(0xFFC89A5A));
    // توهج الغاز بالضغط المنخفض
    final glowA = (1 - torr / 760).clamp(0.0, 1.0);
    if (hv > 20 && glowA > 0.05) {
      c.drawRRect(tube,
          Paint()..color = gasGlow(0.32 * glowA * (hv / 100).clamp(0.3, 1.0)));
    }
    // شعاع الإلكترونات
    if (beamOn) {
      final path = Path()..moveTo(tx0 + 16, cy);
      for (var i = 0; i <= 60; i++) {
        final fx = i / 60;
        final x = tx0 + 16 + fx * (tx1 - tx0 - 40);
        final dy = bend * 46 * fx * fx;
        path.lineTo(x, cy + dy);
      }
      c.drawPath(
          path,
          Paint()
            ..color = const Color(0xCC78FFBE)
            ..strokeWidth = 3.2
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6));
      c.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF78FFBE)
            ..strokeWidth = 1.6);
      // بقعة التألق على الزجاج
      final endY = cy + bend * 46;
      c.drawCircle(Offset(tx1 - 24, endY), 9,
          Paint()..color = const Color(0x9978FFBE));
    } else {
      _arabic(
          c,
          torr >= 8 ? 'الضغط مرتفع — لا مسار!' : 'ارفع الجهد فوق ٣٥',
          Offset(w / 2, cy - r - 22),
          12.5,
          const Color(0xFFE08A6A));
    }
    _arabic(
        c,
        'P = ${toAr(torr.toStringAsFixed(1))}Torr · U = ${toAr(hv.round())} · مغناطيس ${toAr(mg.round())}',
        Offset(w / 2, 26),
        12.5,
        const Color(0xFFE8E2D0));
    _arabic(
        c,
        won ? '🎯 انحرف الشعاع — مغناطيس يعمل!' : beamOn ? 'قرّب المغناطيس…' : '—',
        Offset(w / 2, size.height - 16),
        13,
        const Color.fromRGBO(156, 195, 223, 0.85));
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const len = 300.0;
    // جدار الأنبوب (حلقتان + خطوط جانبية)
    for (final e in [-len / 2, len / 2]) {
      ring3(c, cam, size, e, 60, const Color(0x998FA3B8), 2.4);
    }
    for (var k = 0; k < 12; k++) {
      final a = k / 12 * 2 * math.pi;
      final y = math.cos(a) * 60, z = math.sin(a) * 60;
      line3(c, cam, size, P3(-len / 2, y, z), P3(len / 2, y, z),
          const Color(0x558FA3B8), 1.4);
    }
    // الشعاع المنحرف
    if (beamOn) {
      final path = Path();
      var first = true;
      for (var i = 0; i <= 40; i++) {
        final fx = i / 40;
        final p = cam.project(
            P3(-len / 2 + 30 + fx * (len - 60), bend * 130 * fx * fx, 0), size);
        if (first) {
          path.moveTo(p.x, p.y);
          first = false;
        } else {
          path.lineTo(p.x, p.y);
        }
      }
      c.drawPath(
          path,
          Paint()
            ..color = const Color(0xCC78FFBE)
            ..strokeWidth = 3
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(c, 'P = ${toAr(torr.toStringAsFixed(1))}Torr',
        Offset(size.width / 2, 26), 12, const Color(0xFFE8E2D0));
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
      appBar: AppBar(title: const Text('المختبر: أنبوب الأشعة المهبطية')),
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
                painter: _TubePainter(this),
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
                    for (var gi = 0; gi < 4; gi++)
                      ChoiceChip(
                        label: Text(const [
                          'هواء',
                          'نيون',
                          'هيليوم',
                          'أرغون',
                        ][gi]),
                        selected: gas == gi,
                        onSelected: (_) => setState(() => gas = gi),
                      ),
                  ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'جهد التسريع U',
                  value: hv,
                  min: 0, max: 100, divisions: 20,
                  display: '${toAr(hv.round())}',
                  onChanged: (x) => setState(() => hv = x)),
              LabSlider(
                  label: 'ضغط الغاز',
                  value: pp,
                  min: 5, max: 100, divisions: 95,
                  display: '${toAr(torr.toStringAsFixed(1))}Torr',
                  onChanged: (x) => setState(() => pp = x)),
              LabSlider(
                  label: 'مغناطيس (قرب الأنبوب)',
                  value: mg,
                  min: -50, max: 50, divisions: 20,
                  display: '${toAr(mg.round())}',
                  onChanged: (x) => setState(() => mg = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                    ViewToggle(
                        view3d: view3d,
                        onChanged: (x) => setState(() => view3d = x)),
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
                    'أدخلنا مغناطيساً قرب حزمة الأشعة المهبطية — إلى أين تنحرف؟',
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
                          'نحو القطب الشمالي',
                          'نحو القطب المعاكس للتيار',
                          'لا تنحرف — الكتلة صفرية تقريباً',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — F = qv×B وشحنة الإلكترون سالبة ⇒ انحراف معاكس للتيار'
                        : '✘ تذكّر إشارة الشحنة: السالب ينحرف نحو القطب المعاكس للتيار',
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
              _chip(beamOn ? 'الشعاع يعمل ✅' : 'الشعاع مطفأ', ok: beamOn),
              _chip('توهج: ${const ['هواء', 'نيون', 'هيليوم', 'أرغون'][gas]}'),
              if (!_challengeDoneToday)
                _chip(
                    won
                        ? '🎯 منجز! الشعاع انحرف بالمغناطيس'
                        : '🎯 أشعل الأنبوب (P<٨Torr · U>٣٥) ثم انحرف الشعاع بمغناطيس',
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
                child: Text('جسيمات سالبة (إلكترونات) تتسارع U وتنحرف بالمغناطيس',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('الضغط المنخفض ضروري: عند P عالية تقاطع جزيئات الغاز مسار الإلكترونات فلا يظهر شعاع.'),
              _explainLine('الشعاع يأتي من المهبط السالب إلى الموجب ⇒ شحنته سالبة — وينحرف نحو القطب المعاكس للمغناطيس.'),
              _explainLine('كل غاز يعطي توهجاً بلون مميز (نيون أحمر، هيليوم وردي، أرغون بنفسجي) — أساس إشارات النيون.'),
              _explainLine('هذه التجربة أثبتت أن «الأشعة المهبطية» جسيمات مشحونة سالباً — الطريق لاكتشاف الإلكترون.'),
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

class _TubePainter extends CustomPainter {
  _TubePainter(this.st);
  final _TubeScreenState st;

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
          '🔒 يُفتح الشرح بعد أول إشعال — خفّض الضغط وارفع الجهد!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
