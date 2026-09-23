// ═══════════════════════════════════════════════════════════════════════
// local_duel_screen.dart — واجهة المبارزة المحلية «بلا نت» (F5.4).
// نفس بنية شاشة المبارزة الحية لكن على النقلية المحلية (TCP نقطة اتصال/
// شبكة مشتركة): إعداد (إنشاء=مضيف / انضمام=ضيف بعنوان+رمز) ← لوبي (رمز +
// عنوان المضيف) ← لعب (قضبان + سلسلة) ← نتيجة (حكم محلي حتمي بلا XP).
// بلا سيرفر وبلا GMS — يعمل على أي جهاز. الأرقام عربية، الألوان core/theme.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/math_text.dart';
import '../../core/content/models.dart';
import '../../core/duel/duel_engine.dart';
import '../../core/duel/duel_flow.dart';
import '../../core/duel/local_duel_flow.dart';
import '../../core/duel/local_link.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/arabic_number.dart';
import '../review/review_widgets.dart';

/// مصنع تدفق مبارزة محلية — يحضّره main.dart بلا سيرفر.
typedef LocalDuelFlowFactory = LocalDuelFlow Function();

/// حروف الخيارات المعروضة — مطابقة أعراف الواجهة.
const List<String> _letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];

class LocalDuelScreen extends StatefulWidget {
  const LocalDuelScreen({
    super.key,
    required this.pack,
    required this.flowFactory,
  });

  final ContentPack pack;
  final LocalDuelFlowFactory flowFactory;

  @override
  State<LocalDuelScreen> createState() => _LocalDuelScreenState();
}

class _LocalDuelScreenState extends State<LocalDuelScreen> {
  LocalDuelFlow? _flow;
  StreamSubscription<DuelSnapshot>? _sub;
  DuelSnapshot? _snap;

  late final Map<int, Question> _byId = <int, Question>{
    for (final q in widget.pack.questions) q.id: q,
  };

  // ── نموذج الإعداد ──
  final Set<String> _units = <String>{};
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _ipCtrl = TextEditingController();
  bool _busy = false;
  String _setupError = '';
  String? _hostIpHint; // عنوان المضيف المكتشف تلقائياً

  @override
  void initState() {
    super.initState();
    _units.addAll(widget.pack.units.map((u) => u.id));
    unawaited(_detectIp());
  }

  Future<void> _detectIp() async {
    final ip = await detectHostIp();
    if (mounted) setState(() => _hostIpHint = ip);
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_flow?.dispose());
    _codeCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  void _onSnap(DuelSnapshot s) {
    if (!mounted) return;
    setState(() => _snap = s);
  }

  LocalDuelFlow _openFlow() {
    final f = widget.flowFactory();
    _sub = f.stream.listen(_onSnap);
    return f;
  }

  /// تنظيف وعودة لنموذج الإعداد (إلغاء/ثأر/خطأ).
  Future<void> _backToSetup() async {
    final f = _flow;
    _flow = null;
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _snap = null);
    if (f != null) await f.dispose();
  }

  Future<void> _onHost() async {
    if (_units.isEmpty) {
      setState(() => _setupError = 'اختر وحدة واحدة على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _setupError = '';
    });
    try {
      final flow = _openFlow();
      _flow = flow;
      final units = _units.toList()..sort();
      await flow.host(units: units, packTag: widget.pack.packId);
    } catch (_) {
      await _backToSetup();
      if (mounted) {
        setState(
          () => _setupError = 'تعذر فتح نقطة الاتصال — فعّلها ثم أعد المحاولة',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onJoin() async {
    final code = _codeCtrl.text.trim();
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _setupError = 'أدخل عنوان المضيف (مثل 192.168.43.1)');
      return;
    }
    if (code.isEmpty) {
      setState(() => _setupError = 'أدخل الرمز المكوّن من ٦ محارف');
      return;
    }
    setState(() {
      _busy = true;
      _setupError = '';
    });
    try {
      final flow = _openFlow();
      _flow = flow;
      await flow.join(
        hostIp: ip,
        port: TcpDuelTransport.defaultPort,
        code: code,
      );
    } catch (_) {
      await _backToSetup();
      if (mounted) {
        setState(() => _setupError = 'تعذر الاتصال — تحقق من العنوان والرمز');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(int i, int k) async {
    final s = _snap;
    if (s == null || s.phase != DuelPhase.live) return;
    if (i != s.currentIndex) return; // نقرة قديمة
    await _flow?.submitAnswer(k);
  }

  Future<void> _start() async {
    await _flow?.start();
  }

  Future<void> _cancel() async {
    final f = _flow;
    if (f != null) await f.cancel();
    if (!mounted) return;
    await _backToSetup();
  }

  Future<void> _copy(String text, String doneMsg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(doneMsg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = _snap;
    if (s == null) return _buildSetup();
    return switch (s.phase) {
      DuelPhase.idle => _buildSetup(),
      DuelPhase.creating => _buildBusy(s),
      DuelPhase.lobby => _buildLobby(s),
      DuelPhase.live => _buildPlay(s),
      DuelPhase.finished => _buildResult(s),
      DuelPhase.failed => _buildError(s),
    };
  }

  // ═════════════ الإعداد: إنشاء (مضيف) / انضمام (ضيف) ═════════════
  Widget _buildSetup() {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مبارزة محلية — بلا نت 📡')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('أنشئ المبارزة (مضيف)', style: txt.titleLarge),
          const SizedBox(height: 4),
          Text(
            'فعّل نقطة الاتصال على جهازك، واختر الوحدات — تُولّد الأسئلة '
            'من بذرة واحدة لك ولصديقك بلا إنترنت وبلا سيرفر.',
            style: txt.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.pack.units.length; i++)
                _UnitChip(
                  label:
                      '${ArabicNumber.from(i + 1)} · ${widget.pack.units[i].title}',
                  selected: _units.contains(widget.pack.units[i].id),
                  onToggle: () {
                    setState(() {
                      final id = widget.pack.units[i].id;
                      if (!_units.remove(id)) _units.add(id);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('📡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${ArabicNumber.from(DuelConstants.count)} أسئلة · '
                      '${ArabicNumber.from(DuelConstants.questionSeconds)} ثانية '
                      'لكل سؤال · الحكم محلي على جهاز المضيف · بلا نقاط XP',
                      style: txt.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _busy ? null : _onHost,
            child: const Text('إنشاء المبارزة ⚔️'),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('أو', style: txt.bodyMedium),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          Text('انضم لمبارزة (ضيف)', style: txt.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _ipCtrl,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              hintText: _hostIpHint ?? '192.168.43.1',
              hintTextDirection: TextDirection.ltr,
              labelText: 'عنوان المضيف (من نقطة اتصاله)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _codeCtrl,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: 'K7M2PX',
              hintTextDirection: TextDirection.ltr,
              labelText: 'الرمز (٦ محارف)',
            ),
            onSubmitted: (_) => _onJoin(),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _onJoin,
            child: const Text('الانضمام ⚔️'),
          ),
          if (_setupError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _setupError,
              style: txt.bodyMedium?.copyWith(color: _danger(context)),
              textAlign: TextAlign.center,
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  // ═════════════ جارٍ الإنشاء/الانضمام ═════════════
  Widget _buildBusy(DuelSnapshot s) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              s.isHost ? 'جارٍ فتح الاستماع…' : 'جارٍ الاتصال بالمضيف…',
              style: txt.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════ اللوبي: انتظار الخصم ═════════════
  Widget _buildLobby(DuelSnapshot s) {
    final txt = Theme.of(context).textTheme;
    final isHost = s.isHost;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            const Text('📡', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Text(
              isHost ? 'بانتظار الخصم…' : 'بانتظار بدء المضيف…',
              style: txt.titleLarge,
            ),
            const SizedBox(height: 10),
            if (s.roomCode != null)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  s.roomCode!,
                  style: txt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              isHost
                  ? 'أرسل العنوان والرمز لصديقك — يظهر فور دخوله'
                  : 'سينطلق السؤال الأول فور بدء المضيف',
              style: txt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (isHost) ...[
              const SizedBox(height: 8),
              Text(
                'عنوانك في نقطة الاتصال: ${_hostIpHint ?? '192.168.43.1'}',
                textDirection: TextDirection.ltr,
                style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (s.roomCode != null)
                OutlinedButton.icon(
                  onPressed: () => _copy(
                    '${_hostIpHint ?? '192.168.43.1'} · ${s.roomCode!}',
                    'نُسخ العنوان والرمز',
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ العنوان والرمز'),
                ),
            ],
            const SizedBox(height: 6),
            Text(
              '🟢 متصل محلياً — الأسئلة تتولّد من البذرة المشتركة',
              style: txt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (s.questionIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'بصمة الأسئلة: '
                '${questionsFingerprint(s.questionIds, s.optionOrders)}',
                textDirection: TextDirection.ltr,
                style: txt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'تطابق البصمة على الجهازين = نفس الأسئلة',
                style: txt.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            if (isHost && s.opponentJoined)
              FilledButton(
                onPressed: _start,
                child: const Text('دخل الخصم! ابدأ ⚔️'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _cancel, child: const Text('إلغاء')),
          ],
        ),
      ),
    );
  }

  // ═════════════ اللعب الحي ═════════════
  Widget _buildPlay(DuelSnapshot s) {
    final txt = Theme.of(context).textTheme;
    final i = s.currentIndex;
    final total = s.questionCount;
    final q = _qAt(i);
    final opts = _optsAt(i);
    final mult = s.myStreak >= 6 ? 3 : (s.myStreak >= 3 ? 2 : 1);
    final lowTime = s.remainingSeconds <= 5;
    final oppName = s.opponentName ?? 'الخصم';
    final seconds = s.remainingSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مبارزة محلية ⚔️'),
        actions: [
          if (q != null)
            ReviewNoteButton(kind: 'q', itemId: '${q.id}', preview: q.stem),
          IconButton(
            tooltip: 'إنهاء',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── شريط المواجهة ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: _PlayerBar(
                    name: 'أنت',
                    avatarLetter: 'أ',
                    color: _brand(context),
                    answered: i,
                    total: total,
                    score: s.myScore,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ضد',
                    style: txt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: _PlayerBar(
                    name: oppName,
                    avatarLetter: oppName.isNotEmpty
                        ? oppName.substring(0, 1)
                        : 'خ',
                    color: _brand2(context),
                    answered: s.oppAnswered,
                    total: total,
                    score: s.oppScore,
                  ),
                ),
              ],
            ),
          ),
          // ── شرائح الحالة ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusChip(
                  label:
                      'السؤال ${ArabicNumber.from(i + 1)}/${ArabicNumber.from(total)}',
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: '⏱ ${ArabicNumber.from(seconds)} ث',
                  color: lowTime ? _danger(context) : null,
                ),
                if (mult > 1) ...[
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: '🔥 سلسلة ×${ArabicNumber.from(mult)}',
                    color: _gold(context),
                  ),
                ],
              ],
            ),
          ),
          // ── السؤال والخيارات ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (q == null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'جارٍ التزامن مع الخصم…',
                          style: txt.titleMedium,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PendingBadge(questionId: q.id),
                          MathText(q.stem, style: txt.titleMedium),
                          const SizedBox(height: 12),
                          for (var k = 0; k < opts.length; k++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _OptionTile(
                                letter: _letters[k],
                                text: opts[k],
                                onTap: () => _answer(i, k),
                              ),
                            ),
                          if (s.oppAnswered > i) ...[
                            const SizedBox(height: 10),
                            Text(
                              '$oppName أجاب عن هذا السؤال ✅',
                              style: txt.bodyMedium,
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
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (i / total).clamp(0, 1),
                        minHeight: 10,
                        backgroundColor: Theme.of(context).dividerColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _brand(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${ArabicNumber.from(i)}/${ArabicNumber.from(total)}',
                    style: txt.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════ النتيجة ═════════════
  Widget _buildResult(DuelSnapshot s) {
    final txt = Theme.of(context).textTheme;
    final v = s.verdict!;
    final iAmHost = s.isHost;
    final myScore = iAmHost ? v.hostScore : v.guestScore;
    final oppScore = iAmHost ? v.guestScore : v.hostScore;
    final won = s.iWon;
    // `v.corrects` مفتاح الحكم لا عدد صحيحاتي — أحسب صحيحاتي بالمطابقة.
    var myCorrects = 0;
    final key = v.corrects;
    final mine = s.myAnswers;
    for (var i = 0; i < mine.length && i < key.length; i++) {
      if (mine[i] != null && mine[i] == key[i]) myCorrects++;
    }
    final oppName = s.opponentName ?? 'الخصم';

    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة المبارزة ⚔️')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Text(
              won ? '🏆' : '😤',
              style: const TextStyle(fontSize: 56),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              won ? 'فزت! 🎉' : 'خسرت هذه الجولة — الثأر قريب',
              style: txt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: _brand(context),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ScoreBlock(
                        name: 'أنت',
                        score: myScore,
                        sub:
                            '${ArabicNumber.from(myCorrects)}/'
                            '${ArabicNumber.from(s.questionCount)}',
                        color: _brand(context),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text('—', style: txt.headlineSmall),
                      ),
                      _ScoreBlock(
                        name: oppName,
                        score: oppScore,
                        sub:
                            '${ArabicNumber.from(s.oppCorrects)}/'
                            '${ArabicNumber.from(s.questionCount)}',
                        color: _brand2(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'مبارزة تدريب محلية — بلا نقاط XP',
                    style: txt.titleMedium?.copyWith(
                      color: _brand(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _backToSetup,
            child: const Text('مبارزة الثأر 😤'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copy(
              '⚔️ مبارزة فيزيا كلاش المحلية — ${won ? 'فزت' : 'خسرت'} '
                  '(${ArabicNumber.from(myScore)} مقابل ${ArabicNumber.from(oppScore)})',
              'نُسخت النتيجة — شاركها مع صديقك',
            ),
            icon: const Icon(Icons.ios_share),
            label: const Text('مشاركة النتيجة 📣'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('الرجوع للرئيسية'),
          ),
        ],
      ),
    );
  }

  // ═════════════ خطأ ═════════════
  Widget _buildError(DuelSnapshot s) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 52, color: _danger(context)),
              const SizedBox(height: 12),
              Text('تعذرت المبارزة', style: txt.titleLarge),
              const SizedBox(height: 8),
              Text(
                s.error.isEmpty ? 'حدث خطأ غير متوقع' : s.error,
                textAlign: TextAlign.center,
                style: txt.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _backToSetup,
                child: const Text('محاولة جديدة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── أدوات الأسئلة ──
  Question? _qAt(int i) {
    final s = _snap;
    if (s == null || i >= s.questionIds.length) return null;
    return _byId[s.questionIds[i]];
  }

  List<String> _optsAt(int i) {
    final s = _snap;
    if (s == null || i >= s.questionIds.length) return const [];
    final qid = s.questionIds[i];
    final q = _byId[qid];
    if (q == null) return const [];
    final order = s.optionOrders[qid] ?? const <int>[];
    return [for (final oi in order) q.options[oi]];
  }

  // ── ألوان موحّدة (وضع داكن/فاتح) ──
  Color _brand(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.brandDark
      : AppColors.brandLight;
  Color _brand2(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.brand2Dark
      : AppColors.brand2Light;
  Color _gold(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.goldDark
      : AppColors.goldLight;
  Color _danger(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.dangerDark
      : AppColors.dangerLight;
}

// ═════════════ مكوّنات صغيرة ═════════════

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onToggle(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color ?? Theme.of(context).dividerColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: color ?? cs.onSurface),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.name,
    required this.avatarLetter,
    required this.color,
    required this.answered,
    required this.total,
    required this.score,
  });

  final String name;
  final String avatarLetter;
  final Color color;
  final int answered;
  final int total;
  final int score;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final frac = total == 0 ? 0.0 : (answered / total).clamp(0.0, 1.0);
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.22),
          child: Text(
            avatarLetter,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: txt.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ArabicNumber.from(score),
          style: txt.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.onTap,
  });

  final String letter;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primary.withValues(alpha: 0.18),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MathText(text, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
    required this.name,
    required this.score,
    required this.sub,
    required this.color,
  });

  final String name;
  final int score;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          ArabicNumber.from(score),
          style: txt.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(name, style: txt.bodyMedium),
        Text(sub, style: txt.bodyMedium),
      ],
    );
  }
}
