import 'dart:async';

import 'package:flutter/material.dart';

import 'core/license/heartbeat_client.dart';
import 'core/license/license_store.dart';
import 'core/xp/streak_service.dart';
import 'core/content/content_loader.dart';
import 'core/content/models.dart';
import 'core/crypto/content_key_vault.dart';
import 'core/crypto/device_key_vault.dart';
import 'core/crypto/kc_provision.dart';
import 'core/db/app_database.dart';
import 'core/db/drift_stores.dart';
import 'core/db/legacy_migration.dart';
import 'core/progress/progress_store.dart';
import 'core/progress/shared_prefs_store.dart';
import 'core/review/review_mode.dart';
import 'core/theme/app_theme.dart';
import 'core/training/shared_prefs_training_store.dart';
import 'core/training/training_store.dart';
import 'core/xp/xp_signer.dart';
import 'core/xp/xp_store.dart';
import 'core/supabase/activation_api.dart';
import 'core/supabase/http_xp_sync_api.dart';
import 'core/supabase/league_api.dart';
import 'core/supabase/cert_api.dart';
import 'core/sync/sync_engine.dart';
import 'core/sync/sync_manager.dart';
import 'core/sync/sync_store.dart';
import 'core/supabase/anonymous_auth.dart';
import 'core/supabase/supabase_transport.dart';
import 'core/supabase/duel_api.dart';
import 'core/supabase/realtime_client.dart';
import 'core/duel/duel_engine.dart';
import 'core/duel/duel_flow.dart';
import 'core/duel/local_duel_flow.dart';
import 'core/duel/local_link.dart';
import 'features/activation/activation_gate.dart';
import 'features/curriculum/curriculum_screen.dart';
import 'features/review/review_widgets.dart';
import 'features/shell/app_shell.dart';

void main() => runApp(const FizyaClashApp());

/// فيزيا كلاش — Clash of Physics
/// المهمة الحالية F3.1: التقدم الحقيقي المحفوظ.
class FizyaClashApp extends StatefulWidget {
  const FizyaClashApp({
    super.key,
    this.packLoader,
    this.progressStore,
    this.trainingStore,
    this.licenseStore,
    this.xpRecorder,
    this.activationApiOverride,
    this.startOnHome =
        true, // الإنتاج: الرئيسية أولاً (F3.8) — الاختبارات تمرّر false صراحة
  });

  /// حقن للاختبارات؛ الافتراضي يحمّل حزمة assets الحقيقية.
  final Future<ContentPack> Function()? packLoader;

  /// حقن مخزن التقدم؛ الافتراضي shared_preferences (قرار ٥٧).
  final ProgressStore? progressStore;

  /// حقن مخزن التدريب (F3.3)؛ الافتراضي shared_preferences.
  final TrainingStore? trainingStore;

  /// حقن واجهة التفعيل (F4.4) — للاختبارات حصراً؛ الافتراضي: الخادم الحقيقي.
  final ActivationApi? activationApiOverride;

  /// حقن مخزن الترخيص (F3.6)؛ الافتراضي shared_preferences.
  final LicenseStore? licenseStore;

  /// حقن مُسجّل XP (F3.8)؛ الافتراضي مشترك (Prefs + خزنة آمنة).
  final XpRecorder? xpRecorder;

  /// F3.8: الرئيسية شاشة الانطلاق بعد البوابة.
  final bool startOnHome;

  @override
  State<FizyaClashApp> createState() => _FizyaClashAppState();
}

class _FizyaClashAppState extends State<FizyaClashApp> {
  ThemeMode _mode = ThemeMode.dark; // docs/13: الداكن أولاً

  late Future<ContentPack> _packFuture = _loadPackForMode();

  // ── وضع المراجعة (F2.4 + F6.2 المبسّط — جهاز الأستاذ فقط) ──
  bool _reviewMode = false;
  Set<int> _unapprovedIds = const {};
  final ReviewNotesStore _reviewNotes = ReviewNotesStore();

  /// الحزمة كما يراها هذا الجهاز: الطالب ⇒ الأصل (F2.4: غير المعتمد محجوب
  /// بالفلاتر القائمة)؛ الأستاذ (وضع المراجعة) ⇒ كل الأسئلة مفتوحة للعرض.
  Future<ContentPack> _loadPackForMode() async {
    final original = await (widget.packLoader ?? _defaultLoadPack)();
    final on = widget.packLoader == null && await ReviewModeStore().isEnabled();
    if (!on) return original;
    _sync.suspended = true; // لا تلويث للدوري بجلسات الأستاذ
    final ids = unapprovedQuestionIds(original);
    // العلم يُقرأ في MaterialApp.builder (فوق الـNavigator) ⇒ إعادة بناء صريحة
    if (mounted) {
      setState(() {
        _reviewMode = true;
        _unapprovedIds = ids;
      });
    } else {
      _reviewMode = true;
      _unapprovedIds = ids;
    }
    return openAllForReview(original);
  }

  LicenseStore get _license => widget.licenseStore ?? SharedPrefsLicenseStore();

  // F3.1 — قاعدة Drift المشفّرة المشتركة. كسولة (تُفتح عند أول وصول فقط) فلا
  // تُلمس في الاختبارات التي تحقن المخازن صراحةً — كنمط _contentKeys.
  AppDatabase? _db;
  AppDatabase get _database => _db ??= AppDatabase();

  // مخازن Drift الافتراضية للإنتاج (تُبنى مرة واحدة فوق القاعدة المشتركة).
  DriftProgressStore? _driftProgress;
  DriftProgressStore get _defaultProgressStore =>
      _driftProgress ??= DriftProgressStore(_database);

  DriftTrainingStore? _driftTraining;
  DriftTrainingStore get _defaultTrainingStore =>
      _driftTraining ??= DriftTrainingStore(_database);

  XpRecorder? _sharedRecorder;
  // الإنتاج: دفتر XP على Drift المشفّر + خزنة المفتاح الآمنة. الاختبارات
  // تحقن widget.xpRecorder (بالذاكرة) فلا تُفتح القاعدة.
  XpRecorder get _xpRecorder =>
      widget.xpRecorder ??
      (_sharedRecorder ??= XpRecorder(
        store: DriftXpEventStore(_database),
        vault: SecureXpKeyVault(),
      ));

  // F4.4 — نقلية الخادم الحقيقية (بناء بلا IO — آمن بالاختبارات)
  late final ActivationApi _activationApi =
      widget.activationApiOverride ??
      () {
        final t = SupabaseTransport();
        return ActivationApi(
          transport: t,
          auth: AnonymousAuth(transport: t, store: SharedPrefsSessionStore()),
          contentKeys: _contentKeys,
        );
      }();

  // F2.2-T2 — تزويد K_c (قرار ٣٠): زوج X25519 للجهاز + خزنة مفتاح المحتوى.
  // بناء بلا IO — الخزنتان تُقرآن عند أول استعمال فقط (آمن بالاختبارات).
  late final ContentKeyProvisioner _contentKeys = ContentKeyProvisioner(
    deviceKeys: SecureDeviceKeyVault(),
    contentKeys: SecureContentKeyVault(),
  );
  String? _pubkeyB64;

  // F4.5/F4.6 — الشبكة المشتركة: نقلية واحدة وجلسة واحدة للكل
  late final SupabaseTransport _net = SupabaseTransport();
  late final AnonymousAuth _netAuth = AnonymousAuth(
    transport: _net,
    store: SharedPrefsSessionStore(),
  );

  /// مُشغّل المزامنة — يُبنى محركه عند أول جولة (المفتاح العام وقتها محمّل).
  late final SyncManager _sync = SyncManager(
    engineFactory: () async {
      final pk = _pubkeyB64;
      if (pk == null) throw StateError('المفتاح العام غير محمّل بعد');
      return SyncEngine(
        api: HttpXpSyncApi(transport: _net, auth: _netAuth),
        stateStore: SharedPrefsSyncStateStore(),
        loadEvents: _xpRecorder.ledger.events,
        devicePubkeyB64: pk,
      );
    },
  );

  /// واجهة الدوري (قراءة RLS للمفعّلين حصراً).
  late final LeagueApi _leagueApi = LeagueApi(transport: _net, auth: _netAuth);

  /// واجهة شهادة الموسم (F6.5) — مُصدِر كسول يوقّع تحدّيه بمفتاح الجهاز (XP).
  late final LazyCertApi _certApi = LazyCertApi(
    transport: _net,
    auth: _netAuth,
    signerLoader: () => _xpRecorder.signer(),
  );

  /// واجهة المبارزات (F5.3) — نفس النقلية والجلسة المشتركتين.
  late final DuelApi _duelApi = DuelApi(_net);

  /// فتح تدفق مبارزة — جلسة صالحة + معرّف الجهاز + ناقل حي + حكم XP.
  Future<DuelFlow> _openDuelFlow(ContentPack pack) async {
    final session = await _netAuth.session();
    final deviceId =
        await _duelApi.myDeviceId(
          accessToken: session.accessToken,
          pubkeyB64: _pubkeyB64 ?? '',
        ) ??
        '';
    if (deviceId.isEmpty) {
      throw StateError('الجهاز غير مسجّل بعد');
    }
    return DuelFlow(
      gateway: ApiDuelGateway(_duelApi),
      wireFactory: () => RealtimeDuelWire(
        SupabaseRealtime(baseUrl: _net.baseUrl, anonKey: _net.anonKey),
      ),
      deviceId: deviceId,
      accessToken: session.accessToken,
      buildSession: (seed, scope) =>
          buildDuelSession(pack, seed: seed, scope: scope),
      xpSink: (typeId, extra) async {
        await _xpRecorder.record(typeId, extra: extra);
      },
    );
  }

  /// فتح تدفق مبارزة محلية (F5.4) — بلا سيرفر وبلا GMS، يعمل على أي جهاز.
  LocalDuelFlow _openLocalDuelFlow(ContentPack pack) => LocalDuelFlow(
    transport: TcpDuelTransport(),
    deviceId: _localDeviceId(),
    myName: _localName(),
    buildSession: (seed, scope) =>
        buildDuelSession(pack, seed: seed, scope: scope),
  );

  /// معرّف جهاز محلي مستقر من المفتاح العام (بلا شبكة ولا سيرفر).
  String _localDeviceId() {
    final pk = _pubkeyB64;
    if (pk == null || pk.isEmpty) {
      return 'dev-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    }
    var h = 0;
    for (final u in pk.codeUnits) {
      h = (h * 31 + u) & 0x7FFFFFFF;
    }
    return 'dev-${h.toRadixString(16)}';
  }

  /// اسم عرض محلي قصير مستقر (مقبض ٤ محارف Crockford من المفتاح العام).
  String _localName() {
    final pk = _pubkeyB64;
    if (pk == null || pk.isEmpty) return 'اللاعب';
    var h = 0;
    for (final u in pk.codeUnits) {
      h = (h * 31 + u) & 0x3FFFFFFF;
    }
    final buf = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buf.write(RoomCode.alphabet[h & 31]);
      h >>= 5;
    }
    return 'لاعب ${buf.toString()}';
  }

  late Future<LicenseData> _licenseFuture = _license.load();

  @override
  void initState() {
    super.initState();
    _migrateLegacyIfNeeded();
    _loadPubkey();
  }

  /// F3.1 — ترحيل لمرة واحدة من shared_preferences إلى Drift (صامت، لا يحجب
  /// الإقلاع). يُتخطّى في الاختبارات التي تحقن المخازن (لا قاعدة حقيقية تُفتح).
  void _migrateLegacyIfNeeded() {
    final injected = widget.progressStore != null ||
        widget.trainingStore != null ||
        widget.xpRecorder != null;
    if (injected) return; // بيئة اختبار/حقن — لا ترحيل ولا فتح قاعدة.
    unawaited(
      LegacyMigration(
        db: _database,
        legacyProgress: SharedPrefsProgressStore(),
        legacyTraining: SharedPrefsTrainingStore(),
        legacyXp: SharedPrefsXpEventStore(),
      ).runIfNeeded(),
    );
  }

  Future<void> _loadPubkey() async {
    final k = await _xpRecorder.publicKeyB64();
    if (!mounted) return;
    setState(() => _pubkeyB64 = k);
    // F7.4: نبض الترخيص عند الانطلاق — صامت، لا يحجب شيئاً، يرفع أرضية
    // الساعة من السيرفر ويجدّد التوكن بآخر ٧ أيام (docs/11 §٥ + L4).
    // (الاختبارات تحقن activationApiOverride ⇒ لا شبكة حقيقية ⇒ لا نبض.)
    if (widget.activationApiOverride == null && k.isNotEmpty) {
      _heartbeat ??= HeartbeatClient(
        transport: _net,
        auth: _netAuth,
        store: _license,
        devicePubkeyB64: k,
        contentKeys: _contentKeys,
      );
      unawaited(
        _heartbeat!.beat().then((o) {
          if (o.renewed || o.clockSuspected) _reloadLicense();
          // F2.2-T2: وصل K_c لأول مرة ⇒ أعد تحميل الحزمة (المسار المشفّر)
          if (o.contentKeyReceived) _reloadPack();
        }),
      );
    }
  }

  /// نبض الترخيص (F7.4) — يُبنى بعد تحميل المفتاح العام.
  HeartbeatClient? _heartbeat;

  void _reloadLicense() => setState(() {
    _licenseFuture = _license.load();
  });

  /// F2.2-T2: بعد وصول K_c (تفعيل/نبض) تُعاد قراءة الحزمة بالمسار المشفّر.
  /// محمّل جديد ⇒ لا ذاكرة مؤقتة قديمة؛ والفشل يُترك للـFutureBuilder.
  void _reloadPack() {
    if (!mounted) return;
    setState(() {
      _packFuture = _loadPackForMode();
    });
  }

  // قرار ٣٠: بوجود K_c بالخزنة تُقرأ الحزمة مشفرة pack_seal_v1؛ وإلا النصية.
  static Future<ContentPack> _defaultLoadPack() =>
      ContentLoader(keys: SecureContentKeyVault()).loadPack();

  void _toggleTheme() => setState(() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فيزيا كلاش — Clash of Physics',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl, // التطبيق عربي بالكامل
        // وضع المراجعة **فوق الـNavigator**: كان تحت `home` فلا تراه الشاشات
        // المدفوعة بـpush (دفعة التدريب، الدرس، ملاحظاتي…) ⇒ ✏️ والشريط
        // مخفيان هناك. الآن الشجرة كلها — بما فيها المسارات — تراه.
        child: ReviewScope(
          enabled: _reviewMode,
          unapprovedQuestionIds: _unapprovedIds,
          notes: _reviewNotes,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: FutureBuilder<ContentPack>(
        future: _packFuture,
        builder: _buildRoot,
      ),
    );
  }

  Widget _buildRoot(BuildContext context, AsyncSnapshot<ContentPack> snap) {
    {
      if (snap.connectionState != ConnectionState.done) {
        return const _Splash();
      }
      if (snap.hasError || !snap.hasData) {
        return _ErrorView(error: snap.error);
      }
      return FutureBuilder<LicenseData>(
        future: _licenseFuture,
        builder: (context, licSnap) {
          if (licSnap.connectionState != ConnectionState.done) {
            return const _Splash();
          }
          final license = licSnap.data ?? const LicenseData();
          if (license.mode == LicenseMode.none) {
            // F3.6: بوابة أول فتح — تظهر مرة واحدة ثم من «حسابي»
            if (_pubkeyB64 == null) return const _Splash();
            return ActivationGate(
              licenseStore: _license,
              onModeSet: () {
                _reloadLicense();
                _reloadPack(); // F2.2-T2: K_c قد وصل مع التفعيل
              },
              activationApi: _activationApi,
              devicePubkeyB64: _pubkeyB64!,
            );
          }
          // A2 — الهيكل الجديد (قرار 58): 3 تبويبات، الافتراضي المنهاج
          if (widget.startOnHome) {
            return AppShell(
              pack: snap.data!,
              progressStore: widget.progressStore ?? _defaultProgressStore,
              trainingStore: widget.trainingStore ?? _defaultTrainingStore,
              licenseStore: _license,
              xpRecorder: _xpRecorder,
              onToggleTheme: _toggleTheme,
              syncManager: _sync,
              fetchLeague: () => _leagueApi.fetch(_pubkeyB64 ?? ''),
              openDuel: () => _openDuelFlow(snap.data!),
              openLocalDuel: () => _openLocalDuelFlow(snap.data!),
              devicePubkeyB64: _pubkeyB64 ?? '',
              certApi: _certApi,
            );
          }
          return CurriculumScreen(
            pack: snap.data!,
            onToggleTheme: _toggleTheme,
            progressStore: widget.progressStore ?? _defaultProgressStore,
            trainingStore: widget.trainingStore ?? _defaultTrainingStore,
            licenseStore: _license,
            xpRecorder: _xpRecorder,
            devicePubkeyB64: _pubkeyB64 ?? '',
          );
        },
      );
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 12),
              Text('تعذر تحميل المحتوى', style: txt.titleLarge),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: txt.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
