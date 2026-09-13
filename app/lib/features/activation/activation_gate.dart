import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/license/license_core.dart';
import '../../core/license/license_store.dart';
import '../../core/supabase/activation_api.dart';
import '../../core/theme/app_colors.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'dart:convert' show utf8;

/// F3.6 — بوابة أول فتح (قرار ٣٨/٤٤ — مطابقة النموذج s-activate):
/// «تظهر مرة واحدة عند أول فتح — بعدها تُدار من حسابي».
/// الفحص المحلي Ed25519 ظاهر + انتظار تدريجي بعد ٥ محاولات + مدخل تجريبي.
/// F4.4: بتمرير activationApi يصير التفعيل حقيقياً على الخادم؛ بلا تمرير
/// (الاختبارات) يبقى المسار المحلي «قيد التجهيز» كما كان.
class ActivationGate extends StatefulWidget {
  const ActivationGate({
    super.key,
    required this.licenseStore,
    required this.onModeSet,
    this.activationApi,
    this.devicePubkeyB64 = '',
    this.licenseKey,
  });

  final LicenseStore licenseStore;
  final VoidCallback onModeSet;
  final ActivationApi? activationApi;
  final String devicePubkeyB64;

  /// مفتاح فحص بديل للاختبارات (الإنتاج: المفتاح المضمّن license_core).
  final ed.PublicKey? licenseKey;

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
    // F4.4 — المسار الحقيقي: الخادم يوقّع الإيجار والفحص المحلي يعيد التحقق
    if (widget.activationApi != null && widget.devicePubkeyB64.isNotEmpty) {
      setState(() => _busy = true);
      _say('جارٍ التحقق من الكود على خادم لورانيم...', Colors.blue.shade200);
      try {
        final r = await widget.activationApi!.activate(
            digits, widget.devicePubkeyB64, _deviceFp());
        if (!mounted) return;
        if (r.ok && r.token != null) {
          final check = checkLicense(r.token!,
              nowMs: r.serverTimeMs, key: widget.licenseKey);
          if (check.ok) {
            await widget.licenseStore.save(_data.copyWith(
              mode: LicenseMode.licensed,
              token: r.token,
              activatedAtMs: r.serverTimeMs,
              lastWallMs: r.serverTimeMs, // مرساة زمن السيرفر (L4)
              failures: 0,
              lockUntilMs: 0,
            ));
            if (!mounted) return;
            widget.onModeSet(); // يفكك البوابة — بلا setState بعدها
            return;
          }
          await _recordFailure(false,
              'التوقيع الرقمي لم يجتز الفحص المحلي — أعد المحاولة');
          return;
        }
        await _recordFailure(r.countsAsAttempt, r.errorAr);
        return;
      } catch (_) {
        if (!mounted) return;
        await _recordFailure(
            false, 'تعذر الوصول للخادم — تحقق من اتصال الإنترنت');
        return;
      }
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

  /// تسجيل فشل تفعيل — يُحسب ضد قفل الانتظار حصراً إن كان خطأ كود
  /// (انقطاع الشبكة/عطل الخادم لا يعاقَب — عدالة القفل docs/11 §٩).
  Future<void> _recordFailure(bool counts, String msg) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final failures = counts ? _data.failures + 1 : _data.failures;
    final lockMinutes = counts ? lockoutMinutesFor(failures) : 0;
    final updated = _data.copyWith(
      failures: failures,
      lockUntilMs: counts ? now + lockMinutes * 60000 : 0,
      lastWallMs: now,
    );
    await widget.licenseStore.save(updated);
    if (!mounted) return;
    setState(() {
      _data = updated;
      _busy = false;
      _message = msg;
      _messageColor =
          counts ? Colors.red.shade300 : Colors.orange.shade200;
    });
  }

  /// بصمة الجهاز المرسلة — مشتقة من المفتاح العام (ثابتة بلا حزم خارجية؛
  /// الانحراف عن AndroidId موثّق بالعقد §٩ — حزم device_info محجوبة).
  String _deviceFp() =>
      sha256.convert(utf8.encode(widget.devicePubkeyB64)).toString()
          .substring(0, 16);

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
              // تحصين الإدخال (دفاع أول): حروف Crockford والشرطة حصراً —
              // أي محرف آخر يُرفض قبل أن يلمس الحالة إطلاقاً. والمنسق
              // الحي (formatLicenseCode) دفاع ثانٍ والخادم دفاع ثالث.
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                LengthLimitingTextInputFormatter(17),
              ],
              maxLength: 17,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
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
