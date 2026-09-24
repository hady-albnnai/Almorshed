import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/lab/experiments.dart';
import '../../core/lab/spring_sim.dart' show PeriodMeter, simDt;
import '../../core/theme/app_colors.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٤ — شاشة تجربة عامة تُشغّل أيّ `LabExperiment` (الخمس الجديدة)
/// بقالب النابض نفسه (F3.5 · قرار ٤٣): **توقّع** ← **لاحظ** (RK4 حي + عدّاد
/// دور) ← **اشرح** + تحدٍّ (+١٠ `labChallenge` مرة/يوم بالدفتر).
///
/// تُفتح من داخل الدرس بموضعها (قرار ٥٨/٣٧) ومن فهرس المختبر — نفس الشاشة.
class ExperimentScreen extends StatefulWidget {
  const ExperimentScreen({
    super.key,
    required this.experiment,
    required this.trainingStore,
    this.xpRecorder,
  });

  final LabExperiment experiment;
  final TrainingStore trainingStore;
  final XpRecorder? xpRecorder;

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen>
    with SingleTickerProviderStateMixin {
  LabExperiment get _exp => widget.experiment;

  late Map<String, double> _p = _exp.initialParams;
  OscState _state = const OscState(0.0, 0.0);
  bool _running = false;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _simTime = 0.0;
  double _accumulator = 0.0;
  final PeriodMeter _meter = PeriodMeter();

  int _stage = 0; // 0 توقّع · 1 لاحظ/اشرح
  int? _prediction;

  TrainingData _data = const TrainingData();
  bool _loaded = false;
  bool _challengeDoneToday = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _load();
  }

  Future<void> _load() async {
    final d = await widget.trainingStore.load();
    if (!mounted) return;
    setState(() {
      _data = d;
      _loaded = true;
      _challengeDoneToday =
          d.labChallengeDays[_exp.id] == dateKeyOf(DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.stop();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_running) {
      _lastTick = elapsed;
      return;
    }
    final dtReal = elapsed - _lastTick;
    _lastTick = elapsed;
    _accumulator += dtReal.inMicroseconds / 1e6;
    // خطوات فيزيائية كاملة حصراً — الحتمية بالخطوة الثابتة
    while (_accumulator >= simDt) {
      _accumulator -= simDt;
      _simTime += simDt;
      _state = _exp.step(_state, _p);
      _meter.feed(_simTime, _state.q);
    }
    if (mounted) setState(() {});
  }

  void _toggleRun() {
    setState(() {
      _running = !_running;
      if (_running) {
        if (_state.q == 0.0 && _state.dq == 0.0) {
          // بلا سحب: نبدأ من نصف الانحراف الأقصى حتى يتذبذب شيء
          _state = OscState(_exp.maxInitial * 0.5, 0.0);
        }
        _lastTick = Duration.zero;
        _ticker.start();
      }
    });
  }

  void _resetMotion() {
    _ticker.stop();
    setState(() {
      _running = false;
      _state = const OscState(0.0, 0.0);
      _simTime = 0.0;
      _accumulator = 0.0;
      _meter.reset();
    });
  }

  void _dragTo(double normalized) {
    final c = normalized.clamp(-1.0, 1.0).toDouble();
    _ticker.stop();
    setState(() {
      _running = false;
      _state = OscState(c * _exp.maxInitial, 0.0);
      _simTime = 0.0;
      _accumulator = 0.0;
      _meter.reset();
    });
  }

  void _setParam(String id, double v) {
    setState(() {
      _p = {..._p, id: v};
      _meter.reset();
    });
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: {..._data.labChallengeDays, _exp.id: today},
    );
    await widget.trainingStore.save(updated);
    // +١٠ مرة/يوم لكل التجارب معاً (سقف الدفتر يحمي من التكرار)
    await widget.xpRecorder?.record('labChallenge');
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? AppColors.goldDark
        : AppColors.goldLight;
    final theory = _exp.toDisplay(_exp.period(_p));
    final measuredSim = _meter.averagePeriod;
    final measured = measuredSim == null ? null : _exp.toDisplay(measuredSim);
    final ch = _exp.challenge;
    final challengeNow = ch != null && ch.ok(_exp.challengeValue(_p));

    return Scaffold(
      appBar: AppBar(title: Text('المختبر: ${_exp.title}')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (_stage == 0) _buildPredict(txt),
                if (_stage >= 1) ...[
                  _buildSim(txt, gold, theory, measured),
                  const SizedBox(height: 12),
                  if (ch != null) _buildChallenge(txt, gold, ch, challengeNow),
                  if (measured != null || !_exp.hasDynamics) ...[
                    const SizedBox(height: 12),
                    _buildExplain(txt, measured ?? 0.0, theory),
                  ],
                ],
              ],
            ),
    );
  }

  // ── ١) توقّع ──
  Widget _buildPredict(TextTheme txt) {
    final pr = _exp.prediction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('توقع قبل التجريب', style: txt.titleLarge),
            const SizedBox(height: 8),
            Text(pr.question, style: txt.bodyLarge),
            const SizedBox(height: 14),
            for (var i = 0; i < pr.options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  key: Key('predict-$i'),
                  onPressed: () => setState(() {
                    _prediction = i;
                    _stage = 1;
                  }),
                  child: Text(pr.options[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ٢) لاحظ ──
  Widget _buildSim(TextTheme txt, Color gold, double theory, double? measured) {
    final dyn = _exp.hasDynamics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('لاحظ', style: txt.titleLarge),
                if (dyn)
                  Text(
                    'النظري: ${theory.toStringAsFixed(3)} ${_exp.periodUnit}',
                    key: const Key('theory-period'),
                    style: txt.bodyMedium,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (dyn)
              GestureDetector(
                key: const Key('exp-canvas'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) =>
                    _running ? null : _dragTo(d.localPosition.dx / 160 - 1),
                onTapUp: (d) =>
                    _running ? null : _dragTo(d.localPosition.dx / 160 - 1),
                child: SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: _ExperimentPainter(
                      exp: _exp,
                      params: _p,
                      q: _state.q,
                      t: _simTime,
                      gold: gold,
                      running: _running,
                      dark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _ExperimentPainter(
                    exp: _exp,
                    params: _p,
                    q: 0,
                    t: 0,
                    gold: gold,
                    running: false,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            if (dyn) ...[
              Text(
                _running
                    ? 'المحاكاة تعمل — RK4 خطوة ١/٢٤٠ ث'
                    : 'اسحب لتحدد الانحراف الابتدائي ثم شغّل — أو العب بالمنزلقات',
                style: txt.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('exp-run'),
                      onPressed: _toggleRun,
                      child: Text(_running ? 'إيقاف' : 'تشغيل ▶'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetMotion,
                      child: const Text('تصفير'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            for (final prm in _exp.params) _buildSlider(txt, prm),
            if (measured != null)
              Text(
                '${_exp.measuredLabel} ≈ ${measured.toStringAsFixed(3)} ${_exp.periodUnit} '
                '(بعد ${ArabicNumber.from(_meter.measuredCount)} دورة)',
                key: const Key('measured-period'),
                style: txt.titleMedium?.copyWith(color: gold),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 6),
            Text(_exp.law, style: txt.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(TextTheme txt, LabParam prm) {
    final v = _p[prm.id]!;
    final divisions = ((prm.max - prm.min) / prm.step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${prm.label} = ${v.toStringAsFixed(prm.decimals)} ${prm.unit}',
          key: Key('param-${prm.id}'),
          style: txt.titleSmall,
        ),
        Row(
          children: [
            IconButton(
              key: Key('dec-${prm.id}'),
              tooltip: 'إنقاص',
              onPressed: v - prm.step >= prm.min - 1e-9
                  ? () => _setParam(prm.id, prm.clampSnap(v - prm.step))
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Slider(
                value: v.clamp(prm.min, prm.max).toDouble(),
                min: prm.min,
                max: prm.max,
                divisions: divisions,
                onChanged: (val) => _setParam(prm.id, prm.clampSnap(val)),
              ),
            ),
            IconButton(
              key: Key('inc-${prm.id}'),
              tooltip: 'زيادة',
              onPressed: v + prm.step <= prm.max + 1e-9
                  ? () => _setParam(prm.id, prm.clampSnap(v + prm.step))
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  // ── التحدّي ──
  Widget _buildChallenge(
      TextTheme txt, Color gold, LabChallenge ch, bool now) {
    final value = _exp.challengeValue(_p);
    final valueText = _exp.id == 'string'
        ? (value < 0 ? 'لا طنين' : 'n = ${ArabicNumber.from(value.toInt())}')
        : value.toStringAsFixed(3);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: gold.withValues(alpha: .45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ch.title, style: txt.titleLarge),
            const SizedBox(height: 6),
            Text('القيمة الحالية: $valueText — ${ch.hint}',
                style: txt.bodyMedium),
            const SizedBox(height: 8),
            if (_challengeDoneToday) ...[
              Text('✓ سُجّل اليوم — +١٠ نقطة تعلّم',
                  style: txt.titleMedium?.copyWith(color: gold),
                  textAlign: TextAlign.center),
              Text('غداً تحدٍّ جديد بذات العدالة',
                  style: txt.bodySmall, textAlign: TextAlign.center),
            ] else if (now) ...[
              Text('🎯 تحقّق!',
                  style: txt.titleMedium?.copyWith(color: gold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('challenge-record'),
                onPressed: _recordChallenge,
                child: const Text('سجّل التحدي (+١٠)'),
              ),
            ] else
              Text('اضبط المنزلقات حتى يتحقق الهدف',
                  style: txt.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── ٣) اشرح ──
  Widget _buildExplain(TextTheme txt, double measured, double theory) {
    final pr = _exp.prediction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اشرح', style: txt.titleLarge),
            const SizedBox(height: 6),
            Text(_exp.explain(_p, measured, theory), style: txt.bodyLarge),
            if (_prediction != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _prediction == pr.correct
                      ? 'توقعك «${pr.options[pr.correct]}» كان مطابقاً للقانون ✓'
                      : 'التوقع الأدق «${pr.options[pr.correct]}» — ${pr.afterText}',
                  style: txt.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// رسّام عام: شكل مختلف لكل تجربة من الإحداثي q والمعاملات.
class _ExperimentPainter extends CustomPainter {
  const _ExperimentPainter({
    required this.exp,
    required this.params,
    required this.q,
    required this.t,
    required this.gold,
    required this.running,
    required this.dark,
  });

  final LabExperiment exp;
  final Map<String, double> params;
  final double q;
  final double t;
  final Color gold;
  final bool running;
  final bool dark;

  Color get _ink => dark ? Colors.white : const Color(0xFF1A2233);
  Color get _metal => dark ? const Color(0xFFB7C0D8) : const Color(0xFF64748B);

  @override
  void paint(Canvas canvas, Size size) {
    _panel(canvas, size);
    switch (exp.id) {
      case 'torsion':
        _paintTorsion(canvas, size);
      case 'gravity':
        _paintGravity(canvas, size);
      case 'lc':
        _paintLc(canvas, size);
      case 'string':
        _paintString(canvas, size);
      default:
        _paintPhoto(canvas, size);
    }
  }

  // خلفية المختبر: تدرّج + شبكة قياس خفيفة + إطار.
  void _panel(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    c.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF121A2B), Color(0xFF0A0F1A)]
              : const [Color(0xFFF4F7FF), Color(0xFFE6ECF8)],
        ).createShader(rect),
    );
    c.save();
    c.clipRRect(rr);
    final grid = Paint()
      ..color = _ink.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 22) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), grid);
    }
    for (double y = 0; y < s.height; y += 22) {
      c.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
    c.restore();
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = gold.withValues(alpha: 0.25),
    );
  }

  Paint _glow(Color col, double blur, double w) => Paint()
    ..color = col
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  void _dash(Canvas c, Offset a, Offset b) {
    final paint = Paint()
      ..color = _ink.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    const n = 18;
    for (var i = 0; i < n; i += 2) {
      c.drawLine(
          Offset.lerp(a, b, i / n)!, Offset.lerp(a, b, (i + 1) / n)!, paint);
    }
  }

  Shader _sphere(Offset ctr, double r, Color col) => RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [Colors.white, col, Color.lerp(col, Colors.black, 0.35)!],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: ctr, radius: r));

  // ── نواس الفتل (منظر علوي): ساق تدور + كتلتان طرفيّتان + توهّج + أثر حركة ──
  void _paintTorsion(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final half = math.min(s.width, s.height) * 0.40;
    _dash(c, ctr - Offset(half, 0), ctr + Offset(half, 0));
    if (running) {
      for (final f in const [0.85, 0.6]) {
        _rod(c, ctr, half, q * f, gold.withValues(alpha: 0.10), 5);
      }
    }
    _rod(c, ctr, half, q, gold, 7);
    c.drawCircle(ctr, 9, Paint()..shader = _sphere(ctr, 9, _metal));
    c.drawCircle(
        ctr,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = gold
          ..strokeWidth = 2);
  }

  void _rod(Canvas c, Offset ctr, double half, double ang, Color col, double w) {
    final d = Offset(math.cos(ang) * half, math.sin(ang) * half);
    final a = ctr - d, b = ctr + d;
    c.drawLine(a, b, _glow(col.withValues(alpha: 0.5), 6, w + 3));
    c.drawLine(
        a,
        b,
        Paint()
          ..color = col
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round);
    for (final e in [a, b]) {
      c.drawCircle(e, w + 3, Paint()..shader = _sphere(e, w + 3, col));
    }
  }

  // ── نواس ثقلي: حامل سقف + خيط + كرة لامعة + قوس المدى + ظل ──
  void _paintGravity(Canvas c, Size s) {
    final pivot = Offset(s.width / 2, 18);
    final len = s.height - 50;
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(pivot.dx, 10), width: 70, height: 9),
          const Radius.circular(3)),
      Paint()..color = _metal,
    );
    // قوس المدى ±maxInitial
    final amp = exp.maxInitial;
    final arc = Path();
    for (var i = 0; i <= 40; i++) {
      final a = -amp + 2 * amp * i / 40;
      final p = pivot + Offset(math.sin(a) * len, math.cos(a) * len);
      i == 0 ? arc.moveTo(p.dx, p.dy) : arc.lineTo(p.dx, p.dy);
    }
    c.drawPath(arc, _glow(gold.withValues(alpha: 0.22), 3, 2));
    _dash(c, pivot, Offset(pivot.dx, pivot.dy + len));
    final bob = pivot + Offset(math.sin(q) * len, math.cos(q) * len);
    c.drawLine(
        pivot,
        bob,
        Paint()
          ..color = _metal
          ..strokeWidth = 2);
    c.drawCircle(pivot, 4, Paint()..color = gold);
    c.drawCircle(
        bob + const Offset(2, 4),
        15,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawCircle(bob, 15, Paint()..shader = _sphere(bob, 15, gold));
    c.drawCircle(
        bob,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = gold.withValues(alpha: 0.5)
          ..strokeWidth = 1.2);
  }

  // ── دارة LC: لبوسان بشحنة متوهّجة (±) + وشيعة + تيّار متحرّك يشتدّ عند q=0 ──
  void _paintLc(Canvas c, Size s) {
    final left = 34.0, right = s.width - 34, top = 28.0, bottom = s.height - 28;
    final midY = (top + bottom) / 2;
    final qmax = exp.maxInitial == 0 ? 1.0 : exp.maxInitial;
    final norm = (q / qmax).clamp(-1.0, 1.0).toDouble();
    final current = math.sqrt((1 - norm * norm).clamp(0.0, 1.0));

    final wire = Paint()
      ..color = _metal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(left, top), Offset(right, top), wire);
    c.drawLine(Offset(left, bottom), Offset(right, bottom), wire);
    c.drawLine(Offset(left, top), Offset(left, midY - 16), wire);
    c.drawLine(Offset(left, midY + 16), Offset(left, bottom), wire);
    // الوشيعة (يمين)
    final coil = Path()..moveTo(right, top);
    const segs = 5;
    final segH = (bottom - top) / segs;
    for (var i = 0; i < segs; i++) {
      coil.arcToPoint(Offset(right, top + segH * (i + 1)),
          radius: Radius.circular(segH / 2), clockwise: false);
    }
    c.drawPath(coil, wire);
    // لبوسا المكثفة
    final plate = Paint()
      ..color = _ink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(left - 16, midY - 16), Offset(left + 16, midY - 16), plate);
    c.drawLine(Offset(left - 16, midY + 16), Offset(left + 16, midY + 16), plate);
    // توهّج الشحنة (أحمر=+ ، أزرق=−) بشدّة ∝ |q|
    final pos = norm >= 0;
    final a = 0.12 + 0.65 * norm.abs();
    c.drawCircle(
        Offset(left, midY - 24),
        8,
        Paint()
          ..color = (pos ? Colors.redAccent : Colors.blueAccent).withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    c.drawCircle(
        Offset(left, midY + 24),
        8,
        Paint()
          ..color = (pos ? Colors.blueAccent : Colors.redAccent).withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // تيّار متحرّك متوهّج حول الحلقة
    if (running && current > 0.02) {
      final loop = Path()
        ..moveTo(left, midY + 16)
        ..lineTo(left, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, top)
        ..lineTo(left, top)
        ..lineTo(left, midY - 16);
      final metrics = loop.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final total = metric.length;
        final base = (t * 70) % (total / 8);
        final glow = Paint()
          ..color = gold.withValues(alpha: 0.25 + 0.7 * current)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        for (var k = 0; k < 8; k++) {
          final tan = metric.getTangentForOffset((base + k * total / 8) % total);
          if (tan != null) c.drawCircle(tan.position, 3.0 + 2 * current, glow);
        }
      }
    }
  }

  // ── موجة مستقرة: وتر متوهّج + مغلّف السعة + عقد وبطون نابضة ──
  void _paintString(Canvas c, Size s) {
    final n = StringWaveExperiment.spindles(params);
    final y0 = s.height / 2;
    final w = s.width - 40;
    final post = Paint()
      ..color = _metal
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(20, y0 - 34), Offset(20, y0 + 34), post);
    c.drawLine(Offset(s.width - 20, y0 - 34), Offset(s.width - 20, y0 + 34), post);
    final ampMax = s.height / 2 - 14;
    final inst = (q.abs() > 0 ? q.clamp(-1.0, 1.0).toDouble() : 0.55);
    final amp = ampMax * inst;

    Offset at(double x) {
      double y;
      if (n != null) {
        y = math.sin(n * math.pi * x) * amp;
      } else {
        final lam = StringWaveExperiment.wavelength(params) / params['L']!;
        y = math.sin(2 * math.pi * x / lam - t * 6) * amp * 0.35;
      }
      return Offset(20 + x * w, y0 - y);
    }

    // مغلّف السعة (خافت)
    if (n != null) {
      for (final sgn in const [1.0, -1.0]) {
        final env = Path();
        for (var i = 0; i <= 120; i++) {
          final x = i / 120.0;
          final p = Offset(20 + x * w,
              y0 - sgn * math.sin(n * math.pi * x).abs() * ampMax * 0.9);
          i == 0 ? env.moveTo(p.dx, p.dy) : env.lineTo(p.dx, p.dy);
        }
        c.drawPath(
            env,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = gold.withValues(alpha: 0.16));
      }
    }
    // الوتر
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final p = at(i / 120.0);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, _glow(gold.withValues(alpha: 0.4), 6, 4));
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = gold
          ..strokeCap = StrokeCap.round);
    // العقد والبطون
    if (n != null) {
      for (var k = 0; k <= n; k++) {
        c.drawCircle(Offset(20 + k / n * w, y0), 3.5,
            Paint()..color = _ink.withValues(alpha: 0.7));
      }
      for (var k = 0; k < n; k++) {
        final pa = at((k + 0.5) / n);
        c.drawCircle(
            pa,
            4 + 2 * inst.abs(),
            Paint()
              ..color = gold.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }
  }

  // ── الأثر الكهرضوئي: لوح معدني + فوتونات ملوّنة متحرّكة (لون ∝ λ) + إلكترونات ──
  void _paintPhoto(Canvas c, Size s) {
    final plateX = s.width * 0.30;
    final plateRect = Rect.fromLTWH(plateX - 10, 18, 10, s.height - 36);
    c.drawRect(
      plateRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_metal, Color.lerp(_metal, Colors.black, 0.4)!],
        ).createShader(plateRect),
    );
    final lam = params['lambda']!;
    final hue = ((700 - lam) / 400 * 270).clamp(0.0, 300.0).toDouble();
    final pcol = HSVColor.fromAHSV(1, hue, 0.85, 0.98).toColor();
    final phase = running ? (t * 4) % 1.0 : 0.35;
    final startX = s.width - 16;
    final endX = plateX + 2;
    for (var r = 0; r < 4; r++) {
      final y = 30.0 + r * (s.height - 60) / 3;
      final headX = startX - phase * (startX - endX);
      final p = Path()..moveTo(startX, y);
      for (var i = 1; i <= 30; i++) {
        final x = startX - i * (startX - headX) / 30;
        p.lineTo(x, y + math.sin(i / 30 * 6 * math.pi) * 5);
      }
      c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = pcol.withValues(alpha: 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      c.drawCircle(Offset(headX, y), 3, Paint()..color = pcol);
    }
    // إلكترونات خارجة إن hf > Ws
    if (PhotoelectricExperiment.emits(params)) {
      final ek = PhotoelectricExperiment.ekEv(params);
      final reach = (plateX - 26).clamp(20.0, s.width).toDouble();
      final ePhase = running ? (t * (0.5 + ek)) % 1.0 : 0.5;
      for (var r = 0; r < 4; r++) {
        final y = 34.0 + r * (s.height - 60) / 3;
        final ex = (plateX - 12) - ePhase * reach;
        c.drawLine(Offset(plateX - 12, y), Offset(ex, y),
            _glow(gold.withValues(alpha: 0.5), 4, 2));
        c.drawCircle(Offset(ex, y), 4, Paint()..shader = _sphere(Offset(ex, y), 4, gold));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExperimentPainter old) =>
      old.q != q ||
      old.t != t ||
      old.running != running ||
      old.params != params ||
      old.dark != dark;
}
