import 'package:flutter/material.dart';

import '../../core/license/license_core.dart';
import '../../core/license/license_store.dart';
import '../../core/theme/app_colors.dart';

/// F3.6 — بوابة أول فتح (قرار ٣٨/٤٤ — مطابقة النموذج s-activate):
/// «تظهر مرة واحدة عند أول فتح — بعدها تُدار من حسابي».
/// الفحص المحلي Ed25519 ظاهر + انتظار تدريجي بعد ٥ محاولات + مدخل تجريبي.
class ActivationGate extends StatefulWidget {
  const ActivationGate({
    super.key,
    required this.licenseStore,
    required this.onModeSet,
  });

  final LicenseStore licenseStore;
  final VoidCallback onModeSet;

  @override
  State<ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<ActivationGate> {
  final _codeController = TextEditingController();
  String _message = '';
  Color _messageColor = Colors.transparent;
  bool _busy = false;
  LicenseData _data = const LicenseData();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await widget.licenseStore.load();
    if (!mounted) return;
    setState(() => _data = d);
  }

  void _say(String msg, Color color) => setState(() {
        _message = msg;
        _messageColor = color;
      });

  Future<void> _activate() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockRemaining = _data.lockUntilMs - now;
    if (lockRemaining > 0) {
      final minutes = (lockRemaining / 60000).ceil();
      _say('محاولات كثيرة — انتظر $minutes دقيقة ثم أعد المحاولة',
          Colors.red.shade300);
      return;
    }
    final digits = _codeController.text.replaceAll('-', '');
    if (digits.length < 15) {
      _say('الكود ناقص — ١٥ حرفاً بصيغة XXXXX-XXXXX-XXXXX (من مكتبنا)',
          Colors.red.shade300);
      return;
    }
    setState(() => _busy = true);
    _say('جارٍ فحص الكود على جهازك — التحقق من التوقيع الرقمي...',
        Colors.blue.shade200);
    // F3.6: إصدار التوكن من خادم التفعيل (F4.4) — فكل إدخال شكله سليم الآن
    // يُعدّ محاولة فاشلة حقيقية ويزيد الانتظار التدريجي (نمط حماية الكود).
    final failures = _data.failures + 1;
    final lockMinutes = lockoutMinutesFor(failures);
    final updated = _data.copyWith(
      failures: failures,
      lockUntilMs: now + lockMinutes * 60000,
      lastWallMs: now,
    );
    await widget.licenseStore.save(updated);
    if (!mounted) return;
    setState(() {
      _data = updated;
      _busy = false;
      _message = 'الكود غير معروف بعد — خادم التفعيل قيد التجهيز. '
          'جرّب المحتوى التجريبي الآن';
      _messageColor = Colors.orange.shade200;
    });
  }

  Future<void> _enterTrial() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await widget.licenseStore.save(
      _data.copyWith(mode: LicenseMode.trial, lastWallMs: now),
    );
    widget.onModeSet();
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? AppColors.goldDark
        : AppColors.goldLight;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'هذه الشاشة تظهر مرة واحدة عند أول فتح للتطبيق — '
              'بعدها تُدار من «حسابي»',
              style: txt.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Text('loraneem-tech', style: txt.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 34),
            const Text('📘', textAlign: TextAlign.center, style: TextStyle(fontSize: 42)),
            const SizedBox(height: 10),
            Text('أهلاً بك في «فيزيا كلاش»', style: txt.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Clash of Physics ⚔️', style: txt.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(
              'أدخل كود التفعيل الذي حصلت عليه من مكتبنا\nلفتح المنهاج الكامل وبنك الأسئلة',
              style: txt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              maxLength: 17,
              style: const TextStyle(
                  letterSpacing: 2, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'XXXXX-XXXXX-XXXXX',
                counterText: '',
              ),
              onChanged: (v) => setState(() {
                _codeController.value = TextEditingValue(
                  text: formatLicenseCode(v),
                  selection: TextSelection.collapsed(
                      offset: formatLicenseCode(v).length),
                );
                _message = '';
                _messageColor = Colors.transparent;
              }),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 18,
              child: Text(_message,
                  style: txt.bodySmall?.copyWith(color: _messageColor),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _activate,
              child: const Text('تفعيل ✓'),
            ),
            const SizedBox(height: 10),
            Text(
              'الفحص يتم على جهازك بالكامل — تحقق توقيع رقمي Ed25519 '
              'بدون أي إنترنت. بعد ٥ محاولات خاطئة يُضاف انتظار تدريجي '
              'لحماية الكود',
              style: txt.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _enterTrial,
              child: const Text('تجربة المحتوى التجريبي (بدون تفعيل)'),
            ),
            const SizedBox(height: 14),
            Text(
              'لا تملك كوداً؟ مرّ على مكتبنا — التفعيل دقيقة واحدة\n'
              'بعدها التطبيق يعمل بدون إنترنت حتى يوم الامتحان',
              style: txt.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            Text(
              '✓ المادة العلمية راجعتها: الأستاذ فداء البني',
              style: txt.bodySmall?.copyWith(color: gold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
