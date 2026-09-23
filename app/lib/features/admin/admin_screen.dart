// ═══════════════════════════════════════════════════════════════════════
// admin_screen.dart — لوحة إدارة المكتب المخفية (F6.1-إدارة — قرار المالك
// 2026-09-14): عداد المشتركين + لائحة + إلغاء اشتراك + توليد أكواد.
// ⚠️ لا يصل إليها الطالب: المدخل نقرة سرية (٥ نقرات على الترحيب بالرئيسية)
// وبعدها بوابة مفتاح المكتب OFFICE_KEY الذي يدخله المالك مرة ويعيش في
// الخزنة الآمنة بجهازه حصراً. بلا المفتاح: FORBIDDEN 403 ⇒ لا شيء يُعرض.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cert/certificate.dart' show currentSeason;
import '../../core/review/review_mode.dart';
import '../../core/supabase/office_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/arabic_number.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.api, this.vault});

  /// حقن للاختبارات (بلا شبكة/خزنة) — null = الحقيقيان.
  final OfficeApi? api;
  final OfficeKeyVault? vault;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final OfficeApi _api = widget.api ?? OfficeApi();
  late final OfficeKeyVault _vault = widget.vault ?? OfficeKeyVault();

  bool _loading = true;
  bool _unlocked = false;
  String _error = '';

  String _key = '';
  bool _busy = false;

  // وضع المراجعة (F2.4/F6.2) — يُفعَّل على جهاز الأستاذ قبل التسليم
  final ReviewModeStore _reviewStore = ReviewModeStore();
  bool _reviewOn = false;

  OfficeStats _stats = const OfficeStats(
    issued: 0,
    activated: 0,
    revoked: 0,
    activeLicenses: 0,
  );
  List<Subscriber> _subs = const <Subscriber>[];
  String _filter = 'activated'; // activated | issued | revoked | all
  String _query = ''; // بحث POS: كود أو اسم زبون

  // F6.6 — إدارة الموسم (الموسم الحالي محسوب محلياً؛ الحالة من الخادم)
  final String _season = currentSeason();
  SeasonInfo? _seasonInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    _reviewOn = await _reviewStore.isEnabled();
    final saved = await _vault.read();
    if (saved == null) {
      setState(() => _loading = false);
      return;
    }
    _key = saved;
    final ok = await _refresh();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _unlocked = ok;
    });
  }

  /// يجرّب المفتاح الحالي ويحمّل الأرقام — false عند 403 (مفتاح قديم).
  Future<bool> _refresh() async {
    try {
      final (stats, subs) = await _api.stats(_key);
      if (!mounted) return true;
      setState(() {
        _stats = stats;
        _subs = subs;
        _error = '';
      });
      unawaited(_loadSeason());
      return true;
    } on OfficeApiException catch (e) {
      if (e.forbidden) {
        if (mounted) {
          setState(() => _error = 'المفتاح غير صحيح أو تغيّر — أعد إدخاله');
        }
        await _vault.clear();
        return false;
      }
      if (mounted) {
        setState(() => _error = 'تعذر الوصول: ${e.message}');
      }
      return true; // خطأ شبكة مؤقت — نبقى بالمفتاح
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال — تأكد من الشبكة');
      return true;
    }
  }

  Future<void> _unlock() async {
    final key = _key.trim();
    if (key.isEmpty) {
      setState(() => _error = 'أدخل مفتاح المكتب');
      return;
    }
    setState(() => _busy = true);
    final ok = await _refresh();
    if (ok) await _vault.write(key);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _unlocked = ok;
    });
  }

  Future<void> _lock() async {
    await _vault.clear();
    if (!mounted) return;
    setState(() {
      _unlocked = false;
      _subs = const <Subscriber>[];
      _stats = const OfficeStats(
        issued: 0,
        activated: 0,
        revoked: 0,
        activeLicenses: 0,
      );
    });
  }

  /// قرار ٥٥: كود واحد موسوم «مراجعة» — على جهاز الأستاذ تفتح ٥ نقرات
  /// وضع المراجعة بدل لوحة الإدارة. يُرسل له بواتساب مع التطبيق.
  Future<void> _generateReview() async {
    final sure = await _confirm(
      'كود مراجعة للأستاذ؟',
      'كود تفعيل عادي (٣٠ يوماً، جهاز واحد) لكنه يفتح وضع المراجعة على '
          'جهازه بخمس نقرات على الترحيب. لا يُعطى لطالب.',
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final codes = await _api.generate(_key, count: 1, review: true);
      if (!mounted) return;
      await _showCodes(codes);
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل التوليد: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  /// نقطة البيع (قرار ٣٤): بيع واحد وجهاً لوجه — اسم الزبون ⇒ كود واحد
  /// يُولَّد لحظياً ⇒ بطاقة تسليم (نسخ / واتساب).
  Future<void> _sell() async {
    final customer = await _askCustomer();
    if (customer == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final codes = await _api.generate(_key, count: 1, customer: customer);
      if (!mounted) return;
      await _showSale(codes.first, customer);
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل البيع: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<String?> _askCustomer({String initial = ''}) async {
    var value = initial;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيع اشتراك 🧾'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اسم الطالب (وهاتفه إن شئت) — يبقى عند المكتب فقط.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: initial,
                autofocus: true,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                onChanged: (v) => value = v,
                decoration: const InputDecoration(
                  hintText: 'مثال: أحمد خالد — 09xx',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إصدار الكود'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final v = value.trim();
    if (v.isEmpty) {
      _toast('اكتب اسم الطالب أولاً');
      return null;
    }
    return v;
  }

  Future<void> _showSale(String code, String customer) async {
    if (!mounted) return;
    final msg = AdminSaleMessage.build(code, customer);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم الإصدار ✅'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(customer, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              SelectableText(
                code,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'الكود صالح لجهازين. سلّمه للطالب الآن.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تم'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: msg));
              if (ctx.mounted) Navigator.of(ctx).pop();
              _toast('نُسخت رسالة التسليم');
            },
            icon: const Icon(Icons.copy),
            label: const Text('نسخ الرسالة'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(
                'https://wa.me/?text=${Uri.encodeComponent(msg)}',
              );
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!ok) {
                await Clipboard.setData(ClipboardData(text: msg));
                _toast('واتساب غير متاح — نُسخت الرسالة');
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.send),
            label: const Text('واتساب'),
          ),
        ],
      ),
    );
  }

  /// تعديل اسم الزبون على كود قائم (بيع قديم بلا اسم).
  Future<void> _editCustomer(Subscriber s) async {
    final name = await _askCustomer(initial: s.customer ?? '');
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.note(_key, s.code, name);
      if (mounted) _toast('حُفظ الاسم');
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل الحفظ: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  /// F6.6 — يقرأ حالة الموسم الحالي (بصمت؛ خطأ الشبكة لا يزعج المكتب).
  Future<void> _loadSeason() async {
    try {
      final info = await _api.seasonInfo(_key, _season);
      if (mounted) setState(() => _seasonInfo = info);
    } catch (_) {
      // صامت — البطاقة تعرض «تعذّر التحميل» ضمنياً ببقاء _seasonInfo=null.
    }
  }

  /// F6.6 — ضبط أو مسح نهاية الموسم (قرار ٣٦ — الإغلاق بيد المالك).
  Future<void> _editSeasonEnd() async {
    final info = _seasonInfo;
    final initial = info?.endsOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial != null
          ? (DateTime.tryParse(initial) ?? DateTime.now())
          : DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'تاريخ نهاية الموسم $_season',
    );
    if (picked == null || !mounted) return;
    final iso = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    final sure = await _confirm(
      'إغلاق الموسم $_season بتاريخ $iso؟',
      'بعد مضيّ هذا التاريخ يصبح إصدار الشهادات مفتوحاً للطلاب المستحقّين. '
      'يمكنك تغييره أو إعادة الفتح لاحقاً.',
      confirmLabel: 'حفظ',
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await _api.setSeasonEnd(_key, _season, iso);
      if (mounted) {
        setState(() => _seasonInfo = res);
        _toast('نهاية الموسم = $iso');
      }
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل الحفظ: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// F6.6 — إعادة فتح الموسم (مسح ends_on).
  Future<void> _reopenSeason() async {
    final sure = await _confirm(
      'إعادة فتح الموسم $_season؟',
      'يُلغى تاريخ النهاية ويعود الموسم مفتوحاً — يتوقّف إصدار شهادات جديدة له.',
      confirmLabel: 'إعادة الفتح',
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await _api.setSeasonEnd(_key, _season, null);
      if (mounted) {
        setState(() => _seasonInfo = res);
        _toast('أُعيد فتح الموسم');
      }
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    final count = await _askCount();
    if (count == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final codes = await _api.generate(_key, count: count);
      if (!mounted) return;
      await _showCodes(codes);
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل التوليد: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _revoke(Subscriber s) async {
    final sure = await _confirm(
      'إلغاء ${s.code}؟',
      'سيُسحب الاشتراك وتُرفض تجديداته فور أول اتصال للجهاز.',
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.revoke(_key, s.code);
      if (mounted) _toast('أُلغي ${s.code}');
    } on OfficeApiException catch (e) {
      if (mounted) _toast('فشل الإلغاء: ${e.message}');
    } catch (_) {
      if (mounted) _toast('تعذر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<int?> _askCount() async {
    var count = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('توليد أكواد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('عدد الأكواد (عند الطلب فقط — قرار ٣٤)'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in const [1, 2, 5, 10])
                    ChoiceChip(
                      label: Text(ArabicNumber.from(n)),
                      selected: count == n,
                      onSelected: (_) => setD(() => count = n),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('توليد'),
            ),
          ],
        ),
      ),
    );
    return ok == true ? count : null;
  }

  Future<bool?> _confirm(String title, String body,
          {String confirmLabel = 'تأكيد الإلغاء'}) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  Future<void> _showCodes(List<String> codes) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أكواد جاهزة للبيع 🎫'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in codes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  c,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تم'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codes.join('\n')));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('نسخ الكل'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _unlocked ? _buildDashboard() : _buildLock();
  }

  // ═════════════ بوابة المفتاح ═════════════
  Widget _buildLock() {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔐', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text('إدارة المكتب', style: txt.titleLarge),
              const SizedBox(height: 6),
              Text(
                'هذه الشاشة للمالك حصراً — أدخل مفتاح المكتب '
                '(OFFICE_KEY) لفتح العداد والإدارة.',
                textAlign: TextAlign.center,
                style: txt.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (v) => _key = v,
                decoration: const InputDecoration(
                  hintText: 'مفتاح المكتب',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: const Text('فتح'),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: txt.bodyMedium?.copyWith(color: _danger(context)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════ لوحة الإدارة ═════════════
  Widget _buildDashboard() {
    final txt = Theme.of(context).textTheme;
    final shown = _subs
        .where((s) => _filter == 'all' || s.status == _filter)
        .where((s) => s.matches(_query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المكتب 🗂'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'قفل',
            onPressed: _lock,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── العداد الرئيسي: المشتركون ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('المشتركون الحاليون', style: txt.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    ArabicNumber.from(_stats.activated),
                    style: txt.displayMedium?.copyWith(
                      color: _brand(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        'مصدرون ${ArabicNumber.from(_stats.issued)}',
                        null,
                      ),
                      _StatChip(
                        'ملغاة ${ArabicNumber.from(_stats.revoked)}',
                        null,
                      ),
                      _StatChip(
                        'رخص نشطة ${ArabicNumber.from(_stats.activeLicenses)}',
                        _gold(context),
                      ),
                    ],
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      style: txt.bodySmall?.copyWith(color: _danger(context)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── وضع المراجعة (جهاز الأستاذ) ──
          Card(
            child: SwitchListTile(
              title: const Text('وضع المراجعة (للأستاذ)'),
              subtitle: const Text(
                'لهذا الجهاز فقط (لتجربتك). الأستاذ يحصل عليه بـ«كود مراجعة» '
                'أدناه ثم ٥ نقرات على الترحيب. يسري بعد إعادة التشغيل.',
              ),
              secondary: const Icon(Icons.rate_review_outlined),
              value: _reviewOn,
              onChanged: (v) async {
                await _reviewStore.setEnabled(v);
                if (!mounted) return;
                setState(() => _reviewOn = v);
                _toast(
                  v
                      ? 'وضع المراجعة مفعّل — أغلق التطبيق وافتحه'
                      : 'وضع المراجعة مطفأ — أغلق التطبيق وافتحه',
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // ── F6.6: إدارة الموسم (نهاية الموسم = بوابة الشهادات) ──
          Card(
            key: const Key('season_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined),
                      const SizedBox(width: 8),
                      Text('دوري الموسم $_season', style: txt.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final info = _seasonInfo;
                    if (info == null) {
                      return Text('… تحميل حالة الموسم',
                          style: txt.bodySmall);
                    }
                    final line = info.endsOn == null
                        ? 'مفتوح — لا شهادات بعد'
                        : info.closed
                            ? 'مغلق منذ ${info.endsOn} — الشهادات متاحة ✅'
                            : 'ينتهي ${info.endsOn} — الشهادات بعده';
                    return Text(line,
                        style: txt.bodyMedium?.copyWith(
                          color: info.closed ? _gold(context) : null,
                          fontWeight: FontWeight.w700,
                        ));
                  }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('season_set_end'),
                          onPressed: _busy ? null : _editSeasonEnd,
                          icon: const Icon(Icons.event),
                          label: Text(_seasonInfo?.endsOn == null
                              ? 'تحديد نهاية الموسم'
                              : 'تعديل التاريخ'),
                        ),
                      ),
                      if (_seasonInfo?.endsOn != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('season_reopen'),
                            onPressed: _busy ? null : _reopenSeason,
                            icon: const Icon(Icons.lock_open),
                            label: const Text('إعادة الفتح'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── نقطة البيع (قرار ٣٤): بيع واحد باسم الزبون ──
          FilledButton.icon(
            key: const Key('pos_sell'),
            onPressed: _busy ? null : _sell,
            icon: const Icon(Icons.point_of_sale),
            label: const Text('بيع اشتراك — كود باسم الطالب 🧾'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('دفعة أكواد 🎫'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _generateReview,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('كود مراجعة 📝'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── بحث: كود أو اسم زبون ──
          TextField(
            key: const Key('pos_search'),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث بالكود أو باسم الطالب',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _query = ''),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // ── فلترة ──
          Wrap(
            spacing: 8,
            children: [
              for (final f in const [
                ('activated', 'مشتركون'),
                ('issued', 'مصدرون'),
                ('revoked', 'ملغاة'),
                ('all', 'الكل'),
              ])
                ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'لا توجد سجلات في هذه الفئة',
                  style: txt.bodyMedium,
                ),
              ),
            )
          else
            for (final s in shown)
              _SubscriberTile(
                subscriber: s,
                onRevoke: s.status == 'revoked' ? null : () => _revoke(s),
                onEditCustomer: s.review ? null : () => _editCustomer(s),
              ),
        ],
      ),
    );
  }

  // ── ألوان موحّدة ──
  Color _brand(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.brandDark
      : AppColors.brandLight;
  Color _gold(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.goldDark
      : AppColors.goldLight;
  Color _danger(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.dangerDark
      : AppColors.dangerLight;
}

/// رسالة التسليم الجاهزة للطالب (نسخ/واتساب) — نص ثابت قابل للاختبار.
class AdminSaleMessage {
  const AdminSaleMessage._();

  static String build(String code, String customer) => 'أهلاً $customer 👋\n'
      'كود تفعيل «فيزيا كلاش»:\n'
      '$code\n'
      'افتح التطبيق ← أدخل الكود مرة واحدة ← يعمل على جهازين كحد أقصى.\n'
      'للدعم: مكتب لورانيم.';
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.color);

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
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color ?? cs.onSurface),
      ),
    );
  }
}

class _SubscriberTile extends StatelessWidget {
  const _SubscriberTile({
    required this.subscriber,
    this.onRevoke,
    this.onEditCustomer,
  });

  final Subscriber subscriber;
  final VoidCallback? onRevoke;
  final VoidCallback? onEditCustomer;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (label, color) = switch (subscriber.status) {
      'activated' => ('مشترك', dark ? AppColors.goldDark : AppColors.goldLight),
      'revoked' => (
          'ملغى',
          dark ? AppColors.dangerDark : AppColors.dangerLight,
        ),
      _ => ('مصدر', null),
    };
    final date = subscriber.activatedAt ?? subscriber.createdAt ?? '';
    final shortDate = date.length >= 10 ? date.substring(0, 10) : '';

    final who = subscriber.review
        ? 'مراجعة — الأستاذ'
        : (subscriber.customer ?? 'بلا اسم — اضغط لإضافته');
    return Card(
      child: ListTile(
        onTap: onEditCustomer,
        title: Text(
          subscriber.code,
          textDirection: TextDirection.ltr,
          style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            who,
            'أجهزة ${ArabicNumber.from(subscriber.devicesUsed)}/٢',
            if (shortDate.isNotEmpty) 'فعّل $shortDate',
            subscriber.distributor,
          ].join(' · '),
          style: txt.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (color ?? Theme.of(context).dividerColor).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                label,
                style: txt.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRevoke != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'إلغاء الاشتراك',
                onPressed: onRevoke,
                icon: const Icon(Icons.block),
                color: dark ? AppColors.dangerDark : AppColors.dangerLight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
