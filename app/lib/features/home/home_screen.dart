import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/license/license_store.dart';
import '../../core/progress/progress_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/cards_service.dart';
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';
import '../../core/xp/streak_service.dart';
import '../curriculum/curriculum_screen.dart';
import '../curriculum/lesson_screen.dart';
import '../training/cards_screen.dart';
import '../training/training_screen.dart';

/// F3.8 — الرئيسية (مطابقة النموذج s-home): ترحيب بالسلسلة 🔥 والنقاط
/// الموثقة من الدفتر + واصل الدرس + تدريب سريع + بطاقات اليوم + تحديات
/// (قريباً M5) + فكرة اليوم الدوّارة. كل الأرقام من النوى الخالصة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.pack,
    required this.progressStore,
    required this.trainingStore,
    required this.licenseStore,
    required this.xpRecorder,
    required this.onToggleTheme,
  });

  final ContentPack pack;
  final ProgressStore progressStore;
  final TrainingStore trainingStore;
  final LicenseStore licenseStore;
  final XpRecorder xpRecorder;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  LicenseData? _license;
  ReadProgress? _progress;
  StreakInfo _streak = const StreakInfo(0);
  int _verifiedXp = 0;
  int _dueCards = 0;
  Chapter? _continueChapter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final license = await widget.licenseStore.load();
    final progress = await widget.progressStore.load();
    final training = await widget.trainingStore.load();
    final events = await widget.xpRecorder.ledger.events();
    final verified = await widget.xpRecorder.ledger.verifiedTotalXp();
    final due = todayCardQueue(training, widget.pack.cards, dateKeyOf(now))
        .length;
    // واصل الدرس: أول فصل غير مكتمل بترتيب الحزمة
    Chapter? target;
    final done = progress.completedIds;
    for (final unit in widget.pack.units) {
      for (final ch in unit.chapters) {
        if (!done.contains(ch.id)) {
          target = ch;
          break;
        }
      }
      if (target != null) break;
    }
    if (!mounted) return;
    setState(() {
      _license = license;
      _progress = progress;
      _streak = computeStreak(events, now);
      _verifiedXp = verified;
      _dueCards = due;
      _continueChapter = target;
      _loading = false;
    });
  }

  void _openHome() => _load();

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? AppColors.goldDark
        : AppColors.goldLight;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final todayKey = studyDateKeyOf(DateTime.now());
    final license = _license!;
    final licensed =
        license.mode == LicenseMode.licensed && license.token != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── بطاقة الترحيب (النموذج: تدرّج + شارة + سلسلة + تقدم) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [AppColors.darkCard, AppColors.darkCard2]
                      : [AppColors.lightCard, AppColors.lightBg],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkLine
                        : AppColors.lightLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('👋 أهلاً بك', style: txt.titleLarge),
                      Chip(
                        avatar: Icon(
                            licensed
                                ? Icons.verified_outlined
                                : Icons.science_outlined,
                            size: 16),
                        label: Text(
                          licensed
                              ? 'مفعّل حتى ${_expiryShort(license)}'
                              : 'وضع تجريبي',
                          style: txt.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _streak.days > 0
                        ? 'تدرّبت ${ArabicNumber.from(_streak.days)} '
                            'يوماً متتالياً — واصل! 🔥'
                        : 'أول نشاط اليوم يشعل السلسلة 🔥',
                    style: txt.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('⭐ نقاطك الموثقة: ${ArabicNumber.from(_verifiedXp)}',
                      style: txt.bodyMedium?.copyWith(color: gold)),
                  const SizedBox(height: 10),
                  ..._buildUnitProgress(txt),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── واصل الدرس ──
            Card(
              child: ListTile(
                leading: const Text('📘', style: TextStyle(fontSize: 22)),
                title: Text(_continueChapter == null
                    ? 'أكملت المنهاج كله — راجع ما شئت'
                    : 'واصل الدرس'),
                subtitle: _continueChapter == null
                    ? null
                    : Text('${_continueChapter!.title} ←'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  final ch = _continueChapter;
                  if (ch == null) {
                    await _openCurriculum();
                    return;
                  }
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => LessonScreen(
                      chapter: ch,
                      progressStore: widget.progressStore,
                      xpRecorder: widget.xpRecorder,
                    ),
                  ));
                  _openHome();
                },
              ),
            ),
            // ── تدريب سريع ──
            Card(
              child: ListTile(
                leading: const Text('📝', style: TextStyle(fontSize: 22)),
                title: const Text('تدريب سريع'),
                subtitle: const Text('١٠ أسئلة ←'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TrainingScreen(
                      pack: widget.pack,
                      trainingStore: widget.trainingStore,
                      xpRecorder: widget.xpRecorder,
                    ),
                  ));
                  _openHome();
                },
              ),
            ),
            // ── بطاقات اليوم ──
            Card(
              child: ListTile(
                leading: const Text('🎯', style: TextStyle(fontSize: 22)),
                title: const Text('بطاقات اليوم'),
                subtitle: Text(_dueCards > 0
                    ? 'مراجعة متباعدة ٥ دقائق — +١٥ نقطة ←'
                    : 'أنجزت طابور اليوم ✓'),
                trailing: Chip(
                  label: Text(
                    _dueCards > 0
                        ? '${ArabicNumber.from(_dueCards)} مستحقة'
                        : 'تم ✓',
                  ),
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CardsScreen(
                      pack: widget.pack,
                      trainingStore: widget.trainingStore,
                      xpRecorder: widget.xpRecorder,
                    ),
                  ));
                  _openHome();
                },
              ),
            ),
            // ── تحديات اليوم (M5) ──
            Card(
              child: ListTile(
                leading: const Text('⚔️', style: TextStyle(fontSize: 22)),
                title: const Text('تحديات اليوم'),
                subtitle: const Text('قريباً — دوري فيزيا كلاش'),
                enabled: false,
              ),
            ),
            // ── فكرة اليوم ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 فكرة اليوم', style: txt.titleMedium),
                    const SizedBox(height: 6),
                    Text(factForDay(todayKey), style: txt.bodyLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── المنهاج الكامل ──
            FilledButton.tonal(
              onPressed: _openCurriculum,
              child: const Text('المنهاج الكامل — الوحدات الخمس 📚'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUnitProgress(TextTheme txt) {
    final progress = _progress;
    if (progress == null || widget.pack.units.isEmpty) return const [];
    final unit = widget.pack.units.first;
    final done = unit.chapters
        .where((c) => progress.completedIds.contains(c.id))
        .length;
    final percent = unit.chapters.isEmpty
        ? 0
        : (done * 100 / unit.chapters.length).round();
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
            value: percent / 100, minHeight: 7),
      ),
      const SizedBox(height: 4),
      Text(
        'أكملت ${ArabicNumber.from(percent)}٪ من الوحدة الأولى',
        style: txt.bodySmall,
      ),
    ];
  }

  String _expiryShort(LicenseData license) {
    final token = license.token;
    if (token == null) return '—';
    try {
      final payloadBytes = token.payloadBytes;
      // عرض مختصر من الحمولة — الفحص الكامل في «حسابي»
      final json = String.fromCharCodes(payloadBytes);
      final m = RegExp(r'"expires_at":(\d+)').firstMatch(json);
      if (m == null) return '—';
      final d = DateTime.fromMillisecondsSinceEpoch(
          int.parse(m.group(1)!),
          isUtc: true);
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
          '${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _openCurriculum() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CurriculumScreen(
        pack: widget.pack,
        onToggleTheme: widget.onToggleTheme,
        progressStore: widget.progressStore,
        trainingStore: widget.trainingStore,
        licenseStore: widget.licenseStore,
        xpRecorder: widget.xpRecorder,
      ),
    ));
    _openHome();
  }
}
