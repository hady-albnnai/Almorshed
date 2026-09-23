/// F6.4 — شاشة «عن التطبيق» النهائية (قرار ٣٩ · بند ١٣ المُستثنى بقرار المالك
/// 2026-09-22). الشريط العلوي: تطوير ← لورانيم تك ← الشعار (أو العلامة النصية
/// عند غيابه — docs/13 §٦).
///
/// فرع dev/self-content (2026-09-23): أُزيل سطر «الإشراف العلمي» نهائياً —
/// التطوير يجري بدون إشراف الأستاذ، والمادة العلمية مبنيّة من المنهاج الوزاري
/// والدورات وسلالم التصحيح. راجع BRANCHING.md.
library;

import 'package:flutter/material.dart';

/// الإصدار المعلن — مطابق `pubspec.yaml` (`version: 0.1.0+1`). يُربط
/// تلقائياً بـpackage_info عند F8.1 حين تُعتمد حزمة التوزيع.
const String aboutVersion = '0.1.0+1';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    const gold = Color(0xFFfbbf24);
    final muted = isDark ? Colors.white70 : Colors.black54;
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── الشريط العلوي: تطوير ← لورانيم تك (أُزيل عمود الإشراف العلمي
            //    على فرع dev/self-content — راجع BRANCHING.md) ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تطوير',
                    style: txt.bodySmall?.copyWith(color: muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text('لورانيم تك',
                    style: txt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/brand/loraneem_tech.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Text('loraneem-tech',
                          style: txt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w900, fontSize: 9)),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // ── البطاقة المركزية ──
            Text('فيزيا كلاش',
                style: txt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900, letterSpacing: 0.5),
                textAlign: TextAlign.center),
            Text('Clash of Physics',
                style: txt.titleMedium?.copyWith(color: muted),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('منهاج الثالث الثانوي العلمي',
                style: txt.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('الإصدار $aboutVersion',
                style: txt.bodySmall?.copyWith(color: muted),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '✓ المادة وفق المنهاج الوزاري والدورات وسلالم التصحيح',
              style: txt.bodySmall?.copyWith(color: gold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'حقوق النشر محفوظة\nيعمل بدون إنترنت بعد التفعيل',
              style: txt.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Text('فيزيا كلاش © 2026 — loraneem-tech',
                style: txt.bodySmall?.copyWith(color: muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
