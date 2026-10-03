import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U2-8/9 السكتان المتدحرجتان + الإطار المستطيل (نمط موحّد معتمد).
/// وضع ١: تيار متعاكس بسكتتين ⇒ F = I·B·L (L=0.1m) قوتان متعاكستان وتدحرج r=v·t/R
/// · وضع ٢: إطار بمحور فتل ينحرف بزاوية اتزان φ = N·I·A·B·(±)/K (K=0.02, A=0.006, J=0.5)
/// · تحدّي: أظهر الحركتين المتعاكستين ثم عكسهما بقلب B (+١٠) بمفتاح 'fcoil'.
class FcoilScreen extends StatefulWidget {
  const FcoilScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<FcoilScreen> createState() => _FcoilScreenState();
}

class _FcoilScreenState extends State<FcoilScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-fcoil.html المعتمد) ──
  int mode = 1; // 1 السكتان · 2 الإطار
  double i = 4, b = 0.8;
  double n = 10;
  int iD = 1, bD = 1;
  bool on = false;
  double t = 0;
  bool won = false, started = false;
  static const double lsk = 0.1; // طول السكتة الفعال m
  double x1 = 0, v1 = 0, r1 = 0;
  double x2 = 0, v2 = 0, r2 = 0;
  double wsum = 0;
  double phA = 0, phV = 0;
  bool extSeen = false, sepSeen = false;
  static const double kt = 0.02, afr = 0.006;

  double get fSk => on ? i * b * lsk * iD * bD : 0.0;
  double get phiEq => on ? n * i * afr * b * iD * bD / kt : 0.0;

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
        _data.labChallengeDays['fcoil'] == dateKeyOf(DateTime.now());
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
      final f = fSk;
      if (mode == 1) {
        final a = f * 180; // قوة بمقياس بكسلي
        v1 += a * st;
        x1 += v1 * st;
        r1 += v1 * st / 9;
        v2 -= a * st;
        x2 -= v2 * st;
        r2 -= v2 * st / 9;
        x1 = x1.clamp(-150.0, 150.0);
        x2 = x2.clamp(-150.0, 150.0);
        wsum += (f * (v1.abs() + v2.abs()) * 0.5).abs() * st * 0.1;
        if (a.abs() > 1) {
          if (a > 0) {
            extSeen = true;
          } else {
            sepSeen = true;
          }
        }
        if (extSeen && sepSeen && !won && !_challengeDoneToday) {
          won = true;
          HapticFeedback.mediumImpact();
          _recordChallenge();
        }
      } else {
        final a = (phiEq - phA) * 22 - 6 * phV;
        phV += a * st;
        phA += phV * st;
        if (phiEq.abs() > 0.05 && !started) started = true;
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
        'fcoil': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'fcoil'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      on = false;
      x1 = 0;
      v1 = 0;
      r1 = 0;
      x2 = 0;
      v2 = 0;
      r2 = 0;
      wsum = 0;
      phA = 0;
      phV = 0;
      extSeen = false;
      sepSeen = false;
      won = false;
    });
  }

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    final w = size.width;
    if (mode == 1) {
      // سكتتان أفقيتان + قطبا مغناطيس حولهما
      const benchTop = 340.0;
      paintSpace(c, size, stars, groundTop: benchTop);
      paintWalnutTable(c, size, benchTop + 1);
      final cy = 215.0;
      final cx0 = w * 0.5;
      c.drawLine(Offset(cx0 - 240, cy - 26), Offset(cx0 + 240, cy - 26),
          Paint()
            ..color = const Color.fromRGBO(203, 183, 158, 0.85)
            ..strokeWidth = 5);
      c.drawLine(Offset(cx0 - 240, cy + 26), Offset(cx0 + 240, cy + 26),
          Paint()
            ..color = const Color.fromRGBO(203, 183, 158, 0.85)
            ..strokeWidth = 5);
      // قطبا N/S أعلى وأسفل
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx0 - 130, cy - 120, 260, 46),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFFB23A34));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx0 - 130, cy + 74, 260, 46),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFF3E6FA8));
      _arabic(c, 'N', Offset(cx0, cy - 97), 14, const Color(0xFFFFD9CE));
      _arabic(c, 'S', Offset(cx0, cy + 97), 14, const Color(0xFFCFE3F7));
      // السكتتان (أسطوانتان) تدحرجان بموضعي x1/x2
      _paintRod(c, cx0, cy, x1, r1, const Color(0xFFC89A5A));
      _paintRod(c, cx0, cy, x2, r2, const Color(0xFF9A9A94));
      _arabic(
          c,
          'F لكل سكتة = ${toAr(fSk.abs().toStringAsFixed(3))}N${fSk != 0 ? (fSk > 0 ? ' (تباعد)' : ' (تقارب)') : ''}',
          Offset(w / 2, 26),
          13,
          const Color(0xFFE8E2D0));
      _arabic(c, 'العمل المبذول W = ${toAr(wsum.toStringAsFixed(3))}J',
          Offset(w / 2, 48), 12.5, const Color(0xFF9CD9BC));
      _arabic(c, 'I = ${toAr(i.toStringAsFixed(1))}A · B = ${toAr(b.toStringAsFixed(1))}T · L = ١٠cm',
          Offset(w / 2, size.height - 16), 12.5,
          const Color.fromRGBO(156, 195, 223, 0.85));
    } else {
      // الإطار المستطيل بين قطبين بمحور فتل
      const benchTop = 340.0;
      paintSpace(c, size, stars, groundTop: benchTop);
      paintWalnutTable(c, size, benchTop + 1);
      final cx0 = w * 0.5, cy = 210.0;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx0 - 190, cy - 130, 130, 260),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFFB23A34));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx0 + 60, cy - 130, 130, 260),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFF3E6FA8));
      _arabic(c, 'N', Offset(cx0 - 125, cy), 15, const Color(0xFFFFD9CE));
      _arabic(c, 'S', Offset(cx0 + 125, cy), 15, const Color(0xFFCFE3F7));
      // سلك الفتل + الإطار المنحرف بphA
      c.drawLine(Offset(cx0, cy - 190), Offset(cx0, cy - 70),
          Paint()
            ..color = const Color(0xFFC9C2A8)
            ..strokeWidth = 2.4);
      final skew = (phA * 180 / math.pi).clamp(-60.0, 60.0);
      final h = 95.0;
      final frame = Path()
        ..moveTo(cx0 - skew * 0.8 - 46, cy - 70)
        ..lineTo(cx0 - skew * 0.8 + 46, cy - 70)
        ..lineTo(cx0 - skew * 1.6 + 46, cy + 70)
        ..lineTo(cx0 - skew * 1.6 - 46, cy + 70)
        ..close();
      c.drawPath(
          frame,
          Paint()
            ..color = const Color.fromRGBO(200, 154, 90, 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      _arabic(
          c,
          'φ = ${toAr((phA * 180 / math.pi).toStringAsFixed(1))}° (اتزان ${toAr((phiEq * 180 / math.pi).toStringAsFixed(1))}°)',
          Offset(w / 2, 26),
          13,
          const Color(0xFFF0964A));
      _arabic(
          c,
          'φₐₜ = N·I·A·B/K · K = ٠٫٠٢N·m/rad · N = ${toAr(n.round())}',
          Offset(w / 2, 48),
          12.5,
          const Color(0xFF9CD9BC));
      _arabic(c, 'I = ${toAr(i.toStringAsFixed(1))}A · B = ${toAr(b.toStringAsFixed(1))}T',
          Offset(w / 2, size.height - 16), 12.5,
          const Color.fromRGBO(156, 195, 223, 0.85));
    }
  }

  // ══ منظور 3D ══
  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    if (mode == 1) {
      line3(c, cam, size, const P3(-240, -40, -30), const P3(240, -40, -30),
          const Color.fromRGBO(203, 183, 158, 0.85), 3);
      line3(c, cam, size, const P3(-240, -40, 30), const P3(240, -40, 30),
          const Color.fromRGBO(203, 183, 158, 0.85), 3);
      _paintRod3D(c, size, x1, const Color(0xFFC89A5A), -30);
      _paintRod3D(c, size, x2, const Color(0xFF9A9A94), 30);
      line3(c, cam, size, const P3(-130, 90, 0), const P3(130, 90, 0),
          const Color(0xFFB23A34), 20);
      line3(c, cam, size, const P3(-130, -120, 0), const P3(130, -120, 0),
          const Color(0xFF3E6FA8), 20);
    } else {
      ring3(c, cam, size, 0, 170, const Color.fromRGBO(240, 150, 74, 0.3), 1.6);
      // إطار مائل بphA حول محور رأسي
      final a = phA.clamp(-1.0, 1.0);
      final cs = math.cos(a), sn = math.sin(a);
      stroke3(c, cam, size, [
        P3(-70 * cs, 80, 70 * sn),
        P3(70 * cs, 80, -70 * sn),
        P3(70 * cs, -80, -70 * sn),
        P3(-70 * cs, -80, 70 * sn),
      ], const Color(0xFFC89A5A), 4, close: true);
      line3(c, cam, size, const P3(0, 200, 0), const P3(0, 80, 0),
          const Color(0xFFC9C2A8), 2);
      line3(c, cam, size, const P3(-220, 0, 0), const P3(-90, 0, 0),
          const Color(0xFFB23A34), 22);
      line3(c, cam, size, const P3(90, 0, 0), const P3(220, 0, 0),
          const Color(0xFF3E6FA8), 22);
    }
    _arabic(c, 'اسحب لتدوير الكاميرا',
        Offset(size.width / 2, size.height - 14), 12,
        const Color.fromRGBO(205, 198, 182, 0.5));
    _arabic(
        c,
        mode == 1
            ? 'F = ${toAr(fSk.abs().toStringAsFixed(3))}N · W = ${toAr(wsum.toStringAsFixed(3))}J'
            : 'φ = ${toAr((phA * 180 / math.pi).toStringAsFixed(1))}° · اتزان ${toAr((phiEq * 180 / math.pi).toStringAsFixed(1))}°',
        Offset(size.width / 2, 26),
        12,
        const Color(0xFFE8E2D0));
  }

  void _paintRod(Canvas c, double cx0, double cy, double x, double rot,
      Color col) {
    final px = cx0 + x;
    c.save();
    c.translate(px, cy);
    c.rotate(rot);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-60, -11, 120, 22), const Radius.circular(10)),
        Paint()..color = col);
    c.drawLine(Offset(-52, 0), Offset(52, 0),
        Paint()..color = const Color(0x66000000)..strokeWidth = 2);
    c.restore();
    if (x.abs() > 2) {
      final d = x.sign;
      c.drawLine(
          Offset(px + d * 70, cy - 30),
          Offset(px + d * 86, cy - 30),
          Paint()
            ..color = const Color.fromRGBO(240, 150, 74, 0.9)
            ..strokeWidth = 3);
    }
  }

  void _paintRod3D(Canvas c, Size size, double x, Color col, double z) {
    final p0 = cam.project(P3(x * 1.4 - 55, -26, z), size);
    final p1 = cam.project(P3(x * 1.4 + 55, -26, z), size);
    c.drawLine(Offset(p0.x, p0.y), Offset(p1.x, p1.y),
        Paint()..color = col..strokeWidth = 9);
    final rp = cam.project(P3(x * 1.4, -34, z), size);
    c.drawCircle(Offset(rp.x, rp.y), 3.5,
        Paint()..color = const Color(0x66000000));
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
      appBar: AppBar(
          title: const Text('المختبر: السكتان المتدحرجتان والإطار المستطيل')),
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
                painter: _FcoilPainter(this),
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
                    label: const Text('U2-8 · السكتان المتدحرجتان'),
                    selected: mode == 1,
                    onSelected: (_) => setState(() => mode = 1)),
                ChoiceChip(
                    label: const Text('U2-9 · الإطار بسلك فتل'),
                    selected: mode == 2,
                    onSelected: (_) => setState(() => mode = 2)),
              ]),
              const SizedBox(height: 6),
              LabSlider(
                  label: 'التيار I',
                  value: i,
                  min: 0, max: 8, divisions: 16,
                  display: '${toAr(i.toStringAsFixed(1))}A',
                  onChanged: (x) => setState(() => i = x)),
              LabSlider(
                  label: 'الحقل B',
                  value: b,
                  min: 0.2, max: 1.2, divisions: 10,
                  display: '${toAr(b.toStringAsFixed(1))}T',
                  onChanged: (x) => setState(() => b = x)),
              if (mode == 2)
                LabSlider(
                    label: 'لفات الإطار N',
                    value: n,
                    min: 5, max: 20, divisions: 15,
                    display: '${toAr(n.round())}',
                    onChanged: (x) => setState(() => n = x)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
                  children: [
                ViewToggle(
                    view3d: view3d,
                    onChanged: (x) => setState(() => view3d = x)),
                OutlinedButton(
                    onPressed: () => setState(() => on = !on),
                    child: Text(on ? '⚡ فصل التيار' : '⚡ وصل التيار')),
                OutlinedButton(
                    onPressed: () => setState(() => iD = -iD),
                    child: const Text('⇄ قلب I')),
                OutlinedButton(
                    onPressed: () => setState(() => bD = -bD),
                    child: const Text('⇄ قلب B')),
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
                    'سكتتان متجاورتان، تيارهما في اتجاهين متعاكسين — ماذا يحدث؟',
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
                          'بنفس الاتجاه',
                          'باتجاهين متعاكسين — تتباعدان',
                          'لا تتحركان',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — تيارات متعاكسة تتنافر: F على كل سكتة بجهة معاكسة'
                        : '✘ F = BIL بيد يمنى: عكس التيار ⇒ عكس القوة ⇒ تتباعدان',
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
              _chip(mode == 1
                  ? 'F لكل سكتة = ${toAr(fSk.abs().toStringAsFixed(3))}N'
                  : 'φ = ${toAr((phA * 180 / math.pi).toStringAsFixed(1))}°'),
              if (mode == 1) _chip('W = ${toAr(wsum.toStringAsFixed(3))}J'),
              if (!_challengeDoneToday)
                _chip(
                    won
                        ? '🎯 منجز!'
                        : '🎯 أظهر الحركتين المتعاكستين ثم عكسهما بقلب B',
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
                child: Text('F = B·I·L · τ = N·I·A·B·sinφ — الاتزان عند τمغناطيسي = τفتل',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 15)),
              ),
              const SizedBox(height: 6),
              _explainLine('تياران متعاكسان تتباعدان ومتساويان تتجاذبان — القوة تنعكس بقلب I أو B وحده.'),
              _explainLine('عمل القوة يتحول طاقة حركة تدحرج: W = ΣF·x — راقب العداد أثناء الدفع.'),
              _explainLine('الإطار: العزم المغناطيسي N·I·A·B·sinφ يوازنه عزم الفتل K·φ ⇒ انحراف قياس ثابت (أساس الجلفانومتر).'),
              _explainLine('مضاعفة N أو I أو B تضاعف الانحراف — لهذا نقرأ التيار بإنحراف الإبرة.'),
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

class _FcoilPainter extends CustomPainter {
  _FcoilPainter(this.st);
  final _FcoilScreenState st;

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
          '🔒 يُفتح الشرح عند وصل التيار أول مرة — راقب السكتتين!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
