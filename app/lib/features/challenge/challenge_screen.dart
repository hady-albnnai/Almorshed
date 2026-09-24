import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/challenge/challenge_builder.dart';
import '../../core/content/math_text.dart';
import '../../core/content/models.dart';
import '../../core/training/batch_builder.dart';
import '../../core/util/arabic_number.dart';
import '../../core/xp/challenge_points.dart';
import '../../core/xp/streak_service.dart';

/// A5 — تحدي اليوم (قرار ٦٠): ١٠ أسئلة، مؤقّت لكل سؤال، نقاط تناقصية
/// مع الزمن، و**مغادرة التطبيق = إنهاء التحدي واحتسابه**.
///
/// ثلاث قواعد ملزمة من القرار:
/// 1. النقاط تناقصية داخل المهلة — تُحسب بالدالة الحتمية في
///    `core/xp/challenge_points.dart` (نفسها على السيرفر حرفياً).
/// 2. انتهاء الوقت أو إجابة خاطئة ⇒ **٠ نقطة** («لا نقاط بلا إجابة صحيحة»).
/// 3. `WidgetsBindingObserver`: أي خروج من الواجهة (`paused`/`hidden`/
///    `detached`) يُنهي التحدي فوراً ويُقفله بحدث `challengeAbandon`
///    — فلا تُفتح نقاط التحدي نفسه مرة ثانية لا محلياً ولا خادمياً.
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.pack,
    required this.xpRecorder,
    this.deviceId = 0,
  });

  final ContentPack pack;
  final XpRecorder xpRecorder;
  final int deviceId;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

/// أطوار الشاشة — الانتقال بينها صريح (لا قفز تلقائي).
enum _Phase { loading, playing, closed, already }

/// جواب مُسجَّل لسؤال واحد داخل التحدي.
class _Ans {
  const _Ans({
    required this.chosenIndex,
    required this.correctIndex,
    required this.elapsedMs,
    required this.points,
  });

  /// `null` ⇒ انتهى الوقت بلا اختيار.
  final int? chosenIndex;
  final int correctIndex;
  final int elapsedMs;

  /// ٠ عند الخطأ أو انتهاء الوقت.
  final int points;

  bool get correct => chosenIndex != null && chosenIndex == correctIndex;
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with WidgetsBindingObserver {
  DailyChallenge? _challenge;
  _Phase _phase = _Phase.loading;

  int _index = 0;
  final Map<int, _Ans> _answers = <int, _Ans>{};

  final Stopwatch _stop = Stopwatch();
  Timer? _ticker;
  bool _closed = false; // يمنع الإنهاء المزدوج (مؤقّت + مغادرة معاً)
  bool _abandoned = false; // أُنهِي بمغادرة التطبيق (لا بإتمام الأسئلة)
  bool _resolving = false; // يمنع دخولين متزامنين (نقرة + انقضاء المهلة)

  /// الصنف الحالي — الحزمة الآن اختياري من متعدد (قرار ٦٠: ٢٠–٢٥ ث).
  ChallengeKind get _kind => kChallengeMcq;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _stop.stop();
    super.dispose();
  }

  Future<void> _prepare() async {
    final dateKey = dateKeyOf(DateTime.now());
    final c = buildDailyChallenge(
      widget.pack,
      dateKey: dateKey,
      deviceId: widget.deviceId,
    );
    if (c == null) {
      if (!mounted) return;
      setState(() => _phase = _Phase.closed);
      return;
    }
    // القرار ٦٠: تحدي اليوم مرة واحدة — المعرّف حتمي، والتكرار يُردّ محلياً.
    final started = await widget.xpRecorder.ledger.challengeStarted(c.id);
    if (!mounted) return;
    setState(() {
      _challenge = c;
      _phase = started ? _Phase.already : _Phase.playing;
    });
    if (!started) _startQuestion();
  }

  void _startQuestion() {
    _stop
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (_stop.elapsedMilliseconds >= _kind.budgetMs) {
        _timeout();
      } else {
        setState(() {}); // تحديث العدّاد والنقاط المتاحة
      }
    });
  }

  int get _remainingMs {
    final r = _kind.budgetMs - _stop.elapsedMilliseconds;
    return r < 0 ? 0 : r;
  }

  int get _livePoints =>
      challengePoints(kind: _kind, elapsedMs: _stop.elapsedMilliseconds);

  Future<void> _timeout() => _resolve(null);

  Future<void> _choose(int displayIndex) async {
    if (_phase != _Phase.playing) return;
    await _resolve(displayIndex);
  }

  Future<void> _resolve(int? displayIndex) async {
    if (_phase != _Phase.playing || _closed || _resolving) return;
    _resolving = true;
    final c = _challenge;
    if (c == null) return;

    _stop.stop();
    _ticker?.cancel();

    final qid = c.session.questionIds[_index];
    final order = c.session.optionOrders[qid];
    final q = _questionOf(qid);
    if (q == null || order == null) return;

    final correctIndex = order.indexOf(q.correctIndex);
    final elapsedMs = _stop.elapsedMilliseconds;
    final isCorrect = displayIndex != null && displayIndex == correctIndex;
    final points =
        isCorrect ? challengePoints(kind: _kind, elapsedMs: elapsedMs) : 0;

    // النقاط التناقصية تُسجَّل مرة واحدة لكل (تحدي · سؤال) — السيرفر يرفض
    // التكرار، والخطأ لا يُسجَّل أصلاً (٠ نقطة بلا حدث).
    if (isCorrect) {
      await widget.xpRecorder.recordChallenge(
        challengeId: c.id,
        qIndex: _index,
        qType: _kind.id,
        elapsedMs: elapsedMs,
      );
    }

    if (!mounted) return;
    setState(() {
      _resolving = false;
      _answers[qid] = _Ans(
        chosenIndex: displayIndex,
        correctIndex: correctIndex,
        elapsedMs: elapsedMs,
        points: points,
      );
    });
  }

  Question? _questionOf(int qid) {
    for (final q in widget.pack.questions) {
      if (q.id == qid) return q;
    }
    return null;
  }

  Future<void> _next() async {
    final c = _challenge;
    if (c == null) return;
    if (_index + 1 >= c.session.questionIds.length) {
      await _close(finished: true);
      return;
    }
    setState(() => _index = _index + 1);
    _startQuestion();
  }

  /// إنهاء التحدي بمغادرة التطبيق (قرار ٦٠) — ٠ نقطة + إقفال التحدي.
  Future<void> _abandon(String reason) async {
    if (_closed) return;
    await _close(finished: false, reason: reason);
  }

  Future<void> _close({required bool finished, String reason = 'إتمام'}) async {
    if (_closed) return;
    _closed = true;
    _stop.stop();
    _ticker?.cancel();
    final c = _challenge;
    if (!finished) _abandoned = true;
    if (c != null && !finished) {
      await widget.xpRecorder.recordChallengeAbandon(
        challengeId: c.id,
        reason: reason,
      );
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.closed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // القرار ٦٠: «مغادرة التطبيق = إنهاء التحدي واحتسابه».
    if (state != AppLifecycleState.resumed &&
        _phase == _Phase.playing &&
        !_closed) {
      unawaited(_abandon('مغادرة التطبيق'));
    }
  }

  int get _totalPoints {
    var s = 0;
    for (final a in _answers.values) {
      s += a.points;
    }
    return s;
  }

  int get _correctCount =>
      _answers.values.where((a) => a.correct).length;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return PopScope(
      // الخروج بالإيماءة/الزر = مغادرة = إنهاء (نفس قاعدة القرار ٦٠).
      canPop: _phase != _Phase.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_abandon('خروج من التحدي'));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحدي اليوم'),
          actions: [
            IconButton(
              tooltip: 'كيف تُحسب النقاط؟',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showScoring(context),
            ),
          ],
        ),
        body: _buildBody(context, txt),
      ),
    );
  }

  void _showScoring(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كيف تُحسب النقاط؟'),
        content: const Text(
          'التحديات وحدها هي نقاط الترتيب الأسبوعي.\n\n'
          '• لكل سؤال مهلة ٢٢ ثانية.\n'
          '• تجيب أسرع ⇒ نقاط أكثر (من ١٢ نزولاً إلى ٤).\n'
          '• إجابة خاطئة أو انتهاء الوقت ⇒ ٠.\n'
          '• مغادرة التطبيق ⇒ ينتهي التحدي ويُحتسب، ولا يُعاد اليوم.\n\n'
          'التدريب والبطاقات نقاط تعلّم شخصية — لا تدخل الترتيب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme txt) => switch (_phase) {
      _Phase.loading => const Center(child: CircularProgressIndicator()),
      _Phase.already => const _Message(
          icon: Icons.lock_clock_outlined,
          title: 'أنهيت تحدي اليوم',
          body: 'التحدي مرة واحدة كل يوم — يعود غداً بمهلة جديدة.',
        ),
      _Phase.closed => _Result(
          total: _totalPoints,
          correct: _correctCount,
          answered: _answers.length,
          abandoned: _abandoned,
          onExit: () => Navigator.of(context).pop(),
        ),
      _Phase.playing => _questionView(txt),
    };

  Widget _questionView(TextTheme txt) {
    final c = _challenge!;
    final qid = c.session.questionIds[_index];
    final order = c.session.optionOrders[qid];
    final q = _questionOf(qid);
    if (q == null || order == null) {
      return const _Message(
        icon: Icons.error_outline,
        title: 'سؤال غير متوفر',
        body: 'أعد فتح التحدي من تبويب التحديات.',
      );
    }
    final ans = _answers[qid];
    final answered = ans != null;
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
    final remaining = _remainingMs;
    final fraction = remaining / _kind.budgetMs;

    return Column(
      children: [
        // شريط المهلة — يتناقص حيّاً مع النقاط المتاحة
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${ArabicNumber.from((remaining / 1000).ceil())} ث',
                style: txt.titleMedium?.copyWith(
                  color: remaining < 6000 ? Colors.red : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                answered
                    ? '+${ArabicNumber.from(ans.points)} نقطة'
                    : '+${ArabicNumber.from(_livePoints)} نقطة الآن',
                style: txt.titleMedium?.copyWith(
                  color: answered && ans.points > 0 ? Colors.green : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            color: remaining < 6000 ? Colors.red : null,
            minHeight: 6,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'سؤال ${ArabicNumber.from(_index + 1)} من '
              '${ArabicNumber.from(c.session.questionIds.length)}',
              style: txt.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MathText(q.stem, style: txt.titleMedium),
              const SizedBox(height: 14),
              for (var k = 0; k < order.length; k++)
                _OptionTile(
                  letter: letters[k],
                  text: q.options[order[k]],
                  state: !answered
                      ? _OptionState.idle
                      : (k == ans.correctIndex
                          ? _OptionState.correct
                          : (k == ans.chosenIndex
                              ? _OptionState.wrong
                              : _OptionState.dimmed)),
                  onTap: answered ? null : () => _choose(k),
                ),
              if (answered) ...[
                const SizedBox(height: 14),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ans.points > 0
                              ? '✅ أصبت — ${ArabicNumber.from(ans.points)} نقطة'
                              : (ans.chosenIndex == null
                                  ? '⏰ انتهى الوقت — ٠ نقطة'
                                  : '❌ خطأ — ٠ نقطة'),
                          style: txt.titleSmall,
                        ),
                        if (q.solutionSteps.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          for (var s = 0; s < q.solutionSteps.length; s++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${ArabicNumber.from(s + 1)}. '
                                '${q.solutionSteps[s]}',
                                style: txt.bodyMedium,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: answered ? _next : null,
                child: Text(
                  _index + 1 >= c.session.questionIds.length && answered
                      ? 'إنهاء التحدي'
                      : 'التالي ←',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(title, style: txt.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: txt.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.total,
    required this.correct,
    required this.answered,
    required this.abandoned,
    required this.onExit,
  });

  final int total;
  final int correct;
  final int answered;
  final bool abandoned;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final msg = abandoned
        ? 'غادرت التطبيق فانتهى التحدي — يُعاد غداً.'
        : correct == answered && answered > 0
            ? 'ما شاء الله — كلها صحيحة!'
            : 'راجع خطوات الحل في التدريب وعد غداً أقوى.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              abandoned ? Icons.exit_to_app : Icons.emoji_events_outlined,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              abandoned ? 'انتهى التحدي' : 'أنهيت تحدي اليوم!',
              style: txt.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${ArabicNumber.from(total)} نقطة',
              style: txt.displaySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${ArabicNumber.from(correct)} إجابة صحيحة من '
              '${ArabicNumber.from(answered)}',
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(msg, style: txt.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onExit, child: const Text('رجوع')),
          ],
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color? bg;
    Color? border;
    Icon? lead;
    switch (state) {
      case _OptionState.idle:
        break;
      case _OptionState.correct:
        bg = Colors.green.withValues(alpha: 0.15);
        border = Colors.green;
        lead = const Icon(Icons.check_circle_outline, color: Colors.green);
      case _OptionState.wrong:
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red;
        lead = const Icon(Icons.cancel_outlined, color: Colors.red);
      case _OptionState.dimmed:
        border = cs.outline.withValues(alpha: 0.3);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: bg ?? cs.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: ListTile(
          leading: lead ?? CircleAvatar(child: Text(letter)),
          title: MathText(text),
          onTap: onTap,
          enabled: onTap != null,
        ),
      ),
    );
  }
}
