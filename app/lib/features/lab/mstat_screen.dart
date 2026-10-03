import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-1/2/3 مغناطيسية ساكنة: الإبر، البرادة، الحقل الأرضي (نمط موحّد معتمد).
/// حقل أرضي (شمال = −y) + مغناطيس ثنائي القطب: needleAng = atan2(by, −bx)
/// · B ∝ N·I·μr (قلب حديدي ×5.5) · إبرة الميل tanα = Bعمودي/Bأفقي.
/// تحدّي: قرّب المغناطيس ثم ابعده — عودة الإبر للشمال الجغرافي (+١٠) بمفتاح 'mstat'.
class MstatScreen extends StatefulWidget {
  const MstatScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<MstatScreen> createState() => _MstatScreenState();
}

class _MstatScreenState extends State<MstatScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-mstat.html المعتمد) ──
  int mode = 1; // 1 علبة الإبر · 2 البرادة والقلب · 3 إبرة الميل
  bool near = false, core = false;
  int pol = 1;
  double i = 3, lat = 45;
  double t = 0;
  double magX = 250, magYT = 30;
  bool won = false, started = false;
  bool sawDeflect = false;

  double get bClip => i * (core ? 5.5 : 1);
  int get clipCount => (bClip * 1.6).round();

  double needleAng(double nx, double ny) {
    final dx = nx - magX, dy = ny - magYT;
    final r2 = dx * dx + dy * dy + 4000;
    final m = near ? 1.0 : 0.0;
    final bx = m * pol * 9000 * (-dy / r2);
    final by = m * pol * 9000 * (dx / r2);
    return math.atan2(by + 0, -bx);
  }

  double get maxDeflection {
    var mx = 0.0;
    for (final gy in const [0.0, 1.0, 2.0]) {
      for (final gx in const [0.0, 1.0, 2.0, 3.0, 4.0]) {
        final a = needleAng(160 + gx * 130, 175 + gy * 55);
        final d = (a - 0).abs() > math.pi ? 2 * math.pi - (a - 0).abs() : (a - 0).abs();
        if (d > mx) mx = d;
      }
    }
    return mx;
  }

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
        _data.labChallengeDays['mstat'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step(double dt) {
    t += dt;
    final ty = near ? 100.0 : 30.0;
    magYT += (ty - magYT) * (dt * 6).clamp(0.0, 1.0);
    final defl = maxDeflection;
    if (near && defl > 0.3) sawDeflect = true;
    if (sawDeflect) started = true;
    if (mode == 1 && sawDeflect && !near && defl < 0.05) {
      if (!won && !_challengeDoneToday) {
        won = true;
        HapticFeedback.mediumImpact();
        _recordChallenge();
      }
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
        'mstat': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'mstat'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      near = false;
      pol = 1;
      i = 3;
      core = false;
      lat = 45;
      sawDeflect = false;
      won = false;
    });
  }

  String get statusText {
    if (mode == 1) {
      return near
          ? 'المغناطيس قريب — الإبر تلزم محصلته (${pol > 0 ? 'N' : 'S'} قربها)'
          : 'الحقل الأرضي فقط — الكل شمالاً';
    }
    if (mode == 2) {
      return 'ملف: N=٢٠ لفة${core ? ' · قلب حديدي' : ' · هواء'} · B ∝ N·I·μr = ${toAr(bClip.toStringAsFixed(1))}';
    }
    return 'إبرة الميل — زاوية الميل α = ${toAr(lat.round())}° · tanα = Bعمودي/Bأفقي';
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    const benchTop = 352.0;
    paintSpace(c, size, stars, groundTop: benchTop);
    paintWalnutTable(c, size, benchTop + 1);
    final w = size.width;
    if (mode == 1) {
      // علبة الإبر: 5×4 شبكة إبر داخل إطار خشبي
      final bx0 = w * 0.14, by0 = 150.0;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx0 - 18, by0 - 20, 700 * w / 960, 220),
              const Radius.circular(8)),
          Paint()..color = const Color(0xFF232019));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx0 - 18, by0 - 20, 700 * w / 960, 220),
              const Radius.circular(8)),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF4A4034)
            ..strokeWidth = 3);
      _arabic(c, 'شمال ↑', Offset(bx0 - 34, by0 - 6), 11,
          const Color.fromRGBO(156, 195, 223, 0.7));
      for (var gy = 0; gy < 4; gy++) {
        for (var gx = 0; gx < 5; gx++) {
          final nx = bx0 + 20 + gx * 130.0 * w / 960;
          final ny = by0 + 12 + gy * 55.0;
          final a = needleAng(nx, ny);
          c.drawCircle(Offset(nx, ny), 3,
              Paint()..color = const Color(0xFF4A4540));
          final u = Offset(math.sin(a), -math.cos(a));
          c.drawLine(
              Offset(nx - u.dx * 17, ny - u.dy * 17),
              Offset(nx + u.dx * 17, ny + u.dy * 17),
              Paint()
                ..color = const Color(0xFFB23A34)
                ..strokeWidth = 2.4
                ..strokeCap = StrokeCap.round);
          c.drawCircle(
              Offset(nx + u.dx * 17, ny + u.dy * 17), 3.2,
              Paint()..color = const Color(0xFFB23A34));
        }
      }
      // المغناطيس القلّاب (ينزلق قرب/بعُد)
      final my = magYT;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(magX - 16, my - 60, 32, 120),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFFB23A34));
      c.drawRect(
          Rect.fromLTWH(magX - 16, my, 32, 60),
          Paint()..color = const Color(0xFF3E6FA8));
      _arabic(c, 'N', Offset(magX, my - 48), 13, const Color(0xFFFFD9CE));
      _arabic(c, 'S', Offset(magX, my + 48), 13, const Color(0xFFCFE3F7));
    } else if (mode == 2) {
      // ملف كهرومغناطيسي + برادة
      final cx0 = w * 0.32, cy0 = 225.0;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx0 - 34, cy0 - 24, 68, 130),
              const Radius.circular(6)),
          Paint()
            ..color = core ? const Color(0xFF8A8F94) : const Color(0x688A8F94));
      for (var k = 0; k < 8; k++) {
        c.drawOval(
            Rect.fromCenter(
                center: Offset(cx0, cy0 - 18 + k * 17), width: 110, height: 13),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFFC89A5A)
              ..strokeWidth = 3.4);
      }
      // مشابك البرادة المرفوعة حول القطبين
      final clips = mode == 2 ? clipCount : 0;
      for (var k = 0; k < clips && k < 26; k++) {
        final side = k.isEven ? -1.0 : 1.0;
        final ph = (k ~/ 2) / 13;
        c.drawLine(
            Offset(cx0 + side * (52 + ph * 66), cy0 - 30 + ph * 120),
            Offset(cx0 + side * (58 + ph * 74), cy0 - 44 + ph * 126),
            Paint()
              ..color = const Color.fromRGBO(140, 140, 135, 0.75)
              ..strokeWidth = 1.6);
      }
      // دائرة التغذية
      c.drawCircle(Offset(cx0 + 150, cy0 + 40), 26,
          Paint()..color = const Color(0xFF232320));
      _arabic(c, 'I = ${toAr(i.toStringAsFixed(1))}A', Offset(cx0 + 150, cy0 + 40),
          11.5, const Color(0xFFE8E2D0));
      c.drawLine(Offset(cx0 + 34, cy0 + 46), Offset(cx0 + 124, cy0 + 40),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.5);
      c.drawLine(Offset(cx0 + 34, cy0 - 52), Offset(cx0 + 150, cy0 + 14),
          Paint()..color = const Color(0xFF8F8F8A)..strokeWidth = 2.5);
    } else {
      // إبرة الميل: منقلة رأسية بإبرة مائلة بزاوية lat
      final px = w * 0.5, py = 260.0;
      c.drawArc(Rect.fromCircle(center: Offset(px, py), radius: 110),
          -math.pi / 2 - lat * math.pi / 180, 2 * lat * math.pi / 180, false,
          Paint()
            ..color = const Color.fromRGBO(240, 150, 74, 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      for (var a = 0; a <= 90; a += 15) {
        final r1 = math.pi / 2 - a * math.pi / 180;
        c.drawLine(
            Offset(px - math.cos(r1) * 96, py - math.sin(r1) * 96),
            Offset(px - math.cos(r1) * 110, py - math.sin(r1) * 110),
            Paint()
              ..color = const Color.fromRGBO(205, 215, 230, 0.5)
              ..strokeWidth = 1.4);
      }
      final th = lat * math.pi / 180;
      c.drawLine(
          Offset(px + math.sin(th) * 12, py + math.cos(th) * 12),
          Offset(px - math.sin(th) * 86, py - math.cos(th) * 86),
          Paint()
            ..color = const Color(0xFFB23A34)
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round);
      c.drawCircle(Offset(px, py), 6, Paint()..color = const Color(0xFF4A4540));
      _arabic(c, 'α = ${toAr(lat.round())}°', Offset(px + 60, py - 80), 14,
          const Color(0xFFF0964A));
    }
    _arabic(c, statusText, Offset(w / 2, 26), 13,
        mode == 1 && near ? const Color(0xFFF0964A) : const Color(0xFFE8E2D0));
    if (mode == 2) {
      _arabic(c, 'مشابك مرفوعة: ${toAr(clipCount)}', Offset(w / 2, 48), 12,
          const Color(0xFF9CC3DF));
    }
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    if (mode == 1) {
      // قاعدة + إبر رأسية بدوران needleAng لكل موضع
      for (var gy = 0; gy < 4; gy++) {
        for (var gx = 0; gx < 5; gx++) {
          final wx = -180.0 + gx * 90;
          final wz = -90.0 + gy * 60;
          final pr = cam.project(P3(wx, 0, wz), size);
          final a = needleAng(pr.x, pr.y);
          final u = Offset(math.sin(a), -math.cos(a));
          c.drawLine(
              Offset(pr.x - u.dx * 14, pr.y - u.dy * 14),
              Offset(pr.x + u.dx * 14, pr.y + u.dy * 14),
              Paint()
                ..color = const Color(0xFFB23A34)
                ..strokeWidth = 2.2
                ..strokeCap = StrokeCap.round);
        }
      }
      // المغناطيس بارتفاع متغير magYT
      final h = (magYT - 30) * 0.9 + 40;
      line3(c, cam, size, P3(-24, h, 0), P3(24, h, 0), const Color(0xFFB23A34), 14);
      line3(c, cam, size, P3(24, h, 0), P3(52, h, 0), const Color(0xFF3E6FA8), 14);
    } else if (mode == 2) {
      // لفات الملف كحلقات رأسية + قلب
      for (var k = 0; k < 8; k++) {
        final xx = -120.0 + k * 30;
        ring3(c, cam, size, 0, 44, const Color(0xB3C89A5A), 2.4);
        line3(c, cam, size, P3(xx, 0, -44), P3(xx, 0, 44),
            const Color.fromRGBO(200, 154, 90, 0.35), 1.4);
      }
      c.drawRect(
          Rect.fromLTWH(size.width / 2 - 3, size.height * 0.35, 6, 60),
          Paint()..color = core ? const Color(0xFF8A8F94) : const Color(0x668A8F94));
      final clips = clipCount;
      for (var k = 0; k < clips && k < 18; k++) {
        final a = k * math.pi / 9;
        final p = cam.project(P3(math.cos(a) * 120, -6, math.sin(a) * 120), size);
        c.drawCircle(Offset(p.x, p.y), 1.8,
            Paint()..color = const Color.fromRGBO(140, 140, 135, 0.7));
      }
    } else {
      // إبرة الميل 3D: عمود مائل
      final th = lat * math.pi / 180;
      line3(c, cam, size, const P3(0, 60, 0),
          P3(-math.sin(th) * 150, 60 - math.cos(th) * 150, 0),
          const Color(0xFFB23A34), 4);
      ring3(c, cam, size, 0, 150, const Color.fromRGBO(240, 150, 74, 0.3), 1.6);
    }
    _arabic(c, statusText, Offset(size.width / 2, 26), 12,
        const Color(0xFFE8E2D0));
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
      appBar: AppBar(title: const Text('المختبر: مغناطيسية ساكنة — الإبر والبرادة')),
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
                painter: _MstatPainter(this),
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
                      'U2-1 · علبة الإبر',
                      'U2-2 · البرادة والقلب',
                      'U2-3 · إبرة الميل',
                    ][m - 1]),
                    selected: mode == m,
                    onSelected: (_) => setState(() => mode = m),
                  ),
              ]),
              const SizedBox(height: 6),
              if (mode == 2)
                LabSlider(
                    label: 'التيار I',
                    value: i,
                    min: 0, max: 6, divisions: 12,
                    display: '${toAr(i.toStringAsFixed(1))}A',
                    onChanged: (x) => setState(() => i = x)),
              if (mode == 3)
                LabSlider(
                    label: 'زاوية الميل lat',
                    value: lat,
                    min: 0, max: 90, divisions: 18,
                    display: '${toAr(lat.round())}°',
                    onChanged: (x) => setState(() => lat = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => near = !near),
                    child: Text(near ? '🧲 ابعد المغناطيس' : '🧲 قرّب المغناطيس')),
                OutlinedButton(
                    onPressed: () => setState(() => pol = -pol),
                    child: const Text('⇄ قلب القطبية')),
                if (mode == 2)
                  OutlinedButton(
                      onPressed: () => setState(() => core = !core),
                      child: Text(core
                          ? '🧱 أخرج القلب'
                          : '🧱 أدخل القلب الحديدي')),
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
                    'أدخلنا قلباً حديدياً داخل الملف (نفس I) — ماذا يحدث لحقل الملف؟',
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
                          'تضعف — الحديد يعيق',
                          'تتضاعف أضعافاً — النواة تتركّز',
                          'لا تتغير',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — μr للحديد آلاف الأمثال: B يتضاعف (٥٫٥× بالنموذج)'
                        : '✘ الحديد نواة مغناطيسية: μr كبير ⇒ B يتركّز ويتضاعف',
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
              _chip(statusText),
              if (!_challengeDoneToday)
                _chip(
                    won ? '🎯 منجز!' : '🎯 قرّب المغناطيس ثم ابعده — عودة الإبر للشمال',
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
              _explainLine('الإبرة تستقر على محصلة حقلين: الأرضي (شمالاً) وحقل المغناطيس ثنائي القطب — يقربها يغلبها.'),
              _explainLine('بإبعاده تعود للشمال: الحقل الأرضي أضعف لكنه الحاكم بغياب المنافس — منحى الاستقرار مرئي.'),
              _explainLine('قلب القطبية يقلب المحصلة: نفس القرب بـS قربها يعكس الإبر ١٨٠°.'),
              _explainLine('الملف: B ∝ N·I·μr — القلب الحديدي يتركّز الخطوط ويرفع B أضعافاً، والبرادة تكشفه مشابكاً.'),
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

class _MstatPainter extends CustomPainter {
  _MstatPainter(this.st);
  final _MstatScreenState st;

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
          '🔒 يُفتح الشرح بعد أول تقريب وابتعاد — راقب الإبر تعود شمالاً!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
