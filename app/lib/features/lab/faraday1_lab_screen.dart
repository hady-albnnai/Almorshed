import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/lab/faraday1_sim.dart';
import '../../core/lab/spring_sim.dart' show simDt;
import '../../core/theme/app_colors.dart';
import '../../core/training/batch_builder.dart' show dateKeyOf;
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';
import '../../core/xp/streak_service.dart';

/// المادة ١٤ — تجربة فاراداي (١): مغناطيس ووشيعة (تحريض كهرومغناطيسي).
/// النموذج المعتمد من المالك ٢٠٢٦-١٠-٠٢ منقول كما هو: منهجية POE كاملة
/// (توقّع ← لاحِظ ← اشرح يُفتح بعد أول قياس)، سحب حي للمغناطيس، خيوط تدفق
/// متحركة، أسهم تيار متحرّض، شارة وجه مستحثّ (لينز)، جلفانومتر بذيول
/// فوسفورية وقمّة مُحتفَظة، راسم ε(t)/Φ(t) بنافذة ٦ث، إعادة آخر ٣ث ×٠٫٢٥،
/// وتحدّي الانحرافين المتعاكسين ≥٦٠٪ (+١٠ عبر `labChallengeDays`).
class Faraday1LabScreen extends StatefulWidget {
  const Faraday1LabScreen({
    super.key,
    required this.trainingStore,
    required this.initialData,
    this.xpRecorder,
  });

  final TrainingStore trainingStore;
  final TrainingData initialData;
  final XpRecorder? xpRecorder;

  @override
  State<Faraday1LabScreen> createState() => _Faraday1LabScreenState();
}

class _Faraday1LabScreenState extends State<Faraday1LabScreen>
    with SingleTickerProviderStateMixin {
  // الإعدادات والفيزياء الحية.
  Faraday1Config _cfg = const Faraday1Config();
  Faraday1State _st = const Faraday1State();
  final Faraday1Recorder _recorder = Faraday1Recorder();
  Faraday1Drive _drive = Faraday1Drive.none;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _acc = 0.0;

  // السحب الحي (سرعة الإيد مع تنعيم — كما بالمعتمد).
  bool _dragging = false;
  double _lastDragX = 0.0;
  int _lastDragMs = 0;

  // منهجية POE.
  int _stage = 0; // ٠ = توقّع · ١ = لاحِظ/اشرح
  int? _prediction;
  bool _predictWrong = false;

  // التحدّي (سقف يومي لكل تجربة — labChallengeDays).
  TrainingData _data = const TrainingData();
  bool _challengeDoneToday = false;
  bool _challengeAnnounced = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _challengeDoneToday =
        _data.labChallengeDays['faraday1'] == dateKeyOf(DateTime.now());
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.stop();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dtReal = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final replay = _recorder.replay;
    if (replay != null) {
      // الإعادة بزمن الحائط — المحاكاة متوقفة أثناءها (المعتمد v1.1).
      final r2 = replay.advance(dtReal);
      _recorder.replay = r2.done ? null : r2;
    } else {
      _acc += dtReal;
      while (_acc >= simDt) {
        _acc -= simDt;
        _st = _st.step(cfg: _cfg, drive: _drive, dragging: _dragging);
        _recorder.feed(
          _st,
          epsN: _st.epsNormalized(_cfg),
          phi: _st.phiOf(_cfg),
        );
      }
      // وصول الحاجز ⇒ إطفاء زر الحركة المضيء.
      if (_drive != Faraday1Drive.none &&
          (_st.magnetAtCoilStop || _st.magnetAtFarStop)) {
        _drive = Faraday1Drive.none;
      }
      if (_recorder.challengeDone && !_challengeAnnounced) {
        _challengeAnnounced = true;
        HapticFeedback.mediumImpact(); // لمسية الفوز — لموصلية المرحلة أ
      }
    }
    if (mounted) setState(() {});
  }

  void _dragTo(double logicalX, int msNow) {
    // ⚠️ clamp يرجع num — .toDouble() إلزامي (علّة موثقة).
    final x = logicalX
        .clamp(faradayMagnetMinX, faradayMagnetMaxX)
        .toDouble();
    final dt = math.max((msNow - _lastDragMs) / 1000.0, 0.008);
    final inst = (x - _lastDragX) / dt;
    final v = _st.v * 0.7 + inst * 0.3; // تنعيم السرعة كما بالمعتمد
    _lastDragX = x;
    _lastDragMs = msNow;
    _st = Faraday1State(
      mx: x,
      v: v,
      ang: _st.ang,
      angV: _st.angV,
      t: _st.t,
    );
  }

  void _startDragging(double logicalX, int msNow) {
    _recorder.replay = null; // أي لمس يوقف الإعادة
    _dragging = true;
    _drive = Faraday1Drive.none;
    _lastDragX = logicalX.clamp(faradayMagnetMinX, faradayMagnetMaxX).toDouble();
    _lastDragMs = msNow;
  }

  Future<void> _recordChallenge() async {
    final today = dateKeyOf(DateTime.now());
    final updated = _data.copyWith(
      labChallengeDays: <String, String>{
        ..._data.labChallengeDays,
        'faraday1': today,
      },
    );
    await widget.trainingStore.save(updated);
    await widget.xpRecorder?.record(
      'labChallenge',
      extra: <String, dynamic>{'experimentId': 'faraday1'},
    );
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

    return Scaffold(
      appBar: AppBar(title: const Text('المختبر: فاراداي (١) — مغناطيس ووشيعة')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildSceneCard(txt),
          const SizedBox(height: 12),
          _buildControls(txt),
          const SizedBox(height: 12),
          _buildScopeCard(txt),
          const SizedBox(height: 12),
          _buildChips(txt),
          const SizedBox(height: 12),
          _buildChallengeCard(txt, gold),
          const SizedBox(height: 12),
          _buildExplainCard(txt),
          const SizedBox(height: 8),
          Text(
            'محاكاة حتمية بخطوة ١/٢٤٠ ث — ε = −N·dΦ/dt بمشتقّة تحليلية، '
            'والمقياس من القانون لا من أرقام مزيفة.',
            style: txt.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── المشهد الحي + بطاقة التوقّع فوقه ──
  Widget _buildSceneCard(TextTheme txt) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: faradaySceneW / faradaySceneH,
            child: GestureDetector(
              key: const Key('faraday-canvas'),
              // ⚠️ CustomPaint بلا child غير قابل للمس — opaque إلزامي
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _stage == 0
                  ? null
                  : (d) => _startDragging(
                      d.localPosition.dx * faradaySceneW / _sceneW,
                      DateTime.now().millisecondsSinceEpoch),
              onHorizontalDragUpdate: _stage == 0
                  ? null
                  : (d) => _dragTo(
                      d.localPosition.dx * faradaySceneW / _sceneW,
                      DateTime.now().millisecondsSinceEpoch),
              onHorizontalDragEnd: (_) => _dragging = false,
              onHorizontalDragCancel: () => _dragging = false,
              child: LayoutBuilder(
                builder: (context, box) {
                  _sceneW = box.maxWidth;
                  return CustomPaint(
                    painter: _FaradayScenePainter(
                      st: _st,
                      cfg: _cfg,
                      recorder: _recorder,
                      started: _stage >= 1,
                    ),
                  );
                },
              ),
            ),
          ),
          if (_stage == 0) Positioned.fill(child: _buildPredict(txt)),
        ],
      ),
    );
  }

  double _sceneW = faradaySceneW;

  Widget _buildPredict(TextTheme txt) {
    return Container(
      color: Colors.black.withValues(alpha: .35),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Card(
        color: AppColors.card,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('توقّع أولاً 🔮', style: txt.titleLarge),
              const SizedBox(height: 6),
              Text(
                'أقرّب المغناطيس بسرعة نحو الوشيعة ثم أوقفه عندها — '
                'ماذا يحدث لمؤشّر المقياس؟',
                style: txt.bodyLarge,
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < faraday1PredictOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: OutlinedButton(
                    onPressed: () => _answerPredict(i),
                    child: Text(faraday1PredictOptions[i]),
                  ),
                ),
              Text(
                _predictFeedback,
                style: txt.titleSmall?.copyWith(
                  color: _predictWrong ? AppColors.accent : const Color(0xFF538065),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _predictFeedback {
    if (_prediction == null) return '';
    return _predictWrong
        ? '✘ جرّب ولاحظ — انتبه لموضع المغناطيس لحظة الانحراف'
        : '✔ صحيح — القراءة تظهر فقط أثناء التغيّر';
  }

  void _answerPredict(int i) {
    if (_stage != 0) return;
    setState(() {
      _prediction = i;
      _predictWrong = i != faraday1PredictCorrect;
    });
    if (i == faraday1PredictCorrect) {
      HapticFeedback.selectionClick();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _stage = 1);
      });
    }
  }

  // ── أزرار التحكم ──
  Widget _buildControls(TextTheme txt) {
    final active = _drive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              key: const Key('faraday-polarity'),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _cfg = _cfg.flipPolarity());
              },
              child: Text(_cfg.polarity > 0
                  ? 'وجه الوشيعة ← قطب N'
                  : 'وجه الوشيعة ← قطب S'),
            ),
            // منزلق اللفات N (خطوة ٥ — قيم نظيفة).
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('N = ${ArabicNumber.from(_cfg.turns)}',
                    style: txt.titleSmall),
                IconButton(
                  tooltip: 'إنقاص اللفات',
                  onPressed: _cfg.turns > 5
                      ? () => setState(
                          () => _cfg = _cfg.withTurns(_cfg.turns - 5))
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _cfg.turns.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    onChanged: (v) =>
                        setState(() => _cfg = _cfg.withTurns(v.round())),
                  ),
                ),
                IconButton(
                  tooltip: 'زيادة اللفات',
                  onPressed: _cfg.turns < 30
                      ? () => setState(
                          () => _cfg = _cfg.withTurns(_cfg.turns + 5))
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            OutlinedButton(
              onPressed: _stage == 0 ? null : () => _setDrive(Faraday1Drive.slow),
              style: _driveStyle(active == Faraday1Drive.slow),
              child: const Text('اقتراب بطيء'),
            ),
            OutlinedButton(
              onPressed: _stage == 0 ? null : () => _setDrive(Faraday1Drive.fast),
              style: _driveStyle(active == Faraday1Drive.fast),
              child: const Text('اقتراب سريع'),
            ),
            OutlinedButton(
              onPressed: _stage == 0 ? null : () => _setDrive(Faraday1Drive.away),
              style: _driveStyle(active == Faraday1Drive.away),
              child: const Text('إبعاد'),
            ),
            FilledButton(
              key: const Key('faraday-replay'),
              onPressed: _recorder.canReplay
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(_recorder.startReplay);
                    }
                  : null,
              child: const Text('⏺ إعادة آخر ٣ث ×٠٫٢٥'),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                _drive = Faraday1Drive.none;
                _st = const Faraday1State();
                _recorder.reset();
              }),
              child: const Text('↺ إعادة'),
            ),
          ],
        ),
      ),
    );
  }

  void _setDrive(Faraday1Drive d) {
    setState(() {
      _recorder.replay = null;
      _drive = _drive == d ? Faraday1Drive.none : d;
      _st = Faraday1State(
        mx: _st.mx,
        v: 0,
        ang: _st.ang,
        angV: _st.angV,
        t: _st.t,
      );
    });
  }

  ButtonStyle _driveStyle(bool active) => OutlinedButton.styleFrom(
        side: active
            ? const BorderSide(color: AppColors.accent, width: 2)
            : null,
      );

  // ── الراسم ε(t)/Φ(t) ──
  Widget _buildScopeCard(TextTheme txt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: faradaySceneW / 150,
              child: CustomPaint(
                painter: _FaradayScopePainter(recorder: _recorder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── شارات أعلى قراءة/تحدٍّ ──
  Widget _buildChips(TextTheme txt) {
    final pct = (_recorder.peakHold.abs() * 100).round();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Chip(
          label: Text(_recorder.peakHold == 0
              ? 'أعلى قراءة: —'
              : 'أعلى قراءة: ${_arDec(pct)}٪'),
          visualDensity: VisualDensity.compact,
        ),
        Chip(
          label: Text(_recorder.challengeDone
              ? '🏆 التحدي مُنجَز'
              : 'التحدّي: دفعة ≥ ٦٠٪ يمين ثم يسار'),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  // ── تحدّي الانحرافين المتعاكسين (+١٠ بسقف يومي) ──
  Widget _buildChallengeCard(TextTheme txt, Color gold) {
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
            Text('🎯 التحدي: انحرافان متعاكسان ≥ ٦٠٪', style: txt.titleLarge),
            const SizedBox(height: 6),
            Text(
              'قرّب بسرعة ثم أبعد (أو اعكس القطبية) — سجّل دفعة موجبة '
              'وسالبة فوق ٦٠٪ من المقياس في الجلسة نفسها.',
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (_challengeDoneToday)
              Text('✓ سُجّل اليوم — +١٠ نقطة لدوري فيزيا كلاش',
                  style: txt.titleMedium?.copyWith(color: gold),
                  textAlign: TextAlign.center)
            else if (_recorder.challengeDone) ...[
              Text('🎯 تحقّق! انحرافان متعاكسان فوق ٦٠٪',
                  style: txt.titleMedium?.copyWith(color: gold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _recordChallenge,
                child: const Text('سجّل التحدي (+١٠)'),
              ),
            ] else
              Text('جرّب: اقتراب سريع ثم إبعاد — أو اعكس القطبية',
                  style: txt.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── اشرح — يُفتح بعد أول انحراف ملموس (منهجية POE) ──
  Widget _buildExplainCard(TextTheme txt) {
    if (!_recorder.explained) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '«اشرح» يُفتح بعد أول قياس — حرّك المغناطيس وراقب المقياس.',
                  style: txt.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اشرح — ربط الملاحظة بالقانون', style: txt.titleLarge),
            const SizedBox(height: 6),
            Center(
              child: Text(faraday1Law,
                  style: txt.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic, color: AppColors.accent)),
            ),
            const SizedBox(height: 6),
            for (final b in faraday1ExplainBullets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(b, style: txt.bodyLarge)),
                  ],
                ),
              ),
            if (_prediction != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _prediction == faraday1PredictCorrect
                      ? 'توقعك كان مطابقاً للملاحظة ✓'
                      : 'الآن ترى لماذا الصحيح «ينحرف لحظة التغيّر ثم يعود للصفر»',
                  style: txt.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ الرسّامات — المشهد المنطقي 960×440 كما بالمعتمد ═══════════════

const Color _accent = AppColors.accent; // ‎#DD6E42
const Color _cream = Color(0xFFEEE7DE);
const Color _sand = Color(0xFFCBB79E);
const Color _muted = Color(0xFFB3A79B);
const Color _north = Color(0xFFB8543F);
const Color _south = Color(0xFF4A6D8C);
const Color _err = Color(0xFFBB5A45);

/// كتابة عربية على الكانفس.
void _arText(Canvas c, String s, Offset p,
    {double size = 14, required Color col, bool right = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: size, color: col, height: 1.15),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final dx = right ? p.dx - tp.width : p.dx - tp.width / 2;
  tp.paint(c, Offset(dx, p.dy));
}

/// أرقام عربية مع فاصلة عشرية عربية (٫) وشرطة سالبة (−).
String _arDec(num v) {
  final sb = StringBuffer();
  for (final ch in v.toString().split('')) {
    final i = int.tryParse(ch);
    if (i != null) {
      sb.write('٠١٢٣٤٥٦٧٨٩'[i]);
    } else if (ch == '.') {
      sb.write('٫');
    } else if (ch == '-') {
      sb.write('−');
    } else {
      sb.write(ch);
    }
  }
  return sb.toString();
}

/// تقطيع مسار إلى شرطات (بلا فصول UI) — للخيوط وحلقة التيار.
Path _dashPath(Path src, double on, double off, double phase) {
  final out = Path();
  final period = on + off;
  for (final m in src.computeMetrics()) {
    var d = phase % period;
    if (d < 0) d += period;
    var start = -d;
    while (start < m.length) {
      final s = start < 0 ? 0.0 : start;
      final e = (start + on).clamp(0.0, m.length).toDouble();
      if (e > s) out.addPath(m.extractPath(s, e), Offset.zero);
      start += period;
    }
  }
  return out;
}

class _FaradayScenePainter extends CustomPainter {
  const _FaradayScenePainter({
    required this.st,
    required this.cfg,
    required this.recorder,
    required this.started,
  });

  final Faraday1State st;
  final Faraday1Config cfg;
  final Faraday1Recorder recorder;
  final bool started;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / faradaySceneW;
    canvas.save();
    canvas.scale(scale);
    const W = faradaySceneW;
    const H = faradaySceneH;
    const cy = 220.0;
    final u = st.u;
    final phi = st.phiOf(cfg);
    final epsN = st.epsNormalized(cfg);

    _paintPanel(canvas, W, H);

    // ── عدّاد التدفق Φ (يسار المشهد) ──
    const gx = 34.0, gy = 120.0, gw = 24.0, gh = 210.0;
    canvas.drawRect(
      Rect.fromLTWH(gx, gy, gw, gh),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _cream.withValues(alpha: .35),
    );
    final fh = gh * phi.abs().clamp(0.0, 1.0).toDouble();
    if (fh > 0.5) {
      canvas.drawRect(
        Rect.fromLTWH(gx + 2, gy + gh - fh, gw - 4, fh),
        Paint()..color = _sand.withValues(alpha: .75),
      );
    }
    _arText(canvas, 'Φ', Offset(gx + gw / 2, gy - 30), size: 17, col: _cream);
    _arText(canvas, '${_arDec((phi.abs() * 100).round())}٪',
        Offset(gx + gw / 2, gy + gh + 8), size: 13, col: _muted);

    // ── الوشيعة (٥ ملفات — الأوسط بلون الهوية) ──
    final stand = Paint()
      ..color = _cream.withValues(alpha: .3)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(faradayCoilX - 40, cy + 110),
        Offset(faradayCoilX + 40, cy + 110), stand);
    canvas.drawLine(Offset(faradayCoilX, cy + 80),
        Offset(faradayCoilX, cy + 110), stand);
    for (var i = 4; i >= 0; i--) {
      final r = Rect.fromCenter(
        center: Offset(faradayCoilX + i * 7.0 - 14, cy),
        width: 44,
        height: 168,
      );
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 2 ? 3.5 : 2.5
        ..color = i == 2 ? _accent : const Color(0xFFB87333).withValues(alpha: .55);
      canvas.drawOval(r, p);
    }
    _arText(canvas, 'الوشيعة N=${ArabicNumber.from(cfg.turns)}',
        Offset(faradayCoilX, cy + 128), size: 14, col: _muted);

    // ── خيوط التدفق بين المغناطيس والوشيعة (متحركة — السحب يحرّكها) ──
    if (u < 1.7) {
      final faceMx = st.mx - faradayMagnetLen / 2;
      final phase = st.t * 30 - st.v * 0.04; // جُرّ الخيوط مع الحركة
      final alpha = (0.14 + 0.5 * phi.abs().clamp(0.0, 1.0).toDouble()) *
          (st.v.abs() > 1 ? 1.0 : 0.6);
      for (final dy in const [-56.0, -28.0, 0.0, 28.0, 56.0]) {
        final path = Path()
          ..moveTo(faceMx, cy + dy * 0.55)
          ..quadraticBezierTo(
              (faceMx + faradayCoilX + 26) / 2, cy + dy, faradayCoilX + 26,
              cy + dy);
        canvas.drawPath(
          _dashPath(path, 9, 7, phase),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _accent.withValues(alpha: alpha),
        );
      }
    }

    // ── خطوط مجال ثنائي القطب (r = r0·sin²θ) ──
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, 690, H));
    final sgn = cfg.polarity > 0 ? -1.0 : 1.0;
    for (final r0 in const [46.0, 76.0, 108.0, 142.0]) {
      for (final mir in const [1.0, -1.0]) {
        final path = Path();
        var first = true;
        for (var th = 0.28; th <= math.pi - 0.28; th += 0.09) {
          final r = r0 * math.sin(th) * math.sin(th);
          final axn = r * math.cos(th);
          final perp = mir * r * math.sin(th);
          final p = Offset(st.mx + sgn * axn, cy + perp);
          if (first) {
            path.moveTo(p.dx, p.dy);
            first = false;
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = _cream.withValues(alpha: .13),
        );
      }
    }
    canvas.restore();

    // ── أسهم/حلقة التيار المتحرّض + شارة وجه مستحثّ (لينز بصري) ──
    if (epsN.abs() > 0.03) {
      final dir = (epsN.sign) * (cfg.polarity > 0 ? 1.0 : -1.0);
      final ring = Path()
        ..addOval(Rect.fromCenter(
          center: Offset(faradayCoilX + 21, cy),
          width: 48,
          height: 172,
        ));
      final ringPhase = st.t * 120 * dir;
      canvas.drawPath(
        _dashPath(ring, 12, 9, ringPhase),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..color = _accent,
      );
      final approaching = st.v < 0;
      final face = cfg.polarity > 0
          ? (approaching ? 'N' : 'S')
          : (approaching ? 'S' : 'N');
      canvas.drawCircle(
          Offset(faradayCoilX, cy - 118),
          16,
          Paint()..color = face == 'N' ? _north : _south);
      _arText(canvas, face, Offset(faradayCoilX, cy - 127),
          size: 15, col: const Color(0xFFFFF6EC));
      _arText(canvas, 'الوجه المُستحثّ', Offset(faradayCoilX, cy - 158),
          size: 12, col: _muted);
    }

    // ── المغناطيس ──
    const magH = 26.0;
    const hw = faradayMagnetLen / 2;
    final leftRect = Rect.fromLTWH(st.mx - hw, cy - magH / 2, hw, magH);
    final rightRect = Rect.fromLTWH(st.mx, cy - magH / 2, hw, magH);
    canvas.drawRect(leftRect, Paint()..color = cfg.polarity > 0 ? _north : _south);
    canvas.drawRect(rightRect, Paint()..color = cfg.polarity > 0 ? _south : _north);
    canvas.drawRect(
      Rect.fromLTWH(st.mx - hw, cy - magH / 2, faradayMagnetLen, magH),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFF6EC).withValues(alpha: .35),
    );
    _arText(canvas, 'N', Offset(st.mx - hw / 2, cy - 8),
        size: 15, col: const Color(0xFFFFF6EC));
    _arText(canvas, 'S', Offset(st.mx + hw / 2, cy - 8),
        size: 15, col: const Color(0xFFFFF6EC));

    // ── سهم السرعة v ──
    if (st.v.abs() > 12) {
      final l = (st.v * 0.14).clamp(-46.0, 46.0).toDouble();
      const y = cy - 34;
      canvas.drawLine(Offset(st.mx, y), Offset(st.mx + l, y),
          Paint()..strokeWidth = 2.4..color = _cream);
      final sgn2 = l.sign;
      final tip = Path()
        ..moveTo(st.mx + l, y)
        ..lineTo(st.mx + l - sgn2 * 7, y - 4)
        ..lineTo(st.mx + l - sgn2 * 7, y + 4)
        ..close();
      canvas.drawPath(tip, Paint()..color = _cream);
      _arText(canvas, 'v', Offset(st.mx + l + (l > 0 ? 10 : -10), y - 22),
          size: 14, col: _cream);
    }
    _arText(canvas, 'اسحبني ↔', Offset(st.mx, cy + 30), size: 12,
        col: _cream.withValues(alpha: .45));

    _paintGalvanometer(canvas, cy);
    _paintHud(canvas, W, H, epsN);
    canvas.restore();
  }

  /// لوحة الجهاز: تدرّج + ضوء محيطي + شبكة ١١/٤٤ + مسطرة + vignette.
  void _paintPanel(Canvas canvas, double W, double H) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, H),
          [const Color(0xFF1D2721), const Color(0xFF0D130F)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(W * .32, H * .42),
          W * .55,
          [const Color(0x1ADD6E42), const Color(0x00DD6E42)],
        ),
    );
    final thin = Paint()..strokeWidth = 1;
    for (var x = 0.0; x < W; x += 11) {
      thin.color = x % 44 < 0.5
          ? _cream.withValues(alpha: .08)
          : _cream.withValues(alpha: .035);
      canvas.drawLine(Offset(x, 0), Offset(x, H), thin);
    }
    for (var y = 0.0; y < H; y += 11) {
      thin.color = y % 44 < 0.5
          ? _cream.withValues(alpha: .08)
          : _cream.withValues(alpha: .035);
      canvas.drawLine(Offset(0, y), Offset(W, y), thin);
    }
    thin.color = _cream.withValues(alpha: .22);
    for (var x = 0.0; x < W; x += 11) {
      final long = x % 44 < 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, long ? 7.0 : 4.0), thin);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(W / 2, H / 2),
          W * .72,
          [const Color(0x00000000), const Color(0x61000000)],
        ),
    );
  }

  /// الجلفانومتر صفر-الوسط: قوس ومدرّج وذيول وقمّة وإبرة حيّة وقراءة رقمية.
  void _paintGalvanometer(Canvas canvas, double cy) {
    const gxp = 700.0, gyp = 60.0, gwp = 250.0, ghp = 320.0;
    final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(gxp, gyp, gwp, ghp), const Radius.circular(14));
    canvas.drawRRect(box, Paint()..color = Colors.black.withValues(alpha: .28));
    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _cream.withValues(alpha: .18));

    const pvx = gxp + gwp / 2, pvy = gyp + ghp - 52.0;
    const R = ghp - 118.0;
    const span = 0.85;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(pvx, pvy), radius: R),
        -math.pi / 2 - span,
        2 * span,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _cream.withValues(alpha: .4));
    for (var k = -4; k <= 4; k++) {
      final a = -math.pi / 2 + k * span / 4;
      canvas.drawLine(
        Offset(pvx + math.cos(a) * (R - 8), pvy + math.sin(a) * (R - 8)),
        Offset(pvx + math.cos(a) * R, pvy + math.sin(a) * R),
        Paint()
          ..strokeWidth = k == 0 ? 2.4 : 1.4
          ..color = k == 0 ? _accent : _cream.withValues(alpha: .5),
      );
    }
    const aEnd = -math.pi / 2 + span;
    _arText(
        canvas, '٪+',
        Offset(pvx + R * math.cos(aEnd) + 4, pvy + R * math.sin(aEnd) - 20),
        size: 13,
        col: const Color(0xFF7FB08D));
    const aNeg = -math.pi / 2 - span;
    _arText(
        canvas, '٪−',
        Offset(pvx + R * math.cos(aNeg) - 20, pvy + R * math.sin(aNeg) - 20),
        size: 13,
        col: _err);
    _arText(canvas, 'المقياس (جلفانومتر)', Offset(pvx, gyp + 12),
        size: 13.5, col: _muted);

    // ذيول فوسفورية ثم قمّة باهتة ثم الإبرة الحيّة.
    for (final g in recorder.ghosts) {
      final age = ((st.t - g.t) / 0.9).clamp(0.0, 1.0).toDouble();
      _needle(canvas, pvx, pvy, R - 4, g.ang,
          _accent.withValues(alpha: .30 * (1 - age)), 2);
    }
    if (recorder.peakHold != 0) {
      _needle(canvas, pvx, pvy, R - 16, recorder.peakHold,
          _cream.withValues(alpha: .35), 1.5);
    }
    _needle(canvas, pvx, pvy, R - 4, st.ang, _accent, 3.4);

    // إبرة شبح أثناء الإعادة البطيئة.
    final replay = recorder.replay;
    if (replay != null) {
      final s = recorder.sampleAt(replay.t0 + replay.progress);
      if (s != null) {
        _needle(canvas, pvx, pvy, R - 4, s.ang,
            const Color(0xFFFFF6EC).withValues(alpha: .85), 2);
      }
      _arText(canvas, 'إعادة بطيئة ×٠٫٢٥', Offset(gxp + 14, gyp + 12),
          size: 12, col: _cream, right: false);
    }

    canvas.drawCircle(
        Offset(pvx, pvy),
        7,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(pvx - 2.5, pvy - 3),
            7,
            [const Color(0xFFFFF6EC), _accent, const Color(0xFF1A120D)],
          ));
    final shown = st.ang >= 0 ? '＋' : '−';
    _arText(
        canvas,
        '$shown${_arDec((st.ang.abs() * 100).round())}',
        Offset(pvx, gyp + ghp - 30),
        size: 20,
        col: _cream);
  }

  void _needle(Canvas c, double x, double y, double len, double ang,
      Color col, double w) {
    // ⚠️ clamp يرجع num — .toDouble() إلزامي (علّة موثقة).
    final a = ang.clamp(-1.0, 1.0).toDouble();
    final th = -math.pi / 2 + a * 0.82;
    c.drawLine(
      Offset(x, y),
      Offset(x + math.cos(th) * len, y + math.sin(th) * len),
      Paint()
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = col,
    );
  }

  void _paintHud(Canvas c, double W, double H, double epsN) {
    final pct = (epsN.abs() * 100).round();
    final vPct = ((st.v.abs() / 3).round());
    _arText(c, 'ε = ${_arDec(pct)}٪   ·   v = ${_arDec(vPct)}٪',
        Offset(W / 2, 14), size: 14, col: _muted);
    if (started &&
        st.v.abs() < 2 &&
        !recorder.challengeDone) {
      _arText(c, 'اسحب المغناطيس — أو استعمل أزرار الحركة التلقائية',
          Offset(W / 2, H - 30), size: 13.5, col: _cream.withValues(alpha: .4));
    }
  }

  @override
  bool shouldRepaint(covariant _FaradayScenePainter old) => true;
}

class _FaradayScopePainter extends CustomPainter {
  const _FaradayScopePainter({required this.recorder});

  final Faraday1Recorder recorder;

  @override
  void paint(Canvas canvas, Size size) {
    const W = faradaySceneW;
    const H = 150.0;
    final scale = size.width / W;
    canvas.save();
    canvas.scale(scale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..color = const Color(0xFF10160F),
    );
    final grid = Paint()..strokeWidth = 1;
    for (var x = 0.0; x < W; x += 32) {
      grid.color = _cream.withValues(alpha: .06);
      canvas.drawLine(Offset(x, 0), Offset(x, H), grid);
    }
    for (var y = 0.0; y < H; y += 25) {
      grid.color = _cream.withValues(alpha: .06);
      canvas.drawLine(Offset(0, y), Offset(W, y), grid);
    }
    grid.color = _cream.withValues(alpha: .25);
    canvas.drawLine(Offset(0, H / 2), Offset(W, H / 2), grid);
    _arText(canvas, 'ε(t) — القراءة الحيّة خلال ٦ ث', Offset(W - 10, 6),
        size: 13, col: _muted, right: true);

    final buf = recorder.buf;
    if (buf.length < 2) {
      canvas.restore();
      return;
    }
    final t1 = buf.last.t;
    final t0 = t1 - 6.0;
    double yOf(double v) => H / 2 - v * (H / 2 - 14);

    // ε(t) — الحيّة.
    final epsPath = Path();
    var first = true;
    for (final s in buf) {
      if (s.t < t0) continue;
      final x = (s.t - t0) / 6.0 * W;
      final y = yOf(s.epsN);
      if (first) {
        epsPath.moveTo(x, y);
        first = false;
      } else {
        epsPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
        epsPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = _accent);

    // Φ(t) — منقّطة رمزية.
    final phiPath = Path();
    first = true;
    for (final s in buf) {
      if (s.t < t0) continue;
      final x = (s.t - t0) / 6.0 * W;
      final y = yOf(s.phi.clamp(-1.0, 1.0).toDouble() * 0.85);
      if (first) {
        phiPath.moveTo(x, y);
        first = false;
      } else {
        phiPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
        _dashPath(phiPath, 6, 5, 0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _sand.withValues(alpha: .6));

    // مقطع الإعادة البطيئة — كريمي سميك.
    final replay = recorder.replay;
    if (replay != null) {
      final now = replay.t0 + replay.progress;
      final segPath = Path();
      first = true;
      for (final s in buf) {
        if (s.t < replay.t0) continue;
        if (s.t > now) break;
        final x = (s.t - t0) / 6.0 * W;
        final y = yOf(s.epsN);
        if (first) {
          segPath.moveTo(x, y);
          first = false;
        } else {
          segPath.lineTo(x, y);
        }
      }
      canvas.drawPath(
          segPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.4
            ..color = const Color(0xFFFFF6EC));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FaradayScopePainter old) => true;
}
