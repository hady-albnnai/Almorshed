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
  });

  final LabExperiment exp;
  final Map<String, double> params;
  final double q;
  final double t;
  final Color gold;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = gold.withValues(alpha: .30);
    final border = Paint()
      ..color = gold
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    switch (exp.id) {
      case 'torsion':
        _paintTorsion(canvas, size, line, fill, border);
      case 'gravity':
        _paintGravity(canvas, size, line, fill, border);
      case 'lc':
        _paintLc(canvas, size, line, fill, border);
      case 'string':
        _paintString(canvas, size, line, border);
      default:
        _paintPhoto(canvas, size, line, fill, border);
    }
  }

  /// ساق أفقية تدور حول مركزها بزاوية θ (منظر علوي) + السلك كنقطة.
  void _paintTorsion(
      Canvas c, Size s, Paint line, Paint fill, Paint border) {
    final ctr = Offset(s.width / 2, s.height / 2);
    c.drawCircle(ctr, 6, fill);
    c.drawCircle(ctr, 6, border);
    final half = math.min(s.width, s.height) * 0.42;
    final dx = math.cos(q) * half;
    final dy = math.sin(q) * half;
    c.drawLine(ctr - Offset(dx, dy), ctr + Offset(dx, dy), border);
    // خط المرجع (θ = 0)
    final dash = Paint()
      ..color = Colors.grey.withValues(alpha: .5)
      ..strokeWidth = 1;
    c.drawLine(Offset(ctr.dx - half, ctr.dy), Offset(ctr.dx + half, ctr.dy), dash);
  }

  /// خيط من نقطة تعليق علوية وكرة عند الزاوية θ عن الشاقول.
  void _paintGravity(
      Canvas c, Size s, Paint line, Paint fill, Paint border) {
    final pivot = Offset(s.width / 2, 12);
    final len = s.height - 40;
    final bob = pivot + Offset(math.sin(q) * len, math.cos(q) * len);
    c.drawLine(Offset(pivot.dx - 30, pivot.dy), Offset(pivot.dx + 30, pivot.dy), line);
    c.drawLine(pivot, bob, line);
    c.drawCircle(bob, 14, fill);
    c.drawCircle(bob, 14, border);
    final dash = Paint()
      ..color = Colors.grey.withValues(alpha: .5)
      ..strokeWidth = 1;
    c.drawLine(pivot, Offset(pivot.dx, pivot.dy + len), dash);
  }

  /// مكثفة (لبوسان بشحنة ±q) ووشيعة، مع شريط يمثل q/Qmax.
  void _paintLc(Canvas c, Size s, Paint line, Paint fill, Paint border) {
    final left = 30.0, right = s.width - 30.0, top = 30.0, bottom = s.height - 30.0;
    // الإطار
    c.drawLine(Offset(left, top), Offset(right, top), line);
    c.drawLine(Offset(left, bottom), Offset(right, bottom), line);
    c.drawLine(Offset(left, top), Offset(left, (top + bottom) / 2 - 10), line);
    c.drawLine(Offset(left, (top + bottom) / 2 + 10), Offset(left, bottom), line);
    // لبوسا المكثفة
    c.drawLine(Offset(left - 14, (top + bottom) / 2 - 10), Offset(left + 14, (top + bottom) / 2 - 10), border);
    c.drawLine(Offset(left - 14, (top + bottom) / 2 + 10), Offset(left + 14, (top + bottom) / 2 + 10), border);
    // الوشيعة (٤ حلقات) على الضلع الأيمن
    final coil = Path()..moveTo(right, top);
    final h = (bottom - top) / 4;
    for (var i = 0; i < 4; i++) {
      coil.arcToPoint(Offset(right, top + h * (i + 1)),
          radius: Radius.circular(h / 2), clockwise: false);
    }
    c.drawPath(coil, line);
    // شريط الشحنة: طوله ∝ q (موجب لأعلى، سالب لأسفل)
    final mid = Offset(s.width / 2, (top + bottom) / 2);
    final len = q.clamp(-1.0, 1.0).toDouble() * (bottom - top) / 2 * 0.9;
    c.drawRect(
      Rect.fromPoints(Offset(mid.dx - 10, mid.dy), Offset(mid.dx + 10, mid.dy - len)),
      fill,
    );
    c.drawLine(Offset(mid.dx - 16, mid.dy), Offset(mid.dx + 16, mid.dy), border);
  }

  /// موجة مستقرة y(x) = sin(nπx/L)·cos(ωt) إن كان f مدروجاً — وإلا اهتزاز مشوّش.
  void _paintString(Canvas c, Size s, Paint line, Paint border) {
    final n = StringWaveExperiment.spindles(params);
    final y0 = s.height / 2;
    c.drawLine(Offset(16, y0 - 30), Offset(16, y0 + 30), line);
    c.drawLine(Offset(s.width - 16, y0 - 30), Offset(s.width - 16, y0 + 30), line);
    final w = s.width - 32;
    final amp =
        (s.height / 2 - 12) * (q.abs() > 0 ? q.clamp(-1.0, 1.0).toDouble() : 0.6);
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final x = i / 120.0;
      double y;
      if (n != null) {
        y = math.sin(n * math.pi * x) * amp;
      } else {
        // بلا طنين: موجة جارية باهتة (تقريب بصري)
        final lam = StringWaveExperiment.wavelength(params) / params['L']!;
        y = math.sin(2 * math.pi * x / lam) * amp * 0.35;
      }
      final pt = Offset(16 + x * w, y0 - y);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    c.drawPath(path, border);
    // العقد
    if (n != null) {
      for (var k = 0; k <= n; k++) {
        c.drawCircle(Offset(16 + k / n * w, y0), 3.5, Paint()..color = gold);
      }
    }
  }

  /// مهبط + أسهم فوتونات؛ إلكترونات تخرج فقط إن hf > Ws.
  void _paintPhoto(
      Canvas c, Size s, Paint line, Paint fill, Paint border) {
    final plateX = s.width * 0.28;
    c.drawRect(Rect.fromLTWH(plateX - 8, 20, 8, s.height - 40), fill);
    c.drawRect(Rect.fromLTWH(plateX - 8, 20, 8, s.height - 40), border);
    // فوتونات (متموجة) قادمة من اليمين
    final lam = params['lambda']!;
    final hue = ((700 - lam) / 500 * 270).clamp(0.0, 300.0).toDouble();
    final photon = Paint()
      ..color = HSVColor.fromAHSV(1, hue, 0.8, 0.95).toColor()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var r = 0; r < 3; r++) {
      final y = 40.0 + r * (s.height - 80) / 2;
      final p = Path()..moveTo(s.width - 20, y);
      for (var i = 1; i <= 24; i++) {
        final x = s.width - 20 - i * (s.width - plateX - 30) / 24;
        p.lineTo(x, y + math.sin(i / 24 * 8 * math.pi) * 5);
      }
      c.drawPath(p, photon);
    }
    // إلكترونات خارجة (يسار اللوح) إن تحقق الانتزاع
    if (PhotoelectricExperiment.emits(params)) {
      final ek = PhotoelectricExperiment.ekEv(params);
      final reach = (20 + ek * 30).clamp(20.0, plateX - 30).toDouble();
      for (var r = 0; r < 3; r++) {
        final y = 46.0 + r * (s.height - 80) / 2;
        c.drawLine(Offset(plateX - 10, y), Offset(plateX - 10 - reach, y), border);
        c.drawCircle(Offset(plateX - 10 - reach, y), 4, Paint()..color = gold);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExperimentPainter old) =>
      old.q != q || old.running != running || old.params != params;
}
