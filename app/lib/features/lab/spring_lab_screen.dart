import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/lab/spring_sim.dart';
import '../../core/theme/app_colors.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';

/// F3.5 — تجربة النابض التوافقي بمنهجية PhET/POE كاملة (قرار ٤٣):
/// **توقع** (فرضية قبل التجريب) ← **لاحظ** (محاكاة RK4 حتماً + قياس T)
/// ← **اشرح** (ربط الملاحظة بالقانون) + تحدي «اجعل T=٢ث» (+١٠ بسقف يومي).
class SpringLabScreen extends StatefulWidget {
  const SpringLabScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;

  @override
  State<SpringLabScreen> createState() => _SpringLabScreenState();
}

class _SpringLabScreenState extends State<SpringLabScreen>
    with SingleTickerProviderStateMixin {
  // معاملات التجربة (منزلقات PhET — نطاق صريح).
  double _m = 1.0; // كغ
  double _k = 10.0; // N/m

  // الفيزياء الحية.
  SpringState _state = const SpringState(0.0, 0.0);
  final double _x0Max = 0.6; // أقصى سحب بالأمتار
  bool _running = false;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _simTime = 0.0;
  double _accumulator = 0.0;
  final PeriodMeter _meter = PeriodMeter();

  // منهجية POE.
  int _stage = 0; // 0=توقع 1=لاحظ 2=اشرح(متاح دائماً بعد أول قياس)
  int? _prediction; // فهرس التوقع المختار

  TrainingData _data = const TrainingData();
  bool _challengeDoneToday = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    final today = dateKeyOf(DateTime.now());
    _challengeDoneToday =
        _data.labChallengeDoneDateKey == today;
    _ticker = createTicker(_onTick);
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
      _state = rk4Step(_state, _m, _k);
      _meter.feed(_simTime, _state.x);
    }
    if (mounted) setState(() {});
  }

  void _toggleRun() {
    setState(() {
      _running = !_running;
      if (_running) {
        if (_stage == 0) _stage = 1; // أول تشغيل = بدء الملاحظة
        _lastTick = Duration.zero;
        _ticker.start();
      }
    });
  }

  void _resetMotion() {
    _ticker.stop();
    setState(() {
      _running = false;
      _state = const SpringState(0.0, 0.0);
      _simTime = 0.0;
      _accumulator = 0.0;
      _meter.reset();
    });
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = TrainingData(
      daily: _data.daily,
      mistakes: _data.mistakes,
      cardStates: _data.cardStates,
      cardDay: _data.cardDay,
      labChallengeDoneDateKey: today,
    );
    await widget.trainingStore.save(updated);
    if (!mounted) return;
    setState(() {
      _data = updated;
      _challengeDoneToday = true;
    });
  }

  void _dragTo(double normalized) {
    // سحب المستخدم ⇒ الشروط الابتدائية (مطال + بداية ساكنة)
    // ⚠️ double.clamp يرجع num — .toDouble() إلزامي قبل العمر double
    final clamped = normalized.clamp(-1.0, 1.0).toDouble();
    _ticker.stop();
    setState(() {
      _running = false;
      _state = SpringState.released(clamped * _x0Max);
      _simTime = 0.0;
      _accumulator = 0.0;
      _meter.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? AppColors.goldDark
        : AppColors.goldLight;
    final theory = periodOf(_m, _k);
    final measured = _meter.averagePeriod;
    final challengeNow = challengeT2Ok(_m, _k);

    return Scaffold(
      appBar: AppBar(title: const Text('المختبر: النابض التوافقي')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_stage == 0) _buildPredict(txt),
          if (_stage >= 1) ...[
            _buildSim(txt, gold, theory),
            const SizedBox(height: 12),
            _buildChallenge(txt, gold, theory, challengeNow),
            if (measured != null) ...[
              const SizedBox(height: 12),
              _buildExplain(txt, measured, theory),
            ],
          ],
        ],
      ),
    );
  }

  // ── مرحلة ١: توقع (Predict) ──
  Widget _buildPredict(TextTheme txt) {
    const options = ['يقصر الدور T', 'لا يتغير T', 'يطول الدور T'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('توقع قبل التجريب', style: txt.titleLarge),
            const SizedBox(height: 8),
            Text(
              'لو ضاعفنا الكتلة m المعلّقة على النابض (مع ثبات الصلابة k)، '
              'ماذا يحدث لدور الاهتزاز T؟',
              style: txt.bodyLarge,
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _prediction = i;
                    _stage = 1;
                  }),
                  child: Text(options[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── مرحلة ٢: لاحظ (Observe) — المحاكاة الحية ──
  Widget _buildSim(TextTheme txt, Color gold, double theory) {
    final measured = _meter.averagePeriod;
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
                Text('الفترة النظرية: ${theory.toStringAsFixed(2)} ث',
                    style: txt.bodyMedium),
              ],
            ),
            const SizedBox(height: 10),
            // الرسم الحي — السحب يحدد الشرط الابتدائي
            GestureDetector(
              onHorizontalDragUpdate: (d) =>
                  _running ? null : _dragTo(d.localPosition.dx / 260 - 1),
              onTapUp: (d) =>
                  _running ? null : _dragTo(d.localPosition.dx / 260 - 1),
              child: SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: _SpringPainter(
                    x: _state.x,
                    xMax: _x0Max,
                    gold: gold,
                    running: _running,
                  ),
                ),
              ),
            ),
            Text(
              _running
                  ? 'المحاكاة تعمل — RK4 خطوة ١/٢٤٠ ث'
                  : 'اسحب الكتلة ثم شغّل — أو العب بالمنزلقين',
              style: txt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
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
            _buildSlider(txt, 'الكتلة m', '${_m.toStringAsFixed(1)} كغ',
                _m, 0.5, 5.0, (v) => setState(() {
                      _m = v;
                      _meter.reset();
                    })),
            _buildSlider(txt, 'الصلابة k', '${_k.toStringAsFixed(0)} N/m',
                _k, 5.0, 100.0, (v) => setState(() {
                      _k = v;
                      _meter.reset();
                    })),
            if (measured != null)
              Text(
                'T المقيس من المحاكاة ≈ ${measured.toStringAsFixed(3)} ث '
                '(بعد ${ArabicNumber.from(_meter.measuredCount)} دورة)',
                style: txt.titleMedium?.copyWith(color: gold),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(TextTheme txt, String label, String value,
      double v, double min, double max, ValueChanged<double> onCh) {
    final step = max - min == 95.0 ? 1.0 : 0.1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label = $value', style: txt.titleSmall),
        Row(
          children: [
            IconButton(
              tooltip: 'إنقاص',
              onPressed: v - step >= min
                  ? () => onCh(double.parse((v - step).toStringAsFixed(2)))
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Slider(
                value: v,
                min: min,
                max: max,
                divisions: ((max - min) / step).round(),
                onChanged: (val) => onCh(double.parse(
                    (min + ((val - min) / step).round() * step)
                        .toStringAsFixed(2))),
              ),
            ),
            IconButton(
              tooltip: 'زيادة',
              onPressed: v + step <= max
                  ? () => onCh(double.parse((v + step).toStringAsFixed(2)))
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  // ── التحدّي: اجعل T = ٢ث (+١٠ بسقف يومي) ──
  Widget _buildChallenge(TextTheme txt, Color gold, double theory,
      bool now) {
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
            Text('🎯 التحدي: اجعل T = ٢ث (± ٠٫٠٥)', style: txt.titleLarge),
            const SizedBox(height: 6),
            Text(
              'T الحالي = ${theory.toStringAsFixed(3)} ث — '
              'السعة من: T = 2π·√(m/k)',
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (_challengeDoneToday) ...[
              Text('✓ سُجّل اليوم — +١٠ نقطة لدوري فيزيا كلاش',
                  style: txt.titleMedium?.copyWith(color: gold),
                  textAlign: TextAlign.center),
              Text('غداً تحدٍّ جديد بذات العدالة',
                  style: txt.bodySmall, textAlign: TextAlign.center),
            ] else if (now) ...[
              Text('🎯 تحقّق! |T − 2| ≤ 0.05',
                  style: txt.titleMedium?.copyWith(color: gold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _recordChallenge,
                child: const Text('سجّل التحدي (+١٠)'),
              ),
            ] else
              Text('اضبط m وk حتى يدخل T في النافذة',
                  style: txt.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── مرحلة ٣: اشرح (Explain) — بعد أول قياس ──
  Widget _buildExplain(TextTheme txt, double measured, double theory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اشرح', style: txt.titleLarge),
            const SizedBox(height: 6),
            Text(
              'قياسك ${measured.toStringAsFixed(3)} ث قريب من النظري '
              '${theory.toStringAsFixed(3)} ث — لأن الدور يحكمه القانون '
              'T = 2π·√(m/k): مضاعفة m تطيل T بجذرها، ومضاعفة k تقصّره '
              'بجذرها. المطال لا يؤثر في T — اهتزاز توافقي بسيط.',
              style: txt.bodyLarge,
            ),
            if (_prediction != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _prediction == 2
                      ? 'توقعك «يطول T» كان مطابقاً للقانون ✓'
                      : 'الآن ترى لماذا التوقع الأدق «يطول T» — القانون بجذر m',
                  style: txt.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// رسام النابض: جدار + زجزاج نابض + كتلة — كلها من x الفيزيائية.
class _SpringPainter extends CustomPainter {
  const _SpringPainter({
    required this.x,
    required this.xMax,
    required this.gold,
    required this.running,
  });

  final double x;
  final double xMax;
  final Color gold;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    final wallX = 28.0;
    final centerY = size.height / 2;
    final restLen = size.width - 120.0; // طول السكون للنابض
    final blockW = 46.0;
    // الإزاحة الفيزيائية (±xMax م) ← بكسلات (±70 بكسل)
    final px = (x / xMax) * 70.0;
    final blockX = wallX + restLen + px;

    final line = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // الجدار
    canvas.drawLine(Offset(wallX, centerY - 40),
        Offset(wallX, centerY + 40), line);

    // زجزاج النابض (12 ضلعة)
    final end = blockX - blockW / 2;
    final len = end - wallX;
    final seg = len / 12.0;
    final path = Path()..moveTo(wallX, centerY);
    for (var i = 1; i < 12; i++) {
      path.lineTo(wallX + seg * i,
          centerY + (i.isOdd ? -13.0 : 13.0));
    }
    path.lineTo(end, centerY);
    canvas.drawPath(path, line);

    // الكتلة
    final block = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(blockX + blockW / 2, centerY),
        width: blockW,
        height: 52,
      ),
      const Radius.circular(8),
    );
    final fill = Paint()..color = gold.withValues(alpha: .30);
    final border = Paint()
      ..color = gold
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(block, fill);
    canvas.drawRRect(block, border);

    // خط الصفر (موضع السكون)
    final dash = Paint()
      ..color = Colors.grey.withValues(alpha: .5)
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < size.width; dx += 12) {
      canvas.drawLine(Offset(wallX + restLen + dx, centerY - 4),
          Offset(wallX + restLen + dx + 6, centerY - 4), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _SpringPainter old) =>
      old.x != x || old.running != running;
}
