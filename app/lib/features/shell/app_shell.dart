import 'package:flutter/material.dart';

import '../challenge/challenge_screen.dart';
import '../../core/content/models.dart';
import '../../core/license/license_store.dart';
import '../../core/progress/progress_store.dart';
import '../../core/supabase/league_api.dart';
import '../../core/sync/sync_manager.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import '../account/account_screen.dart';
import '../curriculum/curriculum_screen.dart';
import '../curriculum/lesson_screen.dart';
import '../duel/duel_screen.dart';
import '../duel/local_duel_screen.dart';
import '../home/home_screen.dart';
import '../league/league_screen.dart';
import '../training/cards_screen.dart';
import '../training/mistakes_screen.dart';
import '../training/training_screen.dart';
import '../../core/theme/app_colors.dart';

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
            licenseStore: widget.licenseStore,
            xpRecorder: widget.xpRecorder,
            onToggleTheme: widget.onToggleTheme,
            syncManager: widget.syncManager,
            fetchLeague: widget.fetchLeague,
            openDuel: widget.openDuel,
            openLocalDuel: widget.openLocalDuel,
            devicePubkeyB64: widget.devicePubkeyB64,
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
    required this.licenseStore,
    required this.xpRecorder,
    required this.onToggleTheme,
    this.syncManager,
    this.fetchLeague,
    this.openDuel,
    this.openLocalDuel,
    this.devicePubkeyB64 = '',
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

  @override
  State<_ManhajTab> createState() => _ManhajTabState();
}

class _ManhajTabState extends State<_ManhajTab> {
  // 0 = الدروس (افتراضي)، 1 = المراجعة
  int _sub = 0;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
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
        const SizedBox(height: 6),
        // سطر الإشراف (قرار 58)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'بإشراف الأستاذ فداء مأمون البني',
            style: txt.bodySmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.goldDark
                  : AppColors.goldLight,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _sub == 0
              ? _LessonsView(
                  pack: widget.pack,
                  progressStore: widget.progressStore,
                  trainingStore: widget.trainingStore,
                  licenseStore: widget.licenseStore,
                  xpRecorder: widget.xpRecorder,
                  onToggleTheme: widget.onToggleTheme,
                  syncManager: widget.syncManager,
                  fetchLeague: widget.fetchLeague,
                  openDuel: widget.openDuel,
                  openLocalDuel: widget.openLocalDuel,
                  devicePubkeyB64: widget.devicePubkeyB64,
                )
              : _ReviewView(pack: widget.pack),
        ),
      ],
    );
  }
}

class _LessonsView extends StatelessWidget {
  const _LessonsView({
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

  @override
  Widget build(BuildContext context) {
    // نعيد استخدام HomeScreen كمحتوى تبويب الدروس للحفاظ على كل البطاقات
    // الحالية (واصل الدرس، تدريب سريع، بطاقات، تحديات، فكرة اليوم) داخل
    // تبويب المنهاج افتراضياً — النقل الكامل للتبويبات يتم تدريجياً بلا كسر اختبارات.
    return HomeScreen(
      pack: pack,
      progressStore: progressStore,
      trainingStore: trainingStore,
      licenseStore: licenseStore,
      xpRecorder: xpRecorder,
      onToggleTheme: onToggleTheme,
      syncManager: syncManager,
      fetchLeague: fetchLeague,
      openDuel: openDuel,
      openLocalDuel: openLocalDuel,
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.pack});
  final ContentPack pack;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    // المراجعة: تجميع أقسام 🔑/⚠️/⚖️/🧾 حسب الوحدة — placeholder حتى اكتمال المحتوى
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
                    leading: const Icon(Icons.auto_stories_outlined, size: 18),
                    title: Text(u.title, style: txt.bodyMedium),
                    subtitle: Text('${u.chapters.length} دروس', style: txt.bodySmall),
                    onTap: () {
                      // TODO: فتح صفحة مراجعة الوحدة
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('مراجعة ${u.title} — قريباً')),
                      );
                    },
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
    final txt = Theme.of(context).textTheme;
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

class _UnitTrainingView extends StatelessWidget {
  const _UnitTrainingView({required this.pack, required this.trainingStore, this.xpRecorder});
  final ContentPack pack;
  final TrainingStore trainingStore;
  final XpRecorder? xpRecorder;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('اختر وحدة للتدريب', style: txt.titleLarge),
        const SizedBox(height: 8),
        for (final u in pack.units)
          Card(
            child: ListTile(
              leading: const Text('📝', style: TextStyle(fontSize: 20)),
              title: Text(u.title),
              subtitle: Text('${u.chapters.length} دروس'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TrainingScreen(pack: pack, trainingStore: trainingStore, xpRecorder: xpRecorder),
              )),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Text('🔀', style: TextStyle(fontSize: 20)),
            title: const Text('مختلط — من كل الوحدات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => TrainingScreen(pack: pack, trainingStore: trainingStore, xpRecorder: xpRecorder),
            )),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.style_outlined),
            title: const Text('بطاقات اليوم'),
            subtitle: const Text('مراجعة متباعدة — FSRS'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => CardsScreen(pack: pack, trainingStore: trainingStore, xpRecorder: xpRecorder),
            )),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('أخطائي'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MistakesScreen(pack: pack, trainingStore: trainingStore, xpRecorder: xpRecorder),
            )),
          ),
        ),
      ],
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
