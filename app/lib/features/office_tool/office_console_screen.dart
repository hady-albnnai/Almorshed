// ═══════════════════════════════════════════════════════════════════════
// office_console_screen.dart — أداة توليد الأكواد المستقلّة (خطوة ٢).
//
// أداة منفصلة تماماً عن تطبيق الطالب: نقطة دخولها lib/office_main.dart.
// تعيد استخدام OfficeApi + OfficeKeyVault فقط — بلا أي اعتماد على شاشة
// الإدارة داخل تطبيق الطالب (حتى يمكن حذفها لاحقاً بلا كسر).
//
// تحمل OFFICE_KEY وحده (يُدخَل مرة ويعيش في الخزنة الآمنة على الجهاز) —
// لا تحمل SIGNING_SEED إطلاقاً؛ التوقيع يجري في الخادم (office_codes).
// ═══════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase/office_api.dart';

class OfficeConsoleScreen extends StatefulWidget {
  const OfficeConsoleScreen({super.key, OfficeApi? api, OfficeKeyVault? vault})
      : _api = api,
        _vault = vault;

  final OfficeApi? _api;
  final OfficeKeyVault? _vault;

  @override
  State<OfficeConsoleScreen> createState() => _OfficeConsoleScreenState();
}

class _OfficeConsoleScreenState extends State<OfficeConsoleScreen> {
  late final OfficeApi _api = widget._api ?? OfficeApi();
  late final OfficeKeyVault _vault = widget._vault ?? OfficeKeyVault();

  bool _loading = true;
  bool _busy = false;
  String? _key;

  OfficeStats _stats = const OfficeStats(
    issued: 0,
    activated: 0,
    revoked: 0,
    activeLicenses: 0,
  );

  final _keyController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  bool _obscureKey = true;

  // قائمة الأكواد المُصدَرة (لمن ولّدنا) — تأتي من stats.subscribers.
  List<Subscriber> _subs = const <Subscriber>[];
  String _query = '';

  List<Subscriber> get _filteredSubs =>
      [for (final s in _subs) if (s.matches(_query)) s];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _countController.dispose();
    _customerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final saved = await _vault.read();
    if (!mounted) return;
    setState(() {
      _key = saved;
      _loading = false;
    });
    if (saved != null) await _refresh();
  }

  // ── بوابة المفتاح: يتحقّق عبر stats ثم يحفظ في الخزنة ──────────────────
  Future<void> _saveKey() async {
    final k = _keyController.text.trim();
    if (k.isEmpty) {
      _toast('أدخل مفتاح المكتب');
      return;
    }
    setState(() => _busy = true);
    try {
      final (stats, subs) = await _api.stats(k); // تحقّق فعلي من صحّة المفتاح
      await _vault.write(k);
      if (!mounted) return;
      setState(() {
        _key = k;
        _stats = stats;
        _subs = subs;
        _keyController.clear();
      });
      _toast('تم الدخول ✅');
    } on OfficeApiException catch (e) {
      _toast(e.status == 401 ? 'مفتاح غير صحيح' : 'فشل التحقّق: ${e.message}');
    } catch (_) {
      _toast('تعذّر الاتصال — تحقّق من الإنترنت');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تبديل المفتاح؟'),
        content: const Text('سيُمحى المفتاح من هذا الجهاز وتعود لبوابة الإدخال.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تبديل')),
        ],
      ),
    );
    if (ok != true) return;
    await _vault.clear();
    if (!mounted) return;
    setState(() => _key = null);
  }

  Future<void> _refresh() async {
    final k = _key;
    if (k == null) return;
    setState(() => _busy = true);
    try {
      final (stats, subs) = await _api.stats(k);
      if (mounted) {
        setState(() {
          _stats = stats;
          _subs = subs;
        });
      }
    } on OfficeApiException catch (e) {
      _toast('تعذّر تحديث الإحصاءات: ${e.message}');
    } catch (_) {
      _toast('تعذّر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── التوليد ────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final k = _key;
    if (k == null) return;
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    if (count < 1 || count > 100) {
      _toast('العدد بين ١ و ١٠٠');
      return;
    }
    final customer = _customerController.text.trim();
    setState(() => _busy = true);
    List<String>? codes;
    try {
      codes = await _api.generate(
        k,
        count: count,
        customer: customer.isEmpty ? null : customer,
      );
    } on OfficeApiException catch (e) {
      _toast(e.status == 401 ? 'مفتاح غير صحيح' : 'فشل التوليد: ${e.message}');
    } catch (_) {
      _toast('تعذّر الاتصال');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // الحوار يُفتح بعد إطفاء المؤشّر (حتى لا يبقى أنيميشن دائم يعلّق الاختبارات).
    if (codes == null || !mounted) return;
    await _showCodes(codes, customer);
    _customerController.clear();
    await _refresh();
  }

  static String _saleMessage(String code, String customer) {
    final hi = customer.isEmpty ? 'أهلاً 👋' : 'أهلاً $customer 👋';
    return '$hi\n'
        'كود تفعيل «فيزيا كلاش»:\n'
        '$code\n'
        'افتح التطبيق ← أدخل الكود مرة واحدة ← يعمل على جهازين كحد أقصى.\n'
        'للدعم: مكتب لورانيم.';
  }

  Future<void> _shareWhatsApp(String text) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: text));
      _toast('واتساب غير متاح — نُسخت الرسالة');
    }
  }

  Future<void> _showCodes(List<String> codes, String customer) async {
    if (!mounted) return;
    final single = codes.length == 1;
    final shareText = single
        ? _saleMessage(codes.first, customer)
        : 'أكواد تفعيل «فيزيا كلاش»:\n${codes.join('\n')}';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(single ? 'تم الإصدار ✅' : 'أُصدرت ${codes.length} أكواد ✅'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (customer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(customer, textAlign: TextAlign.center),
                ),
              for (final c in codes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          c,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ الكود',
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: c));
                          if (ctx.mounted) _toast('نُسخ الكود');
                        },
                      ),
                    ],
                  ),
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
              await Clipboard.setData(ClipboardData(text: shareText));
              if (ctx.mounted) _toast('نُسخت الرسالة');
            },
            icon: const Icon(Icons.description),
            label: const Text('نسخ الرسالة'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await _shareWhatsApp(shareText);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.send),
            label: const Text('واتساب'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('مولّد أكواد فيزيا كلاش'),
        actions: [
          if (_key != null) ...[
            IconButton(
              tooltip: 'تحديث',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'تبديل المفتاح',
              onPressed: _busy ? null : _clearKey,
              icon: const Icon(Icons.key_off),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _key == null ? _buildKeyGate() : _buildConsole(),
      ),
    );
  }

  Widget _buildKeyGate() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 20),
        Icon(Icons.vpn_key, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('أدخل مفتاح المكتب (OFFICE_KEY)',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'يُدخَل مرة واحدة ويُحفَظ في الخزنة الآمنة على هذا الجهاز فقط. '
          'لا يُطبع ولا يُرسَل إلا كترويسة للخادم.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('office-key-field'),
          controller: _keyController,
          obscureText: _obscureKey,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'OFFICE_KEY',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('office-login'),
          onPressed: _busy ? null : _saveKey,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.login),
          label: const Text('حفظ ودخول'),
        ),
      ],
    );
  }

  Widget _buildConsole() {
    final txt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── الإحصاءات ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('حالة المكتب', style: txt.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statChip('صُدر', _stats.issued),
                    _statChip('مُفعّل', _stats.activated),
                    _statChip('ملغى', _stats.revoked),
                    _statChip('رخص فعّالة', _stats.activeLicenses),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // ── توليد ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('توليد أكواد جديدة', style: txt.titleSmall),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('office-count'),
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'العدد (١–١٠٠)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('office-customer'),
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الزبون (اختياري)',
                    helperText: 'يظهر في رسالة التسليم عند توليد كود واحد',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('office-generate'),
                  onPressed: _busy ? null : _generate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.qr_code_2),
                  label: const Text('توليد ونسخ / واتساب'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // ── الأكواد المُصدَرة: لمن ولّدنا (اسم الزبون + الحالة + التاريخ) ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('الأكواد المُصدَرة (${_filteredSubs.length})',
                          style: txt.titleSmall),
                    ),
                    IconButton(
                      tooltip: 'تحديث',
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('office-search'),
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    labelText: 'بحث بالكود أو اسم الزبون',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (_filteredSubs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _subs.isEmpty ? 'لا أكواد بعد' : 'لا نتائج للبحث',
                      textAlign: TextAlign.center,
                      style: txt.bodySmall,
                    ),
                  )
                else
                  for (final s in _filteredSubs) _subTile(s),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(String? iso) =>
      (iso == null || iso.isEmpty) ? '' : iso.split('T').first;

  Widget _subTile(Subscriber s) {
    final cs = Theme.of(context).colorScheme;
    final (String label, Color color) = switch (s.status) {
      'activated' => ('مُفعّل', Colors.green),
      'revoked' => ('ملغى', cs.error),
      _ => ('غير مفعّل', cs.outline),
    };
    final who = (s.customer == null || s.customer!.trim().isEmpty)
        ? (s.review ? 'مراجعة — الأستاذ' : 'بلا اسم')
        : s.customer!;
    final meta = <String>[
      if (_fmtDate(s.createdAt).isNotEmpty) 'تاريخ: ${_fmtDate(s.createdAt)}',
      if (s.devicesUsed > 0) 'أجهزة: ${s.devicesUsed}',
    ].join('   •   ');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(who,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  s.code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'نسخ الكود',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: s.code));
                  _toast('نُسخ الكود');
                },
              ),
            ],
          ),
          if (meta.isNotEmpty)
            Text(meta, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
