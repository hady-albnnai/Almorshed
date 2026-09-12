import 'package:flutter/material.dart';

import '../../core/content/models.dart';
import '../../core/progress/progress_store.dart';
import '../../core/license/license_store.dart';
import '../../core/training/training_store.dart';
import '../../core/util/arabic_number.dart';
import '../account/account_screen.dart';
import '../lab/lab_screen.dart';
import '../../core/xp/streak_service.dart';
import '../training/training_screen.dart';
import 'unit_screen.dart';

/// شاشة المنهاج — الوحدات الخمس (F3.2 · مطابقة النموذج المرجعي).
/// F3.1: النسبة الحقيقية من مخزن التقدم، وتُحدَّث عند العودة من الدروس.
class CurriculumScreen extends StatefulWidget {
  /// F3.8 — اختياري: null = بلا تسجيل (اختبارات قديمة سليمة).
  final XpRecorder? xpRecorder;

  const CurriculumScreen({
    super.key,
    required this.pack,
    required this.onToggleTheme,
    required this.progressStore,
    required this.trainingStore,
      required this.licenseStore,
      this.xpRecorder, // F3.8
  });

  final ContentPack pack;
  final VoidCallback onToggleTheme;
  final ProgressStore progressStore;
  final TrainingStore trainingStore;

  final LicenseStore licenseStore;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  ReadProgress _progress = const ReadProgress();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await widget.progressStore.load();
    if (!mounted) return;
    setState(() => _progress = p);
  }

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
            tooltip: 'حسابي — التفعيل والاشتراك',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AccountScreen(licenseStore: widget.licenseStore),
              ));
              _reload(); // تحديث حالة التفعيل عند العودة
            },
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'المختبر — التجارب التفاعلية',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => LabScreen(
                      trainingStore: widget.trainingStore,
                      xpRecorder: widget.xpRecorder,
                    ),
              ));
              _reload(); // نمط F3.1: تحديث عند العودة
            },
            icon: const Icon(Icons.science_outlined),
          ),
          IconButton(
            tooltip: 'التدريب — دفعة اليوم وأخطائي',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TrainingScreen(
                  pack: widget.pack,
                  trainingStore: widget.trainingStore,
              xpRecorder: widget.xpRecorder,
                ),
              ));
              _reload(); // نمط F3.1: تحديث عند العودة
            },
            icon: const Icon(Icons.quiz_outlined),
          ),
          IconButton(
            tooltip: 'تبديل الوضع الفاتح/الداكن',
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('الوحدات الخمس', style: txt.titleLarge),
          const SizedBox(height: 6),
          for (var i = 0; i < widget.pack.units.length; i++)
            _UnitCard(
              index: i,
              unit: widget.pack.units[i],
              completedIds: _progress.completedIds,
              progressStore: widget.progressStore,
              onReturned: _reload, // تحديث النسبة بعد العودة من الدروس
            ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.index,
    required this.unit,
    required this.completedIds,
    required this.progressStore,
    required this.onReturned,
  });

  final int index;
  final Unit unit;
  final Set<String> completedIds;
  final ProgressStore progressStore;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final hasChapters = unit.chapters.isNotEmpty;
    final percent = unitPercent(unit, completedIds);
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
            ? () => Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                      builder: (_) => UnitScreen(
                            unit: unit,
                            progressStore: progressStore,
              xpRecorder: widget.xpRecorder,
                          )),
                )
                .then((_) => onReturned())
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
                  Text('${ArabicNumber.from(percent)}٪',
                      style: txt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 7,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
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
