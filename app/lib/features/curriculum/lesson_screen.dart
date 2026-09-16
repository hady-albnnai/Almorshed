import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/lab/experiments.dart';
import '../../core/progress/progress_store.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tts/flutter_tts_speaker.dart';
import '../../core/tts/speaker.dart';
import '../../core/util/arabic_number.dart';
import '../lab/experiment_screen.dart';
import '../review/review_widgets.dart';

/// شاشة القراءة — فقرة واحدة لكل شاشة (قرار نمط القراءة · F3.2):
/// «التالي» + «📌 خلاصة الفقرة» + TTS «اسمعني» + فهرس حر قابل للطي + «انتهى الدرس».
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.chapter,
    required this.progressStore,
    this.speaker,
    this.xpRecorder, // F3.8: تسجيل درس جديد بدفتر XP
    this.trainingStore, // المادة ١٤: تحدّي التجربة داخل الدرس (null = بلا حفظ)
  });

  final Chapter chapter;
  final ProgressStore progressStore;

  /// المادة ١٤ — مخزن التدريب لتحدّيات التجارب المدمجة (قرار ٥٨).
  final TrainingStore? trainingStore;

  /// حقن اختياري للنطق (اختبارات)؛ الافتراضي FlutterTtsSpeaker حقيقي.
  final Speaker? speaker;

  /// F3.8 — اختياري: null = بلا تسجيل (اختبارات قديمة سليمة).
  final XpRecorder? xpRecorder;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _idx = 0;
  bool _finished = false;
  bool _indexOpen = false;
  Speaker? _speaker; // لا زر «اسمعني» قبل إثبات محرك عربي (قرار F3.2)
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _initSpeaker();
    _restoreCursor(); // F3.1 جزء ثانٍ: استئناف من موضع القارئ المحفوظ
  }

  /// إن للفصل موضع محفوظ وغير مكتمل — نبدأ منه لا من الصفر.
  Future<void> _restoreCursor() async {
    final p = await widget.progressStore.load();
    final cp = p.chapters[widget.chapter.id];
    if (cp == null || cp.completed) return;
    if (!mounted) return;
    final target = cp.cursor.clamp(0, _chapter.paragraphs.length - 1);
    if (target > 0) setState(() => _idx = target);
  }

  Future<void> _initSpeaker() async {
    final s = widget.speaker ?? FlutterTtsSpeaker();
    try {
      if (await s.hasArabicEngine()) {
        if (!mounted) return;
        setState(() => _speaker = s);
      }
    } catch (_) {
      // أي فشل منصة/محرك = يبقى الزر مخفياً بهدوء (قرار F3.2 الصريح).
    }
  }

  Future<void> _toggleSpeak() async {
    final s = _speaker;
    if (s == null) return;
    if (_speaking) {
      await s.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      await s.speak(_paragraph.text);
    } catch (_) {
      // فشل نطق عابر — نُسقط الحالة ويبقى الزر لإعادة المحاولة.
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  void _stopSpeaking() {
    if (!_speaking) return;
    _speaker?.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    _speaker?.stop();
    super.dispose();
  }

  Chapter get _chapter => widget.chapter;
  int get _total => _chapter.paragraphs.length;
  Paragraph get _paragraph => _chapter.paragraphs[_idx];

  Color _gold(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.goldDark
      : AppColors.goldLight;

  /// F3.1: تسجيل إتمام الفصل في مخزن التقدم (مع الحفاظ على موضع القارئ).
  Future<void> _markCompleted() async {
    final p = await widget.progressStore.load();
    final chapters = {...p.chapters};
    chapters[widget.chapter.id] = ChapterProgress(
      cursor: _idx,
      completed: true,
    );
    await widget.progressStore.save(ReadProgress(chapters: chapters));
    // قرار ٦٠: قراءة الدرس = ٠ نقطة (علامة ✓ فقط) — الحدث يُسجَّل لأجل
    // التقدّم والسلسلة البصرية، بلا نقاط وبلا إشعال لسلسلة اليوم.
    await widget.xpRecorder?.record('lessonNew');
  }

  /// F3.1 جزء ثانٍ: حفظ موضع القارئ عند كل تقدّم/تراجع — بلا المساس
  /// بحالة الإتمام (بقّ موثق: كانت مفقودة كلياً وكشفها فشل اختبار
  /// «متابعة القراءة» — كان cursor يُكتب عند الإتمام حصراً).
  Future<void> _saveCursor() async {
    final p = await widget.progressStore.load();
    final chapters = {...p.chapters};
    final prev = chapters[widget.chapter.id];
    chapters[widget.chapter.id] = ChapterProgress(
      cursor: _idx,
      completed: prev?.completed ?? false,
    );
    await widget.progressStore.save(ReadProgress(chapters: chapters));
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _finished ? 'انتهى الدرس' : _chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_finished)
            ReviewNoteButton(
              kind: 'p',
              itemId: _paragraph.id,
              preview: _paragraph.text,
            ),
          if (!_finished && _speaker != null)
            IconButton(
              tooltip: _speaking ? 'إيقاف النطق' : 'اسمعني — نطق الفقرة',
              onPressed: _toggleSpeak,
              icon: Icon(
                _speaking ? Icons.stop_outlined : Icons.volume_up_outlined,
              ),
            ),
          if (!_finished)
            IconButton(
              tooltip: 'الفهرس — تنقّل حر',
              onPressed: () => setState(() => _indexOpen = !_indexOpen),
              icon: const Icon(Icons.menu_book_outlined),
            ),
        ],
      ),
      body: _finished
          ? _EndView(
              onReplay: () => setState(() {
                _finished = false;
                _idx = 0;
              }),
            )
          : Column(
              children: [
                if (_indexOpen)
                  _IndexPanel(
                    chapter: _chapter,
                    current: _idx,
                    onPick: (i) {
                      _stopSpeaking(); // تغيير الفقرة يوقف النطق الجاري
                      setState(() {
                        _idx = i;
                        _indexOpen = false;
                      });
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'فقرة ${ArabicNumber.from(_idx + 1)} من '
                      '${ArabicNumber.from(_total)}',
                      style: txt.bodyMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A4 — عنوان القسم فوق النص (قرار وضوح الدرس)
                        // لا نعرض العنوان إن كان لا يحوي فاصل « — » (اختبارات sample_pack)
                        // حتى لا نكرر نفس نص الخلاصة مرتين → فشل findsOneWidget
                        if (_paragraph.summary.contains(' — '))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _paragraph.summary.split(' — ').first.trim(),
                              style: txt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ),
                        Text(_paragraph.text, style: txt.bodyLarge),
                        // المادة ١٤ — التجربة بموضعها من النوطة (قرار ٥٨/٣٧)
                        if (_paragraph.experimentId != null &&
                            labExperiments.containsKey(
                                _paragraph.experimentId))
                          _ExperimentCard(
                            experiment:
                                labExperiments[_paragraph.experimentId]!,
                            onOpen: () {
                              _stopSpeaking();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ExperimentScreen(
                                    experiment: labExperiments[
                                        _paragraph.experimentId]!,
                                    trainingStore: widget.trainingStore ??
                                        InMemoryTrainingStore(),
                                    xpRecorder: widget.xpRecorder,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _gold(context).withValues(alpha: .45),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📌 خلاصة الفقرة',
                          style: txt.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_paragraph.summary, style: txt.bodyMedium),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      // ⚠️ Expanded إلزامي: ثيم الأزرار بعرض ∞ كحد أدنى
                      // (تمدد بالأعمدة) — داخل Row بلا Expanded = قيود لانهائية
                      children: [
                        if (_idx > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _stopSpeaking();
                                setState(() => _idx--);
                                _saveCursor(); // موضع القارئ عند التراجع
                              },
                              child: const Text('→ السابق'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: _idx > 0 ? 2 : 1,
                          child: FilledButton(
                            onPressed: () {
                              _stopSpeaking();
                              setState(() {
                                if (_idx == _total - 1) {
                                  _markCompleted(); // F3.1: تقدم حقيقي
                                  _finished = true;
                                } else {
                                  _idx++;
                                  _saveCursor(); // موضع القارئ عند كل تقدّم
                                }
                              });
                            },
                            child: Text(
                              _idx == _total - 1 ? 'انتهى الدرس ✓' : 'التالي ←',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// الفهرس الحر — تنقّل مباشر للفقرات (قرار قابلية الطي بالنموذج).
class _IndexPanel extends StatelessWidget {
  const _IndexPanel({
    required this.chapter,
    required this.current,
    required this.onPick,
  });

  final Chapter chapter;
  final int current;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240), // لا فيض أبداً
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < chapter.paragraphs.length; i++)
              // ⚠️ Material شفاف إلزامي: الحاوية الأم ColoredBox (لون السطح)،
              // وListTile يرسم الخلفية/الحبر على أقرب Material أب — بدونه
              // الضربات تنرسم تحت الصندوق = استثناء إطار «may be invisible».
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  leading: i == current
                      ? const Icon(Icons.check_circle_outline, size: 18)
                      : const Icon(Icons.radio_button_unchecked, size: 18),
                  title: Text(
                    'الفقرة ${ArabicNumber.from(i + 1)} — '
                    '${_short(chapter.paragraphs[i].summary)}',
                    style: txt.bodyMedium?.copyWith(
                      fontWeight: i == current ? FontWeight.w800 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onPick(i),
                ),
              ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }

  String _short(String s) => s.length <= 42 ? s : '${s.substring(0, 42)}…';
}

/// «انتهى الدرس» — شاشة الإتمام (قرار نمط القراءة) — النقاط تُسجَّل فعلياً في F3.7.
class _EndView extends StatelessWidget {
  const _EndView({required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration_outlined,
              size: 64,
              color: AppColors.brandDark,
            ),
            const SizedBox(height: 12),
            Text('أنهيت الفصل!', style: txt.titleLarge),
            const SizedBox(height: 6),
            Text(
              '+١٠ نقطة لدوري فيزيا كلاش ✓',
              style: txt.titleMedium?.copyWith(color: _gold(context)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع للوحدة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onReplay,
              child: const Text('أعد القراءة'),
            ),
          ],
        ),
      ),
    );
  }

  Color _gold(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.goldDark
      : AppColors.goldLight;
}

/// بطاقة «🧪 جرّبها بنفسك» داخل الفقرة — تفتح التجربة التفاعلية بموضعها.
class _ExperimentCard extends StatelessWidget {
  const _ExperimentCard({required this.experiment, required this.onOpen});
  final LabExperiment experiment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: Key('experiment-${experiment.id}'),
      margin: const EdgeInsets.only(top: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.secondary.withValues(alpha: .5)),
      ),
      child: ListTile(
        leading: const Text('🧪', style: TextStyle(fontSize: 24)),
        title: Text('جرّبها بنفسك: ${experiment.title}',
            style: txt.titleSmall),
        subtitle: const Text(
            'توقّع ← لاحظ (محاكاة حتمية) ← اشرح · تحدٍّ +١٠'),
        trailing: const Icon(Icons.chevron_left),
        onTap: onOpen,
      ),
    );
  }
}
