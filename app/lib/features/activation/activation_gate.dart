import 'dart:convert' show base64Decode, utf8;

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/license/license_core.dart';
import '../../core/license/license_store.dart';
import '../../core/supabase/activation_api.dart';
import '../../core/theme/app_colors.dart';

/// A1 — شاشة التفعيل (قرار 57):
/// أعلى يمين: تطوير → لورانيم تك → الشعار
/// أعلى يسار: إشراف علمي → الأستاذ فداء مأمون البني
/// تحتهما حقل الكود (٥-٥-٥ Crockford) + زر تفعيل
/// أسفل: حقوق النشر محفوظة
/// بلا وضع تجريبي وبلا دخول بلا تفعيل (قرار 53).
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

  bool _isCrockfordValid(String raw) {
    // Crockford Base32: 0-9 A-H J K M N P R-Z (بدون I L O U)
    // raw already uppercased and stripped of dashes
    const invalid = {'I', 'L', 'O', 'U'};
    for (final c in raw.split('')) {
      if (invalid.contains(c)) return false;
    }
    // يجب أن يكون 0-9 أو A-Z فقط (بعد الفلترة لا يوجد غيرها)
    return RegExp(r'^[0-9A-Z]+$').hasMatch(raw);
  }

  Future<void> _activate() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockRemaining = _data.lockUntilMs - now;
    if (lockRemaining > 0) {
      final minutes = (lockRemaining / 60000).ceil();
      _say('محاولات كثيرة — انتظر $minutes دقيقة ثم أعد المحاولة',
          Colors.red.shade300);
      return;
    }
    final rawUpper = _codeController.text.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    if (rawUpper.isEmpty) {
      _say('أدخل كود التفعيل المكوّن من 15 حرفاً', Colors.red.shade300);
      return;
    }
    if (rawUpper.length < 15) {
      _say('الكود ناقص — ١٥ حرفاً بصيغة XXXXX-XXXXX-XXXXX (من مكتب لورانيم)',
          Colors.red.shade300);
      return;
    }
    if (!_isCrockfordValid(rawUpper)) {
      _say('الكود يحوي حروف غير مسموحة — المسموح 0-9 و A-H,J,K,M,N,P,R-Z (بدون I L O U)',
          Colors.red.shade300);
      return;
    }
    final digits = rawUpper; // 15 حرف Crockford صافية
    // المسار الحقيقي عبر الخادم
    if (widget.activationApi != null && widget.devicePubkeyB64.isNotEmpty) {
      setState(() => _busy = true);
      _say('جارٍ التحقق من الكود على خادم لورانيم...', Colors.blue.shade200);
      try {
        final r = await widget.activationApi!.activate(
            digits, widget.devicePubkeyB64, _deviceFp());
        if (!mounted) return;
        if (r.ok && r.token != null) {
          final check = checkLicense(r.token!,
              nowMs: r.serverTimeMs,
              key: widget.licenseKey,
              devicePubkeyBytes: base64Decode(widget.devicePubkeyB64));
          if (check.ok) {
            await widget.licenseStore.save(_data.copyWith(
              mode: LicenseMode.licensed,
              token: r.token,
              activatedAtMs: r.serverTimeMs,
              lastWallMs: r.serverTimeMs,
              failures: 0,
              lockUntilMs: 0,
            ));
            if (!mounted) return;
            widget.onModeSet();
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
      _message = 'تعذر الاتصال بخادم التفعيل — تأكد من الإنترنت وحاول ثانية';
      _messageColor = Colors.orange.shade200;
    });
  }

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
      _messageColor = counts ? Colors.red.shade300 : Colors.orange.shade200;
    });
  }

  String _deviceFp() =>
      sha256.convert(utf8.encode(widget.devicePubkeyB64)).toString().substring(0, 16);

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? AppColors.goldDark : AppColors.goldLight;
    final line = isDark ? AppColors.darkLine : AppColors.lightLine;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── الشريط العلوي: يمين تطوير / يسار إشراف (قرار 57) ──
            // تصميم متوازن: كل جهة = شارة دائرية + سطر دور + سطر اسم بإيقاع
            // أحجام موحّد؛ الاسم يتقلّص بلا كسر (FittedBox) على الشاشات الضيّقة.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // يمين — تطوير
                  Expanded(
                    child: _CreditBlock(
                      role: 'تطوير',
                      name: 'لورانيم تك',
                      alignEnd: false,
                      isDark: isDark,
                      txt: txt,
                      badge: ClipOval(
                        child: Image.asset(
                          'assets/brand/loraneem_tech.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _FallbackBadge(
                            icon: Icons.memory,
                            isDark: isDark,
                            line: line,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // يسار — إشراف علمي
                  Expanded(
                    child: _CreditBlock(
                      role: 'إشراف علمي',
                      name: 'الأستاذ فداء مأمون البني',
                      alignEnd: true,
                      isDark: isDark,
                      txt: txt,
                      nameColor: gold,
                      badge: CircleAvatar(
                        radius: 20,
                        backgroundColor: gold.withValues(alpha: 0.15),
                        child: Icon(Icons.school_outlined, size: 22, color: gold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── المحتوى الأوسط ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
                children: [
                  Text('فيزيا كلاش',
                      style: txt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Clash of Physics ⚔️',
                      style: txt.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTxt2
                              : AppColors.lightTxt2),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Text('أدخل كود التفعيل',
                      style: txt.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
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
                    height: 20,
                    child: Text(_message,
                        style: txt.bodySmall?.copyWith(color: _messageColor),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _activate,
                    child: const Text('تفعيل ✓'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الكود من مكتب لورانيم — بعد التفعيل يعمل التطبيق بدون إنترنت',
                    style: txt.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTxt2
                            : AppColors.lightTxt2,
                        fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // ── التذييل ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Divider(color: line, height: 1),
                  const SizedBox(height: 10),
                  Text('حقوق النشر محفوظة — لورانيم تك',
                      style: txt.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTxt2
                              : AppColors.lightTxt2,
                          fontSize: 11),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// كتلة إسناد متوازنة: شارة دائرية + دور + اسم (بمحاذاة جهة، بلا كسر سطر).
class _CreditBlock extends StatelessWidget {
  const _CreditBlock({
    required this.role,
    required this.name,
    required this.alignEnd,
    required this.isDark,
    required this.txt,
    required this.badge,
    this.nameColor,
  });

  final String role;
  final String name;
  final bool alignEnd;
  final bool isDark;
  final TextTheme txt;
  final Widget badge;
  final Color? nameColor;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTxt2 : AppColors.lightTxt2;
    final labels = Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(role,
            style: txt.bodySmall?.copyWith(color: muted, fontSize: 11)),
        const SizedBox(height: 2),
        // FittedBox يمنع كسر الاسم إلى سطرين على الشاشات الضيّقة.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(name,
              maxLines: 1,
              style: txt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800, fontSize: 13, color: nameColor)),
        ),
      ],
    );
    final children = alignEnd
        ? [Expanded(child: labels), const SizedBox(width: 8), badge]
        : [badge, const SizedBox(width: 8), Expanded(child: labels)];
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: children,
    );
  }
}

/// بديل الشعار عند غيابه — دائرة موحّدة القياس مع أيقونة.
class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({
    required this.icon,
    required this.isDark,
    required this.line,
  });

  final IconData icon;
  final bool isDark;
  final Color line;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: BoxShape.circle,
          border: Border.all(color: line),
        ),
        child: Icon(icon, size: 20),
      );
}
