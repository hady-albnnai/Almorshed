import 'package:flutter/material.dart';

import '../challenge/challenge_screen.dart';
import '../curriculum/curriculum_review_screen.dart';
import '../curriculum/unit_screen.dart';
import '../../core/content/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/arabic_number.dart';
import '../../core/license/license_store.dart';
import '../../core/progress/progress_store.dart';
import '../../core/cert/certificate.dart';
import '../../core/supabase/cert_api.dart';
import '../../core/supabase/league_api.dart';
import '../../core/sync/sync_manager.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../account/account_screen.dart';
import '../duel/duel_screen.dart';
import '../duel/local_duel_screen.dart';
import '../league/league_screen.dart';
import '../../core/content/generated_items.dart';
import '../training/cards_screen.dart';
import '../training/item_session_screen.dart';
import '../training/mistakes_screen.dart';
import '../training/training_screen.dart';

/// A2 — الهيكل الجديد (قرار 58):
/// 3 تبويبات سفلية، الافتراضي المنهاج.
/// - المنهاج → الدروس | المراجعة
/// - التدريب → أسئلة الدورات | تدريب بالوحدة
/// - التحديات → تحدي اليوم، مبارزة، لوحة الموسم (تراكمي — قرار ٦٥)، نقاطي
/// الحساب/الإعدادات أيقونة علوية. التجارب داخل الدرس.
///
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.pack,
    required this.progressStore,
    required this.trainingStore,
    required this.licenseStore,
    required this.xpRecorder,
    required this.onToggleTheme,
    this.syncManager,
    this.fetchLeague,
    this.openDuel,
    this.openLocalDuel,
    this.devicePubkeyB64 = '',
    this.certApi,
  });

  final ContentPack pack;
  final ProgressStore progressStore;
  final TrainingStore trainingStore;
  final LicenseStore licenseStore;
  final XpRecorder xpRecorder;
  final VoidCallback onToggleTheme;
  final SyncManager? syncManager;
  final Future<LeagueView> Function()? fetchLeague;
  final DuelFlowFactory? openDuel;
  final LocalDuelFlowFactory? openLocalDuel;
  final String devicePubkeyB64;

  /// مُصدِر شهادة الموسم (F6.5) — يُمرَّر لشاشة الحساب؛ null = المدخل مخفي.
  final CertIssuer? certApi;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0; // 0=المنهاج افتراضي

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فيزيا كلاش'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'حسابي',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AccountScreen(
                licenseStore: widget.licenseStore,
                devicePubkeyB64: widget.devicePubkeyB64,
                certApi: widget.certApi,
                certSeason: widget.certApi == null ? '' : currentSeason(),
              ),
            )),
          ),
          IconButton(
            tooltip: 'تبديل المظهر',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _ManhajTab(
            pack: widget.pack,
            progressStore: widget.progressStore,
            trainingStore: widget.trainingStore,
            xpRecorder: widget.xpRecorder,
          ),
          _TrainingTab(
            pack: widget.pack,
            trainingStore: widget.trainingStore,
            xpRecorder: widget.xpRecorder,
          ),
          _ChallengesTab(
            pack: widget.pack,
            xpRecorder: widget.xpRecorder,
            syncManager: widget.syncManager,
            fetchLeague: widget.fetchLeague,
            openDuel: widget.openDuel,
            openLocalDuel: widget.openLocalDuel,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'المنهاج',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'التدريب',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'التحديات',
          ),
        ],
      ),
    );
  }
}

// ── تبويب المنهاج ────────────────────────────────────────────────
class _ManhajTab extends StatefulWidget {
  const _ManhajTab({
    required this.pack,
    required this.progressStore,
    required this.trainingStore,
    required this.xpRecorder,
  });

  final ContentPack pack;
  final ProgressStore progressStore;
  final TrainingStore trainingStore;
  final XpRecorder xpRecorder;

  @override
  State<_ManhajTab> createState() => _ManhajTabState();
}

class _ManhajTabState extends State<_ManhajTab> {
  // 0 = الدروس (افتراضي)، 1 = المراجعة
  int _sub = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // شريط الشرائح
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('الدروس'), icon: Icon(Icons.menu_book_outlined, size: 16)),
              ButtonSegment(value: 1, label: Text('المراجعة'), icon: Icon(Icons.auto_stories_outlined, size: 16)),
            ],
            selected: {_sub},
            onSelectionChanged: (s) => setState(() => _sub = s.first),
          ),
        ),
        // سطر الإشراف (قرار 58) أُزيل على فرع dev/self-content — راجع BRANCHING.md
        const SizedBox(height: 8),
        Expanded(
          child: _sub == 0
              ? _LessonsView(
                  pack: widget.pack,
                  progressStore: widget.progressStore,
                  trainingStore: widget.trainingStore,
                  xpRecorder: widget.xpRecorder,
                )
              : _ReviewView(pack: widget.pack),
        ),
      ],
    );
  }
}

// المنهاج فقط: قائمة الوحدات الخمس ⇐ الفصول ⇐ الدرس (والتجربة داخل الدرس).
// أُزيلت لوحة HomeScreen المكتظّة (تدريب/بطاقات/تحديات/مبارزات/المختبر/فكرة
// اليوم) من هذا التبويب — كلٌّ في تبويبه (التدريب/التحديات). المختبر داخل الدرس.
class _LessonsView extends StatefulWidget {
  const _LessonsView({
    required this.pack,
    required this.progressStore,
    required this.trainingStore,
    required this.xpRecorder,
  });

  final ContentPack pack;
  final ProgressStore progressStore;
  final TrainingStore trainingStore;
  final XpRecorder xpRecorder;

  @override
  State<_LessonsView> createState() => _LessonsViewState();
}

class _LessonsViewState extends State<_LessonsView> {
  ReadProgress _progress = const ReadProgress();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await widget.progressStore.load();
    if (!mounted) return;
    setState(() => _progress = p);
  }

  void _openUnit(Unit unit) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => UnitScreen(
            unit: unit,
            progressStore: widget.progressStore,
            xpRecorder: widget.xpRecorder,
            trainingStore: widget.trainingStore,
          ),
        ))
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final completed = _progress.completedIds;
    final units = widget.pack.units;

    final allChapters = [for (final u in units) ...u.chapters];
    final totalChapters = allChapters.length;
    final doneChapters =
        allChapters.where((c) => completed.contains(c.id)).length;
    final overall =
        totalChapters == 0 ? 0 : (doneChapters * 100 / totalChapters).round();

    // الوحدة/الفصل «التالي» = أول فصل غير مكتمل.
    Unit? nextUnit;
    Chapter? nextChapter;
    for (final u in units) {
      for (final c in u.chapters) {
        if (!completed.contains(c.id)) {
          nextUnit = u;
          nextChapter = c;
          break;
        }
      }
      if (nextChapter != null) break;
    }
    final nu = nextUnit;
    final nc = nextChapter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _Hero(
          started: doneChapters > 0,
          onStart: () {
            if (nu != null) _openUnit(nu);
          },
        ),
        const SizedBox(height: 26),
        _StatsRow(
          lessons: totalChapters,
          units: units.length,
          percent: overall,
        ),
        if (nu != null && nc != null) ...[
          const SizedBox(height: 14),
          _ContinueCard(
            unit: nu,
            chapter: nc,
            fresh: doneChapters == 0,
            onTap: () => _openUnit(nu),
          ),
        ],
        const SizedBox(height: 30),
        Text('خريطة المنهج',
            style: TextStyle(
              fontFamily: 'Alexandria',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.4,
              color: AppColors.accent,
            )),
        const SizedBox(height: 4),
        Text('الوحدات الدراسية',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        // شبكة «مجلّة»: الوحدة الأولى بطاقة كبيرة، والبقية شبكة ثنائية.
        if (units.isNotEmpty)
          _UnitCard(
            index: 0,
            big: true,
            unit: units.first,
            completedIds: completed,
            progressStore: widget.progressStore,
            xpRecorder: widget.xpRecorder,
            trainingStore: widget.trainingStore,
            onReturned: _reload,
          ),
        const SizedBox(height: 12),
        for (var i = 1; i < units.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _UnitCard(
                    index: i,
                    unit: units[i],
                    completedIds: completed,
                    progressStore: widget.progressStore,
                    xpRecorder: widget.xpRecorder,
                    trainingStore: widget.trainingStore,
                    onReturned: _reload,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < units.length
                      ? _UnitCard(
                          index: i + 1,
                          unit: units[i + 1],
                          completedIds: completed,
                          progressStore: widget.progressStore,
                          xpRecorder: widget.xpRecorder,
                          trainingStore: widget.trainingStore,
                          onReturned: _reload,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
              ),
            ),
          ),
      ],
    );
  }
}

/// قسم البطل — العنوان الكبير + بطاقة الفلَك الزخرفية + الأزرار.
class _Hero extends StatelessWidget {
  const _Hero({required this.started, required this.onStart});
  final bool started;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('منهج الفيزياء • بكالوريا ٢٠٢٧',
            style: TextStyle(
              fontFamily: 'Alexandria',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.3,
              color: AppColors.accent,
            )),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: txt.displayLarge,
            children: [
              const TextSpan(text: 'افهم الفكرة.\n'),
              TextSpan(
                  text: 'ثم جرّبها.',
                  style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'شرح مركّز، براهين مرتّبة، ومسائل مصمّمة على نمط الامتحان — '
          'في مكان واحد يحفظ تقدّمك.',
          style: txt.bodyMedium?.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 22),
        Center(child: _OrbitCard()),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onStart,
          child: Text(started ? 'تابع رحلتك ←' : 'ابدأ من أول درس ←'),
        ),
      ],
    );
  }
}

/// بطاقة الفلَك الزخرفية (حبريّة، حلقات + صيغة) — بلا حركة (خفيفة وآمنة).
class _OrbitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? AppColors.card2D : AppColors.ink;
    return Container(
      height: 230,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: base,
        borderRadius: const BorderRadius.vertical(
          top: Radius.elliptical(240, 150),
          bottom: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(180, AppColors.sage.withValues(alpha: 0.28)),
          _ring(120, AppColors.sage.withValues(alpha: 0.22)),
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('φ',
                style: TextStyle(
                    fontFamily: 'Alexandria',
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    color: Colors.white)),
          ),
          Positioned(
            bottom: 26,
            child: Column(
              children: [
                const Text('T₀ = 2π √(m / k)',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontFamily: 'Alexandria',
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('كل قانون له حكاية',
                    style: TextStyle(color: AppColors.sage, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, Color color) => Positioned(
        top: 20,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
        ),
      );
}

/// صفّ الإحصاءات الثلاثي (بفواصل) — الأرقام باللمسة الطوبية.
class _StatsRow extends StatelessWidget {
  const _StatsRow(
      {required this.lessons, required this.units, required this.percent});
  final int lessons;
  final int units;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outline;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          _stat(context, '${ArabicNumber.from(lessons)}', 'درسًا مشروحًا'),
          _divider(line),
          _stat(context, '${ArabicNumber.from(units)}', 'وحدات'),
          _divider(line),
          _stat(context, '${ArabicNumber.from(percent)}٪', 'الإنجاز'),
        ],
      ),
    );
  }

  Widget _divider(Color line) =>
      Container(width: 1, height: 46, color: line);

  Widget _stat(BuildContext context, String value, String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontFamily: 'Alexandria',
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: AppColors.accent)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

/// بطاقة «تابع من حيث وقفت».
class _ContinueCard extends StatelessWidget {
  const _ContinueCard(
      {required this.unit,
      required this.chapter,
      required this.fresh,
      required this.onTap});
  final Unit unit;
  final Chapter chapter;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.surfaceContainerHighest;
    final unitNo = unit.id.replaceAll(RegExp(r'[^0-9]'), '');
    final chNo = (unit.chapters.indexOf(chapter) + 1);
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(
                    '${ArabicNumber.from(int.tryParse(unitNo) ?? 1)}.${ArabicNumber.from(chNo)}',
                    style: const TextStyle(
                        fontFamily: 'Alexandria',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chapter.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        '${fresh ? 'ابدأ رحلتك من هنا' : 'تابع رحلتك'} • '
                        '${ArabicNumber.from(chapter.paragraphs.length)} فقرة',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Text('←', style: TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.index,
    required this.unit,
    required this.completedIds,
    required this.progressStore,
    required this.onReturned,
    required this.xpRecorder,
    this.trainingStore,
    this.big = false,
  });

  final int index;
  final Unit unit;
  final Set<String> completedIds;
  final ProgressStore progressStore;
  final VoidCallback onReturned;
  final XpRecorder? xpRecorder;
  final TrainingStore? trainingStore;
  final bool big;

  // اسم مختصر للوحدة بلا بادئة «الوحدة الأولى: ».
  String get _shortTitle =>
      unit.title.replaceFirst(RegExp(r'^الوحدة[^:：]*[:：]\s*'), '');

  void _open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(
        builder: (_) => UnitScreen(
          unit: unit,
          progressStore: progressStore,
          xpRecorder: xpRecorder,
          trainingStore: trainingStore,
        ),
      ))
      .then((_) => onReturned());

  @override
  Widget build(BuildContext context) {
    final hasChapters = unit.chapters.isNotEmpty;
    final percent = unitPercent(unit, completedIds);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = Theme.of(context).colorScheme.outline;

    final bg = big
        ? (dark ? AppColors.card2D : AppColors.ink)
        : Theme.of(context).colorScheme.surface;
    final onBg = big ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final onBgMuted = big
        ? AppColors.sage
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: hasChapters ? () => _open(context) : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: big ? null : Border.all(color: line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Padding(
                  padding: EdgeInsets.all(big ? 22 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: big ? 40 : 34,
                            height: big ? 40 : 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: onBg.withValues(alpha: 0.4)),
                            ),
                            alignment: Alignment.center,
                            child: Text('←',
                                style: TextStyle(
                                    color: onBg, fontSize: big ? 18 : 15)),
                          ),
                          const Spacer(),
                          Text('${ArabicNumber.from(percent)}٪',
                              style: TextStyle(
                                  fontFamily: 'Alexandria',
                                  fontWeight: FontWeight.w700,
                                  color: onBg)),
                        ],
                      ),
                      SizedBox(height: big ? 22 : 16),
                      Text('الوحدة ${ArabicNumber.from(index + 1)}',
                          style: TextStyle(
                            fontFamily: 'Alexandria',
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            color: AppColors.accent,
                          )),
                      const SizedBox(height: 6),
                      Text(
                        _shortTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Alexandria',
                          fontWeight: FontWeight.w700,
                          fontSize: big ? 22 : 16,
                          height: 1.5,
                          color: onBg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasChapters
                            ? '${ArabicNumber.from(unit.chapters.length)} دروس'
                            : 'قيد الإعداد',
                        style: TextStyle(color: onBgMuted, fontSize: 12.5),
                      ),
                      SizedBox(height: big ? 26 : 14),
                      if (hasChapters)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 6,
                            backgroundColor: onBg.withValues(alpha: 0.15),
                            color: AppColors.accent,
                          ),
                        ),
                      if (big) const SizedBox(height: 8),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.pack});
  final ContentPack pack;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    // المراجعة: قائمة الوحدات ⇐ صفحة مراجعة الوحدة (أقسام 🔑/🧾/⚖️ لكل فصل).
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المراجعة', style: txt.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'هنا ستجد خلاصات الدروس، الأخطاء الشائعة ⚠️، خصومات سلم التصحيح ⚖️، والقوانين الذهبية 🧾 — مجمعة حسب الوحدة.',
                  style: txt.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final u in pack.units)
                  ListTile(
                    dense: true,
                    key: Key('review-unit-${u.id}'),
                    leading: const Icon(Icons.auto_stories_outlined, size: 18),
                    title: Text(u.title, style: txt.bodyMedium),
                    subtitle: Text('${u.chapters.length} دروس', style: txt.bodySmall),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CurriculumReviewScreen(unit: u),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── تبويب التدريب ────────────────────────────────────────────────
// تبويب التدريب: المسائل والتمارين بالوحدة + أدوات المذاكرة. أُزيل التبويب
// الفرعي «أسئلة الدورات» (كان أزراراً وهمية «المرحلة B») حتى يجهز محتواه.
class _TrainingTab extends StatelessWidget {
  const _TrainingTab(
      {required this.pack, required this.trainingStore, required this.xpRecorder});
  final ContentPack pack;
  final TrainingStore trainingStore;
  final XpRecorder? xpRecorder;

  @override
  Widget build(BuildContext context) {
    return _UnitTrainingView(
      pack: pack,
      trainingStore: trainingStore,
      xpRecorder: xpRecorder,
    );
  }
}

class _UnitTrainingView extends StatefulWidget {
  const _UnitTrainingView(
      {required this.pack, required this.trainingStore, this.xpRecorder});
  final ContentPack pack;
  final TrainingStore trainingStore;
  final XpRecorder? xpRecorder;

  @override
  State<_UnitTrainingView> createState() => _UnitTrainingViewState();
}

class _UnitTrainingViewState extends State<_UnitTrainingView> {
  // تُحمَّل مرة واحدة (٥٦١ بند مسائل/تمارين معتمدة من المنهاج الوزاري).
  Future<GeneratedItemsPack>? _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = GeneratedItemsPack.loadAsset();
  }

  void _open(String title, List<GeneratedItem> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا مسائل لهذه الوحدة بعد')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ItemSessionScreen(items: items, title: title),
    ));
  }

  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return FutureBuilder<GeneratedItemsPack>(
      future: _itemsFuture,
      builder: (context, snap) {
        final items = snap.data?.visible ?? const <GeneratedItem>[];
        List<GeneratedItem> forUnit(String unitId) => [
              for (final it in items)
                if ((it.raw['unit'] as String?) == unitId) it
            ];
        final loading = snap.connectionState == ConnectionState.waiting;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text('مسائل وتمارين — أنماط الامتحان', style: txt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'حساب بالوحدة · علّل · برهان مرتّب — تصحيح فوري بسلّم الوزارة',
              style: txt.bodySmall,
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              for (final u in widget.pack.units)
                _unitProblemsCard(u.id, u.title, forUnit(u.id).length,
                    () => _open(u.title, forUnit(u.id))),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Text('🔀', style: TextStyle(fontSize: 20)),
                  title: const Text('مختلط — من كل الوحدات'),
                  subtitle: Text('${ArabicNumber.from(items.length)} بند'),
                  trailing: const Icon(Icons.chevron_left),
                  enabled: items.isNotEmpty,
                  onTap: items.isEmpty
                      ? null
                      : () => _open('تدريب مختلط', items),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('أدوات المذاكرة', style: txt.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.today_outlined),
                title: const Text('دفعة اليوم'),
                subtitle: const Text('أسئلة اليوم — عادلة للجميع بالبذرة اليومية'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _push(TrainingScreen(
                    pack: widget.pack,
                    trainingStore: widget.trainingStore,
                    xpRecorder: widget.xpRecorder)),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('بطاقات اليوم'),
                subtitle: const Text('مراجعة متباعدة — كل بطاقة في وقتها'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _push(CardsScreen(
                    pack: widget.pack,
                    trainingStore: widget.trainingStore,
                    xpRecorder: widget.xpRecorder)),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('أخطائي'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _push(MistakesScreen(
                    pack: widget.pack,
                    trainingStore: widget.trainingStore,
                    xpRecorder: widget.xpRecorder)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _unitProblemsCard(
      String unitId, String title, int count, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: const Text('📝', style: TextStyle(fontSize: 20)),
        title: Text(title),
        subtitle: Text(count > 0
            ? '${ArabicNumber.from(count)} مسألة وتمرين'
            : 'قيد الإعداد'),
        trailing: const Icon(Icons.chevron_left),
        enabled: count > 0,
        onTap: count > 0 ? onTap : null,
      ),
    );
  }
}

// ── تبويب التحديات ───────────────────────────────────────────────
class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({required this.pack, required this.xpRecorder, this.syncManager, this.fetchLeague, this.openDuel, this.openLocalDuel});
  final ContentPack pack;
  final XpRecorder xpRecorder;
  final SyncManager? syncManager;
  final Future<LeagueView> Function()? fetchLeague;
  final DuelFlowFactory? openDuel;
  final LocalDuelFlowFactory? openLocalDuel;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── العب الآن ──
        Text('العب الآن', style: txt.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('⚔️', style: TextStyle(fontSize: 22)),
            title: const Text('تحدي اليوم'),
            subtitle: const Text('١٠ أسئلة بوقت محدود — النقاط تقلّ مع البطء'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _push(
                context, ChallengeScreen(pack: pack, xpRecorder: xpRecorder)),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Text('📡', style: TextStyle(fontSize: 22)),
            title: const Text('مبارزة محلية — بلا نت'),
            subtitle: const Text('تحدَّ صديقك عبر نقطة الاتصال'),
            trailing: const Icon(Icons.chevron_left),
            enabled: openLocalDuel != null,
            onTap: openLocalDuel == null
                ? null
                : () => _push(context,
                    LocalDuelScreen(pack: pack, flowFactory: openLocalDuel!)),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Text('🌐', style: TextStyle(fontSize: 22)),
            title: const Text('مبارزة عن بعد'),
            subtitle: const Text('تحدَّ صديقك برمز الغرفة'),
            trailing: const Icon(Icons.chevron_left),
            enabled: openDuel != null,
            onTap: openDuel == null
                ? null
                : () => _push(
                    context, DuelScreen(pack: pack, flowFactory: openDuel!)),
          ),
        ),
        const SizedBox(height: 18),
        // ── ترتيبك ──
        Text('ترتيبك', style: txt.titleLarge),
        const SizedBox(height: 8),
        if (fetchLeague != null)
          Card(
            child: ListTile(
              leading: const Text('🏆', style: TextStyle(fontSize: 22)),
              title: const Text('لوحة الموسم'),
              subtitle: const Text('ترتيب تراكمي طوال العام — بلا مجموعات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () =>
                  _push(context, LeagueScreen(fetch: fetchLeague!)),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('نقاطي', style: txt.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<int>(
                        future: xpRecorder.ledger.arenaTotalXp(),
                        builder: (_, snap) => _pointsBox(
                          context,
                          '${snap.data ?? 0}',
                          'نقاط الترتيب',
                          Icons.emoji_events_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: xpRecorder.ledger.verifiedTotalXp(),
                        builder: (_, snap) => _pointsBox(
                          context,
                          '${snap.data ?? 0}',
                          'نقاط التعلّم',
                          Icons.school_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // A5 — قرار ٦٠: فصل نقاط التعلّم (شخصية) عن نقاط الترتيب (التحديات).
                Text(
                  'التحديات وحدها تدخل الترتيب الأسبوعي (الفوز يُكافأ). '
                  'التدريب والبطاقات نقاط تعلّم شخصية — بلا سقف وبلا ترتيب.',
                  style: txt.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pointsBox(
      BuildContext context, String value, String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
