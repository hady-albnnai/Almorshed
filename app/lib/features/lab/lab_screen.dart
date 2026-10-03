import 'package:flutter/material.dart';

import '../../core/lab/experiments.dart';
import '../../core/training/batch_builder.dart';
import '../../core/training/training_store.dart';
import '../../core/xp/streak_service.dart';
import 'airtube_screen.dart';
import 'crookes_screen.dart';
import 'ac_screen.dart';
import 'experiment_screen.dart';
import 'fbil_screen.dart';
import 'oscilloscope_screen.dart';
import 'tutia_screen.dart';
import 'faraday1_lab_screen.dart';
import 'generators_screen.dart';
import 'helmholtz_screen.dart';
import 'induct_screen.dart';
import 'blvrails_screen.dart';
import 'fcoil_screen.dart';
import 'melde_screen.dart';
import 'mstat_screen.dart';
import 'simple_screen.dart';
import 'spring_lab_screen.dart';
import 'syringe_screen.dart';
import 'torsion_screen.dart';

/// F3.5 + المادة ١٤ — فهرس المختبر (قرار ٣٧: عرض بديل لنفس تجارب الدروس):
/// النابض التوافقي + التجارب الخمس بقالب توقّع/لاحظ/اشرح ومحاكاة حتمية.
class LabScreen extends StatefulWidget {
  /// F3.8 — اختياري: null = بلا تسجيل (اختبارات قديمة سليمة).
  final XpRecorder? xpRecorder;

  const LabScreen({
    super.key,
    required this.trainingStore,
    this.xpRecorder, // F3.8
  });

  final TrainingStore trainingStore;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  TrainingData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.trainingStore.load();
    if (!mounted) return;
    setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final data = _data;

    return Scaffold(
      appBar: AppBar(title: const Text('المختبر')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 4, left: 4),
                  child: Text(
                    'تجارب تفاعلية بمحاكاة فيزيائية حقيقية — غيّر الوسائط، '
                    'توقّع، شغّل، ولاحظ الحركة بنفسك.',
                    style: txt.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('النابض التوافقي'),
                    subtitle: const Text(
                        'محاكاة RK4 حتماً · منهجية توقع/لاحظ/اشرح · تحدي T=٢ث'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      // data محلية نهائية مفحوصة بالثلاثي — الترقية تسري للإغلاق
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SpringLabScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load(); // تحديث حالة التحدي عند العودة
                    },
                  ),
                ),
                // المادة ١٤ — فاراداي (١) (المعتمد ٢٠٢٦-١٠-٠٢): شاشة خاصة
                // بمشهد سحب حي — نمط النابض (لا القالب العام للخمسة).
                Card(
                  key: const Key('lab-faraday1'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['faraday1'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🧪',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('فاراداي (١): مغناطيس ووشيعة'),
                    subtitle: const Text(
                        'الوحدة ٢ · التحريض الكهرومغناطيسي · تحدّي الانحرافين المتعاكسين'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => Faraday1LabScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load(); // تحديث علامة ✓ عند العودة
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-melde'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['melde'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🌊',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('ملد: الوتر والرنانة'),
                    subtitle: const Text(
                        'الوحدة ٣ · v=√(FT/μ) · أنماط المغازل الثابتة'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => MeldeScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-helmholtz'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['helmholtz'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🌀',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('ملفا هلمهولتز: المسار الدائري'),
                    subtitle: const Text(
                        'الوحدة ٢ · r = 0.45·√(U/I) · الجسيم المشحون'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => HelmholtzScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-airtube'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['airtube'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🚰',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('قرصانة عمود الهواء'),
                    subtitle: const Text(
                        'الوحدة ٣ · Ln=(2n−1)λ/4 · الموجات الصوتية'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => AirtubeScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-fbil'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['fbil'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🧲',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('القوة على سلك يمر به تيار'),
                    subtitle: const Text(
                        'الوحدة ٢ · F=BIL · دولاب بارلو'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => FbilScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-oscilloscope'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['oscilloscope'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '📺',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('الأوسيلوسكوب: قراءة U₀ وT'),
                    subtitle: const Text(
                        'الوحدة ٢ · ثلاث تجارب قراءة الشبكة'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => OscilloscopeScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-crookes'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['crookes'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '☢️',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('أنبوب كروكس: أشعة مهبطية'),
                    subtitle: const Text(
                        'الوحدة ٤ · الشرارة → التألق → الانحراف'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => CrookesScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-tutia'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['tutia'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '⚡',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('صفيحة التوتياء: الفعل الكهرضوئي'),
                    subtitle: const Text(
                        'الوحدة ٤ · UV يفريغ الشحنة · الزجاج يحجب'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => TutiaScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-torsion'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['torsion'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🌀',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('نواس الفتل المخبري'),
                    subtitle: const Text(
                        'الوحدة ١ · T₀=2π√(I/K) · I=½MR²+2mr²'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => TorsionScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-simple'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['simple'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '⏱️',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('النواس البسيط: T ~ √l'),
                    subtitle: const Text(
                        'الوحدة ١ · قياس ١٠ نوسات · نسبة ٢٫٠'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SimpleScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-syringe'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['syringe'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '💉',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('المحقن والإبرة: التدفق'),
                    subtitle: const Text(
                        'الوحدة ١ · Q=A·v · تحدي ٥ml/٣s'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SyringeScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-mstat'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['mstat'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🧭',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('مغناطيسية ساكنة: الإبر والبرادة'),
                    subtitle: const Text(
                        'الوحدة ٢ · مناحي الاستقرار · B ∝ N·I·μr'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => MstatScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-blvrails'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['blvrails'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🛤️',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('السكتان التحريضية: ε = BLv'),
                    subtitle: const Text(
                        'الوحدة ٢ · القراءة أثناء الحركة فقط'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => BlvrailsScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-fcoil'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['fcoil'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '⚡',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('السكتان المتدحرجتان والإطار'),
                    subtitle: const Text(
                        'الوحدة ٢ · F=BIL متعاكسة · τ=NIAB·sinφ'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => FcoilScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-induct'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['induct'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🔁',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('وشيعتان + قانون لينز'),
                    subtitle: const Text(
                        'الوحدة ٢ · ε₂=−M·dI₁/dt · جهة التيار المُحرَّض'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => InductScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-generators'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['generators'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '⚙️',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('المولد والمحرك والذاتي'),
                    subtitle: const Text(
                        'الوحدة ٢ · ميزان الطاقة · ε المعاكسة · شرارة الفتح'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => GeneratorsScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                Card(
                  key: const Key('lab-ac'),
                  child: ListTile(
                    leading: Text(
                      data.labChallengeDays['ac'] ==
                              dateKeyOf(DateTime.now())
                          ? '✓'
                          : '🔌',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: const Text('القيمة الفعّالة + R/L/C'),
                    subtitle: const Text(
                        'الوحدة ٢ · Ueff=U₀/√٢ · C يمنع DC · L تعارض AC'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => AcScreen(
                          trainingStore: widget.trainingStore,
                          initialData: data,
                          xpRecorder: widget.xpRecorder,
                        ),
                      ));
                      _load();
                    },
                  ),
                ),
                for (final exp in labExperiments.values)
                  Card(
                    key: Key('lab-${exp.id}'),
                    child: ListTile(
                      leading: Text(
                        data.labChallengeDays[exp.id] ==
                                dateKeyOf(DateTime.now())
                            ? '✓'
                            : '🧪',
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(exp.title),
                      subtitle: Text(
                          '${_chapterLabel(exp.chapterId)} · ${exp.challenge?.title ?? ''}'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ExperimentScreen(
                            experiment: exp,
                            trainingStore: widget.trainingStore,
                            xpRecorder: widget.xpRecorder,
                          ),
                        ));
                        _load(); // تحديث علامة ✓ عند العودة
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'كل التجارب تعمل محلياً بلا شبكة — خطوة تكامل ١/٢٤٠ ث '
                  'ونفس السحب ⇒ نفس المسار على كل الأجهزة',
                  style: txt.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

/// «الوحدة ١ · الفصل ٢» من معرّف الفصل `U1C2` (للعنوان الفرعي فقط).
String _chapterLabel(String chapterId) {
  final m = RegExp(r'^U(\d+)C(\d+)$').firstMatch(chapterId);
  if (m == null) return chapterId;
  return 'الوحدة ${m.group(1)} · الفصل ${m.group(2)}';
}
