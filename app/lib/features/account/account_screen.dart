import 'package:flutter/material.dart';

import 'dart:convert' show base64;

import '../../core/license/license_core.dart';
import '../../core/license/license_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/arabic_number.dart';

/// F3.6 — «حسابي»: إدارة الاشتراك من هنا (قرار ٤٤ — مطابقة s-account):
/// شارة الحالة + إعادة فحص التوقيع المحلي الظاهرة + الانتهاء + لورانيم.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.licenseStore,
      this.devicePubkeyB64 = ''});

  final LicenseStore licenseStore;

  /// مفتاح الجهاز العام — لربط الفحص المحلي (F4.4-تحصين). فارغ = فحص أعمى.
  final String devicePubkeyB64;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  LicenseData? _data;
  String _signLine = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.licenseStore.load();
    if (!mounted) return;
    setState(() {
      _data = d;
      _signLine = '';
    });
  }

  void _recheck() {
    final data = _data;
    final token = data?.token;
    if (token == null) {
      setState(() => _signLine = 'لا توقيع محفوظ — أنت بوضع التجربة');
      return;
    }
    // L4-أرضية رتيبة: الساعة لا تعود خلف آخر زمن معروف (من السيرفر)
    final wall = data?.lastWallMs ?? 0;
    final now = wall > DateTime.now().millisecondsSinceEpoch
        ? wall
        : DateTime.now().millisecondsSinceEpoch;
    final check = checkLicense(token, nowMs: now,
        devicePubkeyBytes: widget.devicePubkeyB64.isEmpty
            ? null
            : base64Decode(widget.devicePubkeyB64));
    setState(() {
      _signLine = check.ok
          ? 'سليم ✓ (محلي، بدون إنترنت)'
          : switch (check.verdict) {
              LicenseVerdict.expired => 'منتهٍ — يلزم التجديد ✗',
              LicenseVerdict.hardPassed => 'تجاوز يوم الامتحان ✗',
              LicenseVerdict.badSignature => 'التوقيع مرفوض ✗',
              LicenseVerdict.wrongDevice => 'توكن جهاز آخر ✗',
              _ => 'بنية فاسدة ✗',
            };
    });
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toUtc();
    return '${ArabicNumber.from(d.day)} / '
        '${ArabicNumber.from(d.month)} / ${ArabicNumber.from(d.year)}';
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? AppColors.goldDark
        : AppColors.goldLight;
    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final licensed = data.mode == LicenseMode.licensed && data.token != null;
    final payload = data.token == null
        ? null
        : _safePayload(
            data.token!,
            (data.lastWallMs > DateTime.now().millisecondsSinceEpoch)
                ? data.lastWallMs
                : DateTime.now().millisecondsSinceEpoch);

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('التفعيل والاشتراك', style: txt.titleMedium),
                      licensed
                          ? Chip(
                              avatar: const Icon(Icons.verified_outlined,
                                  size: 16),
                              label: const Text('✓ مفعّل'),
                              backgroundColor:
                                  Colors.green.withValues(alpha: .15))
                          : Chip(
                              avatar: const Icon(Icons.science_outlined,
                                  size: 16),
                              label: const Text('وضع تجريبي')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (licensed && payload != null) ...[
                    _row(txt, 'كود التفعيل', maskCodeId(payload.codeId)),
                    if (data.activatedAtMs != null)
                      _row(txt, 'التفعيل تم', _fmtDate(data.activatedAtMs!)),
                    const SizedBox(height: 8),
                    Text(
                      'ينتهي في: ${_fmtDate(payload.expiresAtMs)}\n'
                      'الحد الصلب: يوم الامتحان (docs/11 — ٢٠٢٧/٠٥/٠١)',
                      style: txt.bodyMedium,
                    ),
                  ] else
                    Text(
                      'أنت بوضع التجربة — أدخل كوداً من مكتبنا '
                      'لفتح المنهاج الكامل وبنك الأسئلة',
                      style: txt.bodyMedium,
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recheck,
                    child: const Text('⟲ إعادة فحص التوقيع الآن'),
                  ),
                  // ⚠️ ردّة الفحص تُعرض هنا حصراً — كانت داخل فرع «مفعّل»
                  // فزر التجربة يردّ في الفراغ (بق عرض أصلحه لصقة المالك ٩)
                  if (_signLine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _signLine,
                        style: txt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('الأجهزة المربوطة'),
              subtitle: const Text(
                  'تغيّر موبايلك؟ مرّ على مكتبنا وإعادة الربط دقيقة واحدة'),
              trailing: const Chip(label: Text('٢ / ٢')),
            ),
          ),
          const SizedBox(height: 8),
          Text('loraneem-tech', style: txt.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'فيزيا كلاش — Clash of Physics\n'
            'منهاج الثالث الثانوي العلمي · الإصدار 1.0\n'
            'التطوير والتصميم: loraneem-tech',
            style: txt.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '✓ المادة العلمية راجعتها: الأستاذ فداء البني',
            style: txt.bodySmall?.copyWith(color: gold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'فيزيا كلاش © 2026 — loraneem-tech\nيعمل بدون إنترنت بعد التفعيل',
            style: txt.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  LicensePayload? _safePayload(LicenseToken token, int nowMs) =>
      checkLicense(token, nowMs: nowMs).payload;

  Widget _row(TextTheme txt, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: txt.bodyMedium),
            Text(v, style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
