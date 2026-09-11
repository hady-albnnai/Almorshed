import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/util/arabic_number.dart';
import 'unit_screen.dart';

/// شاشة المنهاج — الوحدات الخمس (F3.2 · مطابقة النموذج المرجعي).
/// التقدم الحقيقي يُوصَل في F3.1 (Drift) — الآن ٠٪ بصدق.
class CurriculumScreen extends StatelessWidget {
  const CurriculumScreen({
    super.key,
    required this.pack,
    required this.onToggleTheme,
  });

  final ContentPack pack;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فيزيا كلاش', style: txt.titleLarge),
            Text('Clash of Physics · منهاج الثالث الثانوي العلمي',
                style: txt.bodyMedium),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تبديل الوضع الفاتح/الداكن',
            onPressed: onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('الوحدات الخمس', style: txt.titleLarge),
          const SizedBox(height: 6),
          for (var i = 0; i < pack.units.length; i++)
            _UnitCard(index: i, unit: pack.units[i]),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.index, required this.unit});

  final int index;
  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final hasChapters = unit.chapters.isNotEmpty;
    final note = hasChapters
        ? '${ArabicNumber.from(unit.chapters.length)} فصل — '
            'ص${ArabicNumber.from(unit.chapters.first.page)} '
            'إلى ص${ArabicNumber.from(unit.chapters.last.page)}'
        : 'قيد الإعداد — تصل مع تحديث المحتوى';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasChapters
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => UnitScreen(unit: unit)),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ArabicNumber.from(index + 1)} · ${unit.title}',
                      style: txt.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('٠٪',
                      style: txt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  value: 0,
                  minHeight: 7,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              Text(note, style: txt.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
