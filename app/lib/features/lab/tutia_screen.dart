import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/unified_lab_core.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٦ — U4-3 صفيحة التوتياء: الفعل الكهرضوئي والزجاج يحجب UV (نمط موحّد معتمد).
/// effUV = (مصباح UV && بلا زجاج) · q تفريغ بمعدل 0.030/ث للسالب و0.18× للموجب
/// · تحدّي: تفريغ تام للشحنة السالبة (+١٠) بمفتاح 'tutia'.
/// منظور واقعي (كهرسكوب + مصباح + زجاج) + منظور 3D بنفس الحالة.
class TutiaScreen extends StatefulWidget {
  const TutiaScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<TutiaScreen> createState() => _TutiaScreenState();
}

class _TutiaScreenState extends State<TutiaScreen>
    with SingleTickerProviderStateMixin {
  // ── الفيزياء (نسخ حرفي من flash-tutia.html المعتمد) ──
  int charge = -1; // −1 سالب · 1 موجب · 0 متعادل
  double q = 0.0; // شحنة الأوراق 0..1 (تتفتح)
  int lamp = 0; // 0 مطفأ · 1 UV · 2 ضوء أبيض
  bool glass = false;
  double t = 0;
  bool won = false, started = false;

  int get effUV => (lamp == 1 && !glass) ? 1 : 0;

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
        _data.labChallengeDays['tutia'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step(double st) {
    t += st;
    if (charge != 0) {
      final rate = effUV * 0.030 * (charge < 0 ? 1.0 : 0.18);
      q = math.max(0, q - rate);
      if (charge < 0 && effUV > 0 && !started) started = true;
      if (charge < 0 && q <= 0.001 && !won && !_challengeDoneToday) {
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
        'tutia': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'tutia'},
    );
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _reset() {
    setState(() {
      charge = -1;
      q = 0.0;
      lamp = 0;
      glass = false;
      won = false;
      started = false;
    });
  }

  String get lampLabel => lamp == 0
      ? 'مصباح UV: OFF'
      : lamp == 1
          ? 'مصباح UV: ON'
          : 'مصباح ضوئي أبيض';

  // ══ الرسّام الواقعي ══
  void _paintReal(Canvas c, Size size) {
    final w = size.width, h = size.height;
    // خلفية غرفة داكنة
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF15130F));
    // الكهرسكوب: قارورة + صفيحة خارصين + أوراق
    final bx = w * 0.30, by = h * 0.62;
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx - 52, by, 104, 78), const Radius.circular(8)),
        Paint()..color = const Color(0xFF232019));
    // قارورة زجاجية
    c.drawCircle(
        Offset(bx, by - 26),
        46,
        Paint()
          ..color = const Color.fromRGBO(190, 215, 235, 0.10)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2));
    c.drawCircle(
        Offset(bx, by - 26),
        46,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(180, 210, 235, 0.45)
          ..strokeWidth = 2.2);
    // صفيحة الخارصين داخل القارورة
    c.drawRect(
        Rect.fromLTWH(bx - 22, by - 62, 44, 8),
        Paint()..color = const Color(0xFFB8BEC4));
    c.drawLine(
        Offset(bx, by - 54),
        Offset(bx, by + 18),
        Paint()
          ..color = const Color(0xFF8A8F94)
          ..strokeWidth = 2.4);
    // الأوراق الذهبية — تفتح بحسب q
    final spread = q * 0.85; // راديان نصف زاوية
    for (final sgn in [-1.0, 1.0]) {
      c.drawLine(
          Offset(bx, by + 18),
          Offset(bx + sgn * math.sin(spread) * 34,
              by + 18 + 30 * (1 - spread * 0.25)),
          Paint()
            ..color = const Color(0xFFD9B45A)
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round);
    }
    _arabic(
        c,
        'الأوراق: ${toAr((q * 100).round())}٪',
        Offset(bx, by + 96),
        12.5,
        const Color(0xFFE8E2D0));
    // المصباح
    final lx = w * 0.70;
    final lampCol = lamp == 1
        ? const Color(0xF2483E7D)
        : lamp == 2
            ? const Color(0xF27A6B48)
            : const Color(0xF22D2D2A);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(lx - 46, by - 96, 58, 72),
            const Radius.circular(6)),
        Paint()..color = lampCol);
    if (lamp > 0) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(lx + 12, by - 90, 10, 60),
              const Radius.circular(3)),
          Paint()..color = lamp == 1
              ? const Color(0x80AA8CFF)
              : const Color(0x80FFF0BE));
    }
    _arabic(c, lampLabel, Offset(lx, by - 112), 12,
        const Color(0xFFE8E2D0));
    // الزجاج الواقي
    if (glass) {
      c.drawRect(
          Rect.fromLTWH(w * 0.52, by - 120, 14, 150),
          Paint()..color = const Color.fromRGBO(180, 220, 255, 0.25));
      c.drawRect(
          Rect.fromLTWH(w * 0.52, by - 120, 14, 150),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color.fromRGBO(200, 230, 255, 0.55)
            ..strokeWidth = 1.4);
      _arabic(c, '🪟', Offset(w * 0.52 + 7, by - 132), 14,
          const Color(0xFFCFE3F7));
    }
    // أشعة المصباح نحو الصفيحة
    if (lamp > 0) {
      final col = lamp == 1
          ? const Color.fromRGBO(170, 140, 255, 0.6)
          : const Color.fromRGBO(255, 240, 190, 0.6);
      final blocked = glass && lamp == 1;
      final endX = blocked ? w * 0.52 : bx + 30;
      for (var k = -1; k <= 1; k++) {
        c.drawLine(
            Offset(lx + 22, by - 60 + k * 16),
            Offset(endX, by - 40 + k * 14),
            Paint()
              ..color = blocked
                  ? const Color.fromRGBO(200, 230, 255, 0.55)
                  : col
              ..strokeWidth = 1.6);
        if (blocked) {
          c.drawCircle(Offset(endX, by - 40 + k * 14), 2.4,
              Paint()..color = const Color.fromRGBO(200, 230, 255, 0.5));
        }
      }
    }
    // إلكترونات متطايرة من الصفيحة عند التفريغ
    if (effUV > 0 && charge < 0 && q > 0) {
      for (var k = 0; k < 6; k++) {
        final ph = (t * 1.3 + k / 6) % 1;
        c.drawCircle(
            Offset(bx + 30 + ph * 60, by - 46 + math.sin(k * 2.4) * 16 * (1 - ph)),
            2.2,
            Paint()
                ..color = Color.fromRGBO(200, 230, 255, (1 - ph).toDouble()));
      }
    }
    _arabic(
        c,
        'اللوح: ${charge == -1 ? 'سالب' : charge == 1 ? 'موجب' : 'متعادل'} · الشحنة: ${toAr((q * 100).round())}٪',
        Offset(w / 2, 26),
        13,
        const Color(0xFFE8E2D0));
    _arabic(
        c,
        effUV > 0 && charge < 0
            ? 'تفريغ ضوئي! UV ينتزع الإلكترونات'
            : lamp == 1 && glass
                ? 'الزجاج يمتص UV — لا تفريغ'
                : 'نشّط المصباح وراقب الأوراق',
        Offset(w / 2, 48),
        12.5,
        effUV > 0 && charge < 0
            ? const Color(0xFFF0964A)
            : const Color.fromRGBO(232, 226, 208, 0.8));
  }

  // ══ منظور 3D ══
  void _fillPoly3(Canvas c, Size size, List<P3> pts, Color col) {
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final qq = cam.project(pts[i], size);
      i == 0 ? p.moveTo(qq.x, qq.y) : p.lineTo(qq.x, qq.y);
    }
    p.close();
    c.drawPath(p, Paint()..color = col);
  }

  void _paint3D(Canvas c, Size size) {
    paintSpace(c, size, stars);
    paintGrid3(c, cam, size);
    const lx = -195.0;
    // اللوح المعدني (صفيحة التوتياء)
    _fillPoly3(
        c,
        size,
        const [
          P3(-20, -30, -26),
          P3(150, -30, -26),
          P3(150, 140, -26),
          P3(-20, 140, -26),
        ],
        const Color(0xD9969BA0));
    // قاعدة الكهرسكوب
    _fillPoly3(
        c,
        size,
        const [
          P3(-66, -148, -48),
          P3(66, -148, -48),
          P3(66, -66, -48),
          P3(-66, -66, -48),
        ],
        const Color(0xEB23201C));
    // المصباح
    final lampCol = lamp == 1
        ? const Color(0xF2483E7D)
        : lamp == 2
            ? const Color(0xF27A6B48)
            : const Color(0xF22D2D2A);
    _fillPoly3(
        c,
        size,
        const [
          P3(lx - 46, 44, -42),
          P3(lx + 12, 44, -42),
          P3(lx + 12, 116, -42),
          P3(lx - 46, 116, -42),
        ],
        lampCol);
    _fillPoly3(
        c,
        size,
        const [
          P3(lx + 12, 50, -36),
          P3(lx + 22, 50, -36),
          P3(lx + 22, 110, -36),
          P3(lx + 12, 110, -36),
        ],
        lamp == 1
            ? const Color(0x80AA8CFF)
            : lamp == 2
                ? const Color(0x80FFF0BE)
                : const Color(0x80464642));
    // الزجاج
    if (glass) {
      _fillPoly3(
          c,
          size,
          const [
            P3(-104, 26, -64),
            P3(-92, 26, -64),
            P3(-92, 150, -64),
            P3(-104, 150, -64),
          ],
          const Color(0x40B4DCFF));
    }
    // الأشعة
    if (lamp > 0) {
      final col = lamp == 1 ? '170,140,255' : '255,240,190';
      final blocked = glass && lamp == 1;
      final rr = col.split(',');
      for (var k = 0; k < 4; k++) {
        final z0 = -34.0 + k * 20;
        if (blocked) {
          line3(c, cam, size, P3(lx + 22, 92, z0), P3(-98, 80, z0),
              Color.fromRGBO(int.parse(rr[0]), int.parse(rr[1]),
                  int.parse(rr[2]), 0.55),
              1.4);
          final gp = cam.project(const P3(-98, 80, 0), size);
          c.drawCircle(Offset(gp.x, gp.y + k * 4), 2.2,
              Paint()..color = const Color.fromRGBO(200, 230, 255, 0.5));
        } else {
          line3(c, cam, size, P3(lx + 22, 92, z0), P3(-16, 84, z0),
              Color.fromRGBO(int.parse(rr[0]), int.parse(rr[1]),
                  int.parse(rr[2]), 0.6),
              1.4);
        }
      }
    }
    // إلكترونات متطايرة
    if (effUV > 0 && charge < 0) {
      for (var k = 0; k < 10; k++) {
        final ph = (t * 0.7 + k / 10) % 1;
        final ep = cam.project(
            P3(60 + ph * 135, 56 + math.sin(k * 2.4) * 30 + ph * 44,
                math.sin(k * 3.3) * 30),
            size);
        c.drawCircle(
            Offset(ep.x, ep.y),
            2.2,
            Paint()
                ..color = Color.fromRGBO(200, 230, 255, (1 - ph).toDouble()));
      }
    }
    _arabic(
        c,
        'اللوح: ${charge == -1 ? 'سالب' : charge == 1 ? 'موجب' : 'متعادل'} · الأوراق: ${toAr((q * 100).round())}٪',
        Offset(size.width / 2, 26),
        12,
        const Color(0xFFE8E2D0));
    _arabic(
        c,
        'المصباح: ${lamp == 0 ? 'مطفأ' : lamp == 1 ? 'UV' : 'ضوء أبيض'}${glass ? ' · صفائح زجاجية' : ''}${effUV > 0 && charge < 0 ? ' · تفريغ ضوئي!' : ''}',
        Offset(size.width / 2, 46),
        12,
        effUV > 0 && charge < 0
            ? const Color(0xFFF0964A)
            : const Color.fromRGBO(232, 226, 208, 0.8));
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
      appBar: AppBar(
          title: const Text('المختبر: صفيحة التوتياء — الفعل الكهرضوئي')),
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
                painter: _TutiaPainter(this),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6,
                alignment: WrapAlignment.center, children: [
              ViewToggle(
                  view3d: view3d,
                  onChanged: (x) => setState(() => view3d = x)),
              OutlinedButton(
                  onPressed: () => setState(() {
                        charge = -1;
                        q = 1;
                        won = false;
                      }),
                  child: const Text('اشحن الكهرسكوب (−)')),
              OutlinedButton(
                  onPressed: () => setState(() => lamp = lamp == 1 ? 0 : 1),
                  child: Text(lampLabel)),
              OutlinedButton(
                  onPressed: () => setState(() => lamp = 2),
                  child: const Text('مصباح ضوئي أبيض')),
              OutlinedButton(
                  onPressed: () => setState(() => glass = !glass),
                  child: Text(glass ? '🪟 زجاج: قريب' : '🪟 زجاج: بعيد')),
              OutlinedButton(onPressed: _reset, child: const Text('↺ إعادة')),
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
                    'التفريغ يجري بمصباح UV. حطينا زجاجاً بين المصباح والصفيحة — ماذا يحدث؟',
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
                          'يستمر التفريغ أبطأ فقط',
                          'يتوقف التفريغ — الزجاج يمتص UV',
                          'ينعكس التفريغ',
                        ][oi]),
                      ),
                    ),
                  ),
                if (_predictPick != null)
                  Text(
                    _predictPick == 2
                        ? '✔ صحيح — UV فقط هو الفعّال، والزجاج يمتصه'
                        : '✘ الزجاج يحجب UV بالكامل — التفريغ يتوقف',
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('الشحنة: ${toAr((q * 100).round())}٪'),
              _chip(effUV > 0 ? 'UV فعّال' : 'لا UV'),
              if (!_challengeDoneToday)
                _chip(
                    won ? '🎯 منجز!' : '🎯 فرّغ الشحنة السالبة كاملة بمصباح UV',
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
              _explainLine('UV ينتزع إلكترونات من صفيحة الخارصين السالبة ⇒ الشحنة تهرب ⇒ أوراق الكهرسكوب تهبط تدريجياً.'),
              _explainLine('الضوء الأبيض (طول موجي أطول) لا ينتزع إلكترونات — الفعل الكهرضوئي يحتاج تردداً عتبة.'),
              _explainLine('الزجاج يمتص UV ويمرر المرئي ⇒ وضع الزجاج يوقف التفريغ تماماً: دليل أن الفعّال هو غير المرئي.'),
              _explainLine('بمنظور 3D: لاحظ الأشعة تنقطع عند الزجاج والإلكترونات تتوقف عن التطاير.'),
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

class _TutiaPainter extends CustomPainter {
  _TutiaPainter(this.st);
  final _TutiaScreenState st;

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
          '🔒 يُفتح الشرح عند أول تفريغ ضوئي — اشحن ثم شغّل UV!',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
