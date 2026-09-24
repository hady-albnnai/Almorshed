import 'package:flutter/material.dart';

import '../challenge/challenge_screen.dart';
import '../curriculum/curriculum_review_screen.dart';
import '../curriculum/unit_screen.dart';
import '../../core/content/models.dart';
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

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final completed = _progress.completedIds;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('الوحدات الخمس', style: txt.titleLarge),
        const SizedBox(height: 6),
        for (var i = 0; i < widget.pack.units.length; i++)
          _UnitCard(
            index: i,
            unit: widget.pack.units[i],
            completedIds: completed,
            progressStore: widget.progressStore,
            xpRecorder: widget.xpRecorder,
            trainingStore: widget.trainingStore,
            onReturned: _reload,
          ),
      ],
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
  });

  final int index;
  final Unit unit;
  final Set<String> completedIds;
  final ProgressStore progressStore;
  final VoidCallback onReturned;
  final XpRecorder? xpRecorder;
  final TrainingStore? trainingStore;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final hasChapters = unit.chapters.isNotEmpty;
    final percent = unitPercent(unit, completedIds);
    final note = hasChapters
        ? '${ArabicNumber.from(unit.chapters.length)} فصل — '
            'ص${ArabicNumber.from(unit.chapters.first.page)} '
            'إلى ص${ArabicNumber.from(unit.chapters.last.page)}'
        : 'قيد الإعداد — تصل مع تحديث المحتوى';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasChapters
            ? () => Navigator.of(context)
                .push(MaterialPageRoute<void>(
                  builder: (_) => UnitScreen(
                    unit: unit,
                    progressStore: progressStore,
                    xpRecorder: xpRecorder,
                    trainingStore: trainingStore,
                  ),
                ))
                .then((_) => onReturned())
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ArabicNumber.from(index + 1)} · ${unit.title}',
                      style: txt.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${ArabicNumber.from(percent)}٪',
                      style: txt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 7,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
              ),
              Text(note, style: txt.bodyMedium),
            ],
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
class _TrainingTab extends StatefulWidget {
  const _TrainingTab({required this.pack, required this.trainingStore, required this.xpRecorder});
  final ContentPack pack;
  final TrainingStore trainingStore;
  final XpRecorder? xpRecorder;

  @override
  State<_TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<_TrainingTab> {
  int _sub = 1; // 0=أسئلة الدورات، 1=تدريب بالوحدة (افتراضي حسب الاستخدام)

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('أسئلة الدورات')),
              ButtonSegment(value: 1, label: Text('تدريب بالوحدة')),
            ],
            selected: {_sub},
            onSelectionChanged: (s) => setState(() => _sub = s.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _sub == 0 ? _ExamsView(pack: widget.pack) : _UnitTrainingView(pack: widget.pack, trainingStore: widget.trainingStore, xpRecorder: widget.xpRecorder),
        ),
      ],
    );
  }
}

class _ExamsView extends StatelessWidget {
  const _ExamsView({required this.pack});
  final ContentPack pack;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أسئلة الدورات', style: txt.titleLarge),
                const SizedBox(height: 8),
                Text('أوراق 2022 — 2026 مع سلالمها، مصنفة بالسنة وبالوحدة.', style: txt.bodyMedium),
                const SizedBox(height: 12),
                for (final y in const ['2026', '2023', '2022'])
                  ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: Text('دورة $y'),
                    subtitle: const Text('عرض الأسئلة والمسائل مع السلم الوزاري'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('أسئلة $y — تُنقل في المرحلة B')),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('المرحلة B ستنقل النص الكامل لكل ورقة إلى التطبيق.', style: txt.bodySmall),
              ],
            ),
          ),
        ),
      ],
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
                subtitle: const Text('مراجعة متباعدة — FSRS'),
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

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('التحديات', style: txt.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('⚔️', style: TextStyle(fontSize: 22)),
            title: const Text('تحدي اليوم'),
            subtitle: const Text('10 أسئلة بوقت محدود — النقاط تقلّ مع البطء'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ChallengeScreen(
                pack: pack,
                xpRecorder: xpRecorder,
              ),
            )),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Text('📡', style: TextStyle(fontSize: 22)),
            title: const Text('مبارزة محلية — بلا نت'),
            subtitle: const Text('عبر نقطة الاتصال'),
            enabled: openLocalDuel != null,
            onTap: openLocalDuel == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LocalDuelScreen(pack: pack, flowFactory: openLocalDuel!))),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Text('🌐', style: TextStyle(fontSize: 22)),
            title: const Text('مبارزة عن بعد'),
            subtitle: const Text('تحدَّ صديقك برمز الغرفة'),
            enabled: openDuel != null,
            onTap: openDuel == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DuelScreen(pack: pack, flowFactory: openDuel!))),
          ),
        ),
        if (fetchLeague != null)
          Card(
            child: ListTile(
              leading: const Text('🏆', style: TextStyle(fontSize: 22)),
              title: const Text('لوحة الموسم'),
              subtitle: const Text('ترتيب تراكمي طوال العام — بلا مجموعات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LeagueScreen(fetch: fetchLeague!))),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نقاطي — كيف تُحسب؟', style: txt.titleMedium),
                const SizedBox(height: 8),
                // A5 — قرار ٦٠: فصل حاسم بين نقاط التعلّم (شخصية) ونقاط الترتيب (التحديات)
                const Text('التدريب والبطاقات = نقاط تعلّم شخصية، بلا سقف وبلا جوائز — لا تدخل الترتيب. التحديات وحدها هي نقاط الترتيب الأسبوعي، والفوز فقط يُكافَأ.'),
                const SizedBox(height: 6),
                FutureBuilder<int>(
                  future: xpRecorder.ledger.arenaTotalXp(),
                  builder: (_, snap) => Text(
                    'نقاط الترتيب (التحديات): ${snap.data ?? 0}',
                    style: txt.titleSmall,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<int>(
                  future: xpRecorder.ledger.verifiedTotalXp(),
                  builder: (_, snap) => Text(
                    'نقاط التعلّم الموثقة: ${snap.data ?? 0}',
                    style: txt.bodySmall,
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
