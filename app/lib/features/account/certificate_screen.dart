/// F6.5 — شاشة شهادة الموسم «بطل دوري فيزيا كلاش».
///
/// تطلب الشهادة من cert_issue (توقيع تحدٍّ بمفتاح الجهاز)، تتحقق منها محليًّا
/// بالمفتاح المضمّن (أوف لاين)، ثم تعرضها ببطاقة رسمية + زر نسخ/مشاركة نصية.
/// الحالات الصريحة: الموسم لم يُغلق · لم تشارك · تعذّر الاتصال · توقيع مرفوض.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cert/certificate.dart';
import '../../core/supabase/cert_api.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({
    super.key,
    required this.season,
    this.api,
    this.initial,
  });

  /// اسم الموسم (مثل '2026-2027') — من current_season بالخادم.
  final String season;

  /// مُصدِر الشهادة — يُحقن؛ null ⇒ الشاشة تعرض [initial] فقط (للمعاينة/الاختبار).
  final CertIssuer? api;

  /// شهادة جاهزة للعرض مباشرة (اختبار/معاينة) — تتخطّى الشبكة.
  final Certificate? initial;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

enum _Phase { loading, ready, seasonOpen, notParticipated, offline, badSig, error }

class _CertificateScreenState extends State<CertificateScreen> {
  _Phase _phase = _Phase.loading;
  Certificate? _cert;
  String _errorCode = '';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _cert = widget.initial;
      _phase = _Phase.ready;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final api = widget.api;
    if (api == null) {
      setState(() {
        _phase = _Phase.error;
        _errorCode = 'NO_API';
      });
      return;
    }
    try {
      final cert = await api.issue(widget.season);
      if (!mounted) return;
      setState(() {
        _cert = cert;
        _phase = _Phase.ready;
      });
    } on CertApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCode = e.code;
        _phase = e.seasonOpen
            ? _Phase.seasonOpen
            : e.notParticipated
                ? _Phase.notParticipated
                : e.badSignature
                    ? _Phase.badSig
                    : _Phase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.offline);
    }
  }

  String _shareText(Certificate c) => '${c.tier.label} — $certTitle\n'
      'الموسم ${c.season} · ${c.xp} نقطة\n'
      'فيزيا كلاش — Clash of Physics';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شهادة الموسم')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const CircularProgressIndicator();
      case _Phase.ready:
        return _CertCard(cert: _cert!, shareText: _shareText(_cert!));
      case _Phase.seasonOpen:
        return _Message(
          key: const Key('cert_season_open'),
          icon: Icons.hourglass_top,
          title: 'الموسم لم ينتهِ بعد',
          body: 'تُمنح الشهادة عند نهاية الموسم — تابع جمع النقاط!',
        );
      case _Phase.notParticipated:
        return _Message(
          key: const Key('cert_not_participated'),
          icon: Icons.emoji_events_outlined,
          title: 'لا شهادة بعد',
          body: 'شارِك في الدوري هذا الموسم لتستحق شهادة «$certTitle».',
        );
      case _Phase.badSig:
        return _Message(
          key: const Key('cert_bad_sig'),
          icon: Icons.gpp_bad,
          title: 'تعذّر التحقق من الشهادة',
          body: 'توقيع الشهادة غير صالح — لم تُقبل. حاول لاحقًا.',
        );
      case _Phase.offline:
        return _Message(
          key: const Key('cert_offline'),
          icon: Icons.wifi_off,
          title: 'تعذّر الاتصال',
          body: 'الشهادة تحتاج اتصالًا مرّة لإصدارها. تحقق من الإنترنت.',
          onRetry: _load,
        );
      case _Phase.error:
        return _Message(
          key: const Key('cert_error'),
          icon: Icons.error_outline,
          title: 'حدث خطأ',
          body: 'تعذّر إصدار الشهادة${_errorCode.isEmpty ? '' : ' ($_errorCode)'}.',
          onRetry: widget.api == null ? null : _load,
        );
    }
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.cert, required this.shareText});

  final Certificate cert;
  final String shareText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;
    const gold = Color(0xFFfbbf24);
    final muted = theme.brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            key: const Key('cert_card'),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: gold, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cert.tier.label,
                      style: const TextStyle(fontSize: 40),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(certTitle,
                      style: txt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900, color: gold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('فيزيا كلاش — Clash of Physics',
                      style: txt.bodyMedium?.copyWith(color: muted),
                      textAlign: TextAlign.center),
                  const Divider(height: 32),
                  _row('الموسم', cert.season, txt),
                  const SizedBox(height: 6),
                  _row('سنوات المشاركة', '${cert.years}', txt),
                  const SizedBox(height: 6),
                  _row('مجموع النقاط', '${cert.xp}', txt),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified,
                          key: Key('cert_verified'), color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text('موثّقة — توقيع رقمي',
                          style: txt.bodySmall
                              ?.copyWith(color: Colors.green.shade700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('cert_share'),
            icon: const Icon(Icons.share),
            label: const Text('نسخ / مشاركة'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('نُسخت الشهادة — الصقها لمشاركتها')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, TextTheme txt) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: txt.bodyMedium),
          Text(value,
              style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      );
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title,
            style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(body, style: txt.bodyMedium, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('cert_retry'),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            onPressed: () => onRetry!(),
          ),
        ],
      ],
    );
  }
}
