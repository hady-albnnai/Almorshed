/// المادة ١٤ — نوى التجارب الخمس (قرار ٥٨: داخل الدرس بموضعها · قرار ٤٣:
/// منهجية توقّع/لاحظ/اشرح · docs/12 §٦: RK4 بخطوة ثابتة 1/240 ث، حتمية بتّاً).
///
/// كل تجربة = نموذج خالص بلا Flutter: معاملات (منزلقات) + حالة (x أو θ أو q)
/// + خطوة RK4 + دور نظري + سؤال توقّع + نص شرح + تحدٍّ. الشاشة الواحدة
/// `ExperimentScreen` ترسم أيَّ تجربة من هذا الوصف.
///
/// الرموز كما في الكتاب: النابض `k`، الفتل `C` (ثابت الفتل — قرار الأستاذ
/// المعلّق: K مقابل C، نعرض «C» ونذكر أن الكتاب يكتب `k` أيضاً)، الثقلي
/// `T0 = 2π√(IΔ/mgd)` وللبسيط `2π√(l/g)`، طومسون `T0 = 2π√(LC)`، الوتر
/// `v = √(FT/μ)` و `fn = (n/2L)·√(FT/μ)`، الكهرضوئي `Ek = hf − Ws`.
library;

import 'dart:math' as math;

import 'spring_sim.dart' show simDt;

/// معامل قابل للضبط بمنزلق — نطاق صريح وخطوة ثابتة (قيم «نظيفة»).
class LabParam {
  const LabParam({
    required this.id,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.initial,
    this.decimals = 1,
  });

  final String id;
  final String label; // «الكتلة m»
  final String unit; // «kg»
  final double min;
  final double max;
  final double step;
  final double initial;
  final int decimals;

  double clampSnap(double v) {
    final snapped = min + ((v - min) / step).round() * step;
    final c = snapped.clamp(min, max).toDouble();
    return double.parse(c.toStringAsFixed(decimals));
  }
}

/// حالة مهتزّ ذي درجة حرية واحدة: الإحداثي q (x أو θ أو الشحنة) ومشتقّه.
class OscState {
  const OscState(this.q, this.dq);
  final double q;
  final double dq;
}

/// خطوة RK4 عامة للمعادلة q″ = f(q) — نفس بنية `rk4Step` في النابض.
OscState rk4Osc(OscState s, double Function(double q) acc) {
  final k1q = s.dq;
  final k1v = acc(s.q);
  final k2q = s.dq + simDt / 2.0 * k1v;
  final k2v = acc(s.q + simDt / 2.0 * k1q);
  final k3q = s.dq + simDt / 2.0 * k2v;
  final k3v = acc(s.q + simDt / 2.0 * k2q);
  final k4q = s.dq + simDt * k3v;
  final k4v = acc(s.q + simDt * k3q);
  return OscState(
    s.q + simDt / 6.0 * (k1q + 2.0 * k2q + 2.0 * k3q + k4q),
    s.dq + simDt / 6.0 * (k1v + 2.0 * k2v + 2.0 * k3v + k4v),
  );
}

/// سؤال التوقّع (Predict) قبل التجريب — ثلاثة خيارات ومؤشّر الصحيح.
class LabPrediction {
  const LabPrediction({
    required this.question,
    required this.options,
    required this.correct,
    required this.afterText,
  });
  final String question;
  final List<String> options;
  final int correct;

  /// يظهر في «اشرح» بعد أول قياس — يربط الملاحظة بالقانون.
  final String afterText;
}

/// التحدّي: هدف عددي على المقدار النظري ± سماحية (كتحدّي النابض T=٢ث).
class LabChallenge {
  const LabChallenge({
    required this.title,
    required this.target,
    required this.tolerance,
    required this.hint,
  });
  final String title;
  final double target;
  final double tolerance;
  final String hint;

  bool ok(double value) => (value - target).abs() <= tolerance;
}

/// وصف التجربة الكامل — كل ما تحتاجه الشاشة العامة.
abstract class LabExperiment {
  const LabExperiment();

  String get id;
  String get title;
  String get chapterId;

  /// المعاملات بترتيب العرض.
  List<LabParam> get params;

  /// ما يقيسه عدّاد الدور: «T0 المقيس» أو «f المقيس» …
  String get measuredLabel => 'T0 المقيس من المحاكاة';

  /// تسمية الإحداثي المرسوم (للرسم فقط).
  String get coordinateLabel;

  /// أقصى انحراف ابتدائي يمكن للمستخدم سحبه (بوحدة q).
  double get maxInitial;

  LabPrediction get prediction;
  LabChallenge? get challenge;

  /// الدور النظري بالمعاملات الحالية — **بوحدة زمن المحاكاة** (ما يقيسه
  /// العدّاد): ثوانٍ للنواسات، وحدات مبطّأة للدارة والوتر (انظر `simUnitMs`).
  double period(Map<String, double> p);

  /// كم ميلي ثانية حقيقية تساوي وحدة زمن المحاكاة الواحدة (١٠٠٠ = ثانية).
  /// الدارة L–C: ١ ms لكل وحدة (تبطيء ×١٠٠٠) · الوتر: ١٠ ms (×١٠٠).
  double get simUnitMs => 1000.0;

  /// وحدة عرض الدور: «ث» أو «ms».
  String get periodUnit => 'ث';

  /// تحويل زمن المحاكاة إلى وحدة العرض.
  double toDisplay(double simUnits) =>
      periodUnit == 'ث' ? simUnits : simUnits * simUnitMs;

  /// المقدار الذي يُفحص به التحدّي (بوحدة العرض) — الدور النظري افتراضاً.
  double challengeValue(Map<String, double> p) => toDisplay(period(p));

  /// هل للتجربة تكامل زمني (رسم حي + عدّاد دور)؟ الكهرضوئي: لا.
  bool get hasDynamics => true;

  /// التسارع المعمّم q″ = f(q) — يحدد المسار حتماً.
  double acceleration(double q, Map<String, double> p);

  /// خطوة واحدة (RK4) — تعتمد `acceleration`.
  OscState step(OscState s, Map<String, double> p) =>
      rk4Osc(s, (q) => acceleration(q, p));

  /// سطر القانون كما يُكتب في الامتحان.
  String get law;

  /// نص «اشرح» — لماذا القياس قريب من النظري وما الذي يحكم الدور.
  String explain(Map<String, double> p, double measured, double theory);

  Map<String, double> get initialParams => {
        for (final x in params) x.id: x.initial,
      };
}

// ─────────────────────────────── ١) نواس الفتل ───────────────────────────────

/// نواس الفتل: Γ = −C·θ ⇒ θ″ = −(C/IΔ)·θ ⇒ T0 = 2π√(IΔ/C).
/// نمذجة IΔ لساق متجانسة: IΔ = (1/12)·m·L² — الطالب يتحكم بـ m وL وC.
class TorsionExperiment extends LabExperiment {
  const TorsionExperiment();

  @override
  String get id => 'torsion';
  @override
  String get title => 'نواس الفتل — الدور والثابت C';
  @override
  String get chapterId => 'U1C2';
  @override
  String get coordinateLabel => 'θ (rad)';
  @override
  double get maxInitial => 0.8;

  @override
  List<LabParam> get params => const [
        LabParam(
            id: 'm', label: 'كتلة الساق m', unit: 'kg',
            min: 0.1, max: 2.0, step: 0.1, initial: 0.6),
        LabParam(
            id: 'L', label: 'طول الساق L', unit: 'm',
            min: 0.2, max: 1.0, step: 0.05, initial: 0.5, decimals: 2),
        LabParam(
            id: 'C', label: 'ثابت الفتل C', unit: 'N·m·rad⁻¹',
            min: 0.01, max: 0.5, step: 0.01, initial: 0.05, decimals: 2),
      ];

  /// الافتراضي: IΔ = 0.6·0.5²/12 = 0.0125 ⇒ T0 = 2π√(0.25) ≈ 3.14 s (خارج
  /// نافذة التحدي)؛ الهدف ٢ s يتحقق مثلاً بـ C = 0.12 ⇒ T0 ≈ 2.03 s.
  static double inertia(Map<String, double> p) =>
      p['m']! * p['L']! * p['L']! / 12.0;

  @override
  double period(Map<String, double> p) =>
      2.0 * math.pi * math.sqrt(inertia(p) / p['C']!);

  @override
  double acceleration(double q, Map<String, double> p) =>
      -(p['C']! / inertia(p)) * q;

  @override
  String get law => 'T0 = 2π·√(IΔ / C)   ،   IΔ(ساق) = (1/12)·m·L²';

  @override
  LabPrediction get prediction => const LabPrediction(
        question:
            'لو ضاعفنا طول الساق L (مع ثبات كتلتها وثابت الفتل C)، ماذا يحدث لدور نواس الفتل T0؟',
        options: ['يقصر T0', 'لا يتغير T0', 'يطول T0 (يتضاعف)'],
        correct: 2,
        afterText:
            'IΔ = (1/12)·m·L² يصير ٤ أمثال عند مضاعفة L، والدور يتناسب مع √IΔ ⇒ يتضاعف. السعة الزاوية لا تؤثر — اهتزاز جيبي دوراني.',
      );

  @override
  LabChallenge? get challenge => const LabChallenge(
        title: '🎯 اجعل T0 = ٢ ث (± ٠٫٠٥)',
        target: 2.0,
        tolerance: 0.05,
        hint: 'اضبط m وL وC حتى يدخل T0 النافذة — تذكّر T0 ∝ L·√(m/C)',
      );

  @override
  String explain(Map<String, double> p, double measured, double theory) =>
      'قياسك ${measured.toStringAsFixed(3)} ث قريب من النظري ${theory.toStringAsFixed(3)} ث لأن '
      'الدور يحكمه T0 = 2π√(IΔ/C): زيادة عزم العطالة (بالكتلة أو بالطول) تطيل الدور، '
      'وزيادة ثابت الفتل C (سلك أقصر أو أغلظ: C ∝ d⁴/l) تقصّره. السعة الزاوية θmax لا تدخل.';
}

// ─────────────────────────────── ٢) النواس الثقلي ───────────────────────────────

/// النواس الثقلي البسيط بالمعادلة الحقيقية θ″ = −(g/l)·sin θ (غير توافقي)؛
/// الدور النظري بالسعات الصغيرة T0 = 2π√(l/g) — والمحاكاة تُظهر أن الدور
/// المقيس يطول مع السعة الكبيرة (جوهر «في السعات الصغيرة فقط»).
class GravityPendulumExperiment extends LabExperiment {
  const GravityPendulumExperiment();

  @override
  String get id => 'gravity';
  @override
  String get title => 'النواس الثقلي البسيط — السعات الصغيرة';
  @override
  String get chapterId => 'U1C3';
  @override
  String get coordinateLabel => 'θ (rad)';
  @override
  double get maxInitial => 1.4; // ≈ ٨٠° — لإظهار خروج التوافقية

  @override
  List<LabParam> get params => const [
        LabParam(
            id: 'l', label: 'طول الخيط l', unit: 'm',
            min: 0.2, max: 2.5, step: 0.05, initial: 0.6, decimals: 2),
        LabParam(
            id: 'g', label: 'تسارع الجاذبية g', unit: 'm·s⁻²',
            min: 1.6, max: 25.0, step: 0.1, initial: 10.0),
        LabParam(
            id: 'm', label: 'كتلة الكرة m', unit: 'kg',
            min: 0.05, max: 2.0, step: 0.05, initial: 0.2, decimals: 2),
      ];

  @override
  double period(Map<String, double> p) =>
      2.0 * math.pi * math.sqrt(p['l']! / p['g']!);

  @override
  double acceleration(double q, Map<String, double> p) =>
      -(p['g']! / p['l']!) * math.sin(q);

  @override
  String get law =>
      'T0 = 2π·√(l / g)   (في السعات الصغيرة فقط — sin θ ≈ θ)   ،   المركّب: T0 = 2π·√(IΔ / (m·g·d))';

  @override
  LabPrediction get prediction => const LabPrediction(
        question:
            'لو ضاعفنا كتلة كرة النواس البسيط (مع ثبات الطول l)، ماذا يحدث للدور T0؟',
        options: ['يقصر T0', 'لا يتغير T0', 'يطول T0'],
        correct: 1,
        afterText:
            'الكتلة لا تدخل في T0 = 2π√(l/g): الثقل المُرجِع وعطالة الكرة كلاهما ∝ m فتُختصر. جرّب المنزلق m — الدور ثابت. ثم اسحب الكرة إلى زاوية كبيرة: الدور المقيس يطول — لذلك «جيبية في السعات الصغيرة فقط».',
      );

  @override
  LabChallenge? get challenge => const LabChallenge(
        title: '🎯 نواس الثواني: اجعل T0 = ٢ ث (± ٠٫٠٥)',
        target: 2.0,
        tolerance: 0.05,
        hint: 'بـ g = 10: l = g·T0²/(4π²) ≈ 1 m — جرّب بالمنزلق',
      );

  @override
  String explain(Map<String, double> p, double measured, double theory) {
    final dev = theory == 0 ? 0.0 : (measured - theory) / theory * 100;
    final big = dev > 1.5;
    return 'النظري ${theory.toStringAsFixed(3)} ث (سعات صغيرة) والمقيس ${measured.toStringAsFixed(3)} ث '
        '(فرق ${dev.toStringAsFixed(1)}٪). '
        '${big ? 'الفرق واضح لأن السعة كبيرة: المعادلة الحقيقية θ″ = −(g/l)·sin θ وsin θ < θ فيطول الدور — الحركة غير توافقية. ' : 'الفرق ضئيل لأن السعة صغيرة فـ sin θ ≈ θ والحركة جيبية دورانية تقريباً. '}'
        'الكتلة لا تؤثر، وg الأصغر (كالقمر 1.6) تطيل الدور — الميقاتية تؤخّر بالارتفاع.';
  }
}

// ─────────────────────────────── ٣) الدارة المهتزّة L–C ───────────────────────────────

/// دارة L–C مثالية: L·q″ + q/C = 0 ⇒ q″ = −q/(LC) ⇒ T0 = 2π√(LC) (طومسون).
/// الوحدات المريحة للمنزلقات: L بالـmH وC بالـμF ⇒ T0 بالـms
/// (√(mH·μF) = √(10⁻⁹) s = 10⁻⁴·√10 s). نُجري المحاكاة بزمن مقيس τ = t/1 ms
/// حتى تبقى خطوة RK4 (1/240 ث) مناسبة: q″(τ) = −q/(L[mH]·C[μF]·10⁻³).
class LcCircuitExperiment extends LabExperiment {
  const LcCircuitExperiment();

  @override
  String get id => 'lc';
  @override
  String get title => 'الدارة المهتزّة L–C — علاقة طومسون';
  @override
  String get chapterId => 'U2C4';
  @override
  String get coordinateLabel => 'q / Qmax';
  @override
  double get maxInitial => 1.0;
  @override
  String get measuredLabel => 'T0 المقيس من المحاكاة';
  @override
  double get simUnitMs => 1.0; // وحدة المحاكاة = ١ ms ⇒ العرض مبطّأ ×١٠٠٠
  @override
  String get periodUnit => 'ms';

  /// الافتراضي L = 10 mH، C = 20 μF ⇒ T0 = 2π√(0.2) ≈ 2.81 ms (خارج النافذة)؛
  /// الهدف ٢ ms عند L·C ≈ 101 (مثلاً 10 mH × 10 μF ⇒ 1.987 ms).
  @override
  List<LabParam> get params => const [
        LabParam(
            id: 'L', label: 'ذاتية الوشيعة L', unit: 'mH',
            min: 1.0, max: 100.0, step: 1.0, initial: 10.0, decimals: 0),
        LabParam(
            id: 'C', label: 'سعة المكثفة C', unit: 'μF',
            min: 1.0, max: 100.0, step: 1.0, initial: 20.0, decimals: 0),
      ];

  /// T0 بالميلي ثانية: 2π√(L[mH]·C[μF]·10⁻³) ms
  @override
  double period(Map<String, double> p) =>
      2.0 * math.pi * math.sqrt(p['L']! * p['C']! * 1e-3);

  /// الزمن المحاكى بوحدة ms ⇒ ω² = 1/(L·C·10⁻³) بوحدة ms⁻²
  @override
  double acceleration(double q, Map<String, double> p) =>
      -q / (p['L']! * p['C']! * 1e-3);

  @override
  String get law =>
      'L·q″ + q/C = 0  ⇒  q = Qmax·cos(ω0·t + φ)  ،  T0 = 2π·√(L·C)  ،  E = ½·Qmax²/C = ½·L·Imax² ثابتة';

  @override
  LabPrediction get prediction => const LabPrediction(
        question:
            'لو جعلنا سعة المكثفة C أربعة أمثال (مع ثبات L)، ماذا يحدث لدور التفريغ المهتز T0؟',
        options: ['يصير الربع', 'يتضاعف', 'يصير ٤ أمثال'],
        correct: 1,
        afterText:
            'T0 = 2π√(LC) يتناسب مع √C: أربعة أمثال C ⇒ مِثلا الدور (يتضاعف). الطاقة تتبادل بين المكثفة (½q²/C) والوشيعة (½Li²) ومجموعها ثابت في الدارة المثالية.',
      );

  @override
  LabChallenge? get challenge => const LabChallenge(
        title: '🎯 اجعل T0 = ٢ ms (± ٠٫٠٥)',
        target: 2.0,
        tolerance: 0.05,
        hint: 'L·C = (T0/2π)² ⇒ بالـmH·μF: L·C ≈ 101 — مثلاً L = 10 mH وC = 10 μF',
      );

  @override
  String explain(Map<String, double> p, double measured, double theory) =>
      'المقيس ${measured.toStringAsFixed(3)} ms والنظري ${theory.toStringAsFixed(3)} ms — '
      'علاقة طومسون T0 = 2π√(LC): نفس بنية النابض (L ↔ m، 1/C ↔ k). '
      'لا مقاومة هنا ⇒ السعة ثابتة (غير متخامد)؛ بمقاومة صغيرة تتناقص السعة وبكبيرة يصير التفريغ لا دورياً.';
}

// ─────────────────────────────── ٤) الوتر المشدود (ملد) ───────────────────────────────

/// موجة مستقرة على وتر (تجربة ملد): الوتر بطول L مشدود بقوة FT وكتلته
/// الخطية μ، يُهتزّ بتواتر f. المدروجات fn = (n/2L)·√(FT/μ). المحاكاة هنا
/// ليست تكاملاً زمنياً بل رسم مباشر y(x,t) = 2a·sin(2πx/λ)·cos(2πft) — والقياس
/// هو عدد المغازل n المكتمل عند الطنين (|f/f1 − round(f/f1)| صغير).
class StringWaveExperiment extends LabExperiment {
  const StringWaveExperiment();

  @override
  String get id => 'string';
  @override
  String get title => 'الوتر المشدود — تجربة ملد والمغازل';
  @override
  String get chapterId => 'U3C1';
  @override
  String get coordinateLabel => 'y (سعة نسبية)';
  @override
  double get maxInitial => 1.0;
  @override
  String get measuredLabel => 'دور الهزّاز المقيس T = 1/f';
  @override
  double get simUnitMs => 10.0; // وحدة المحاكاة = ١٠ ms ⇒ مبطّأ ×١٠٠
  @override
  String get periodUnit => 'ms';

  @override
  List<LabParam> get params => const [
        LabParam(
            id: 'f', label: 'تواتر الهزّاز f', unit: 'Hz',
            min: 10.0, max: 200.0, step: 1.0, initial: 50.0, decimals: 0),
        LabParam(
            id: 'FT', label: 'قوة الشد FT', unit: 'N',
            min: 1.0, max: 100.0, step: 1.0, initial: 16.0, decimals: 0),
        LabParam(
            id: 'L', label: 'طول الوتر L', unit: 'm',
            min: 0.5, max: 2.0, step: 0.1, initial: 1.0),
        LabParam(
            id: 'mu', label: 'الكتلة الخطية μ', unit: 'g·m⁻¹',
            min: 0.5, max: 10.0, step: 0.5, initial: 4.0),
      ];

  /// سرعة الانتشار v = √(FT/μ) — μ بالـkg·m⁻¹.
  static double speed(Map<String, double> p) =>
      math.sqrt(p['FT']! / (p['mu']! * 1e-3));

  /// التواتر الأساسي f1 = v/(2L).
  static double fundamental(Map<String, double> p) =>
      speed(p) / (2.0 * p['L']!);

  /// عدد المغازل عند الطنين (null إن لم يكن f قريباً من مدروج).
  static int? spindles(Map<String, double> p, {double tol = 0.04}) {
    final r = p['f']! / fundamental(p);
    final n = r.round();
    if (n < 1 || (r - n).abs() > tol * n.clamp(1, 4)) return null;
    return n;
  }

  /// طول الموجة λ = v/f.
  static double wavelength(Map<String, double> p) => speed(p) / p['f']!;

  /// دور الهزّاز بوحدة المحاكاة (١٠ ms): T = 1/f s = (100/f) وحدة.
  @override
  double period(Map<String, double> p) => 100.0 / p['f']!;

  /// حركة نقطة البطن: y″ = −ω²·y بزمن المحاكاة (ω = 2πf·0.01 rad/وحدة).
  @override
  double acceleration(double q, Map<String, double> p) {
    final w = 2.0 * math.pi * p['f']! * 1e-2;
    return -w * w * q;
  }

  /// التحدّي على عدد المغازل (−1 = لا طنين).
  @override
  double challengeValue(Map<String, double> p) =>
      (spindles(p) ?? -1).toDouble();

  @override
  String get law =>
      'v = √(FT / μ)   ،   fn = (n / 2L)·√(FT / μ)   ،   L = n·λ/2   ،   المسافة بين عقدتين متتاليتين λ/2';

  @override
  LabPrediction get prediction => const LabPrediction(
        question:
            'وتر يهتز بمغزلين عند تواتر معيّن. لو ضاعفنا قوة الشد FT أربعة أمثال (مع ثبات f وL وμ)، كم مغزلاً نرى؟',
        options: ['مغزل واحد', 'مغزلان (لا يتغير)', 'أربعة مغازل'],
        correct: 0,
        afterText:
            'v = √(FT/μ) تتضاعف ⇒ λ = v/f تتضاعف ⇒ عدد أنصاف الموجات على الطول نفسه ينصف: من مغزلين إلى مغزل واحد. الطاقة لا تنتقل على طول الوتر في الموجة المستقرة.',
      );

  @override
  LabChallenge? get challenge => const LabChallenge(
        title: '🎯 اصنع ٣ مغازل بالضبط (n = ٣)',
        target: 3.0,
        tolerance: 0.0,
        hint: 'f3 = 3·f1 = (3/2L)·√(FT/μ) — اضبط f أو FT حتى يُعلن الطنين n = ٣',
      );

  @override
  String explain(Map<String, double> p, double measured, double theory) {
    final n = spindles(p);
    final v = speed(p);
    final f1 = fundamental(p);
    return 'سرعة الانتشار v = √(FT/μ) = ${v.toStringAsFixed(1)} m·s⁻¹ والتواتر الأساسي f1 = v/2L = ${f1.toStringAsFixed(1)} Hz. '
        '${n == null ? 'التواتر الحالي ليس مدروجاً — لا موجة مستقرة واضحة (اضبط f على مضاعف f1).' : 'التواتر الحالي ≈ $n·f1 ⇒ $n مغازل: ${n + 1} عقدة و$n بطوناً، والمسافة بين عقدتين λ/2 = ${(wavelength(p) / 2).toStringAsFixed(3)} m.'} '
        'زيادة الشد تزيد v فتقلّ n عند f ثابت؛ زيادة f تزيد n.';
  }
}

// ─────────────────────────────── ٥) الفعل الكهرضوئي ───────────────────────────────

/// الفعل الكهرضوئي: Ek = hf − Ws؛ العتبة f0 = Ws/h وλ0 = hc/Ws؛
/// كمون الإيقاف U0 = Ek/e. لا تكامل زمني — «المحاكاة» حسابية مباشرة،
/// و«الدور» غير معرَّف (period ترجع 0 والشاشة تخفي عدّاده).
class PhotoelectricExperiment extends LabExperiment {
  const PhotoelectricExperiment();

  static const double h = 6.63e-34; // J·s
  static const double c = 3.0e8; // m·s⁻¹
  static const double e = 1.6e-19; // C

  @override
  String get id => 'photo';
  @override
  String get title => 'الفعل الكهرضوئي — العتبة ومعادلة أينشتاين';
  @override
  String get chapterId => 'U4C3';
  @override
  String get coordinateLabel => '';
  @override
  double get maxInitial => 0.0;
  @override
  String get measuredLabel => '';

  @override
  List<LabParam> get params => const [
        LabParam(
            id: 'lambda', label: 'طول موجة الضوء λ', unit: 'nm',
            min: 200.0, max: 700.0, step: 10.0, initial: 450.0, decimals: 0),
        LabParam(
            id: 'Ws', label: 'عمل الانتزاع Ws', unit: 'eV',
            min: 1.0, max: 5.0, step: 0.1, initial: 2.2),
        LabParam(
            id: 'P', label: 'استطاعة الحزمة P', unit: 'mW',
            min: 0.5, max: 10.0, step: 0.5, initial: 3.0),
      ];

  /// طاقة الفوتون بالـeV.
  static double photonEv(Map<String, double> p) =>
      h * c / (p['lambda']! * 1e-9) / e;

  /// الطاقة الحركية العظمى للإلكترون بالـeV (0 إن لم يحدث انتزاع).
  static double ekEv(Map<String, double> p) {
    final ek = photonEv(p) - p['Ws']!;
    return ek > 0 ? ek : 0.0;
  }

  static bool emits(Map<String, double> p) => photonEv(p) > p['Ws']!;

  /// طول موجة العتبة بالـnm.
  static double thresholdNm(Map<String, double> p) =>
      h * c / (p['Ws']! * e) * 1e9;

  /// عدد الفوتونات في الثانية N = P/E.
  static double photonsPerSecond(Map<String, double> p) =>
      p['P']! * 1e-3 / (photonEv(p) * e);

  @override
  bool get hasDynamics => false;

  @override
  double period(Map<String, double> p) => 0.0;

  @override
  double acceleration(double q, Map<String, double> p) => 0.0;

  /// التحدّي على Ek بالـeV.
  @override
  double challengeValue(Map<String, double> p) => ekEv(p);

  @override
  String get law =>
      'h·f = Ws + Ek   ⇒   Ek = h·f − Ws   ،   f0 = Ws/h  ،  λ0 = h·c/Ws   ،   U0 = Ek/e';

  @override
  LabPrediction get prediction => const LabPrediction(
        question:
            'ضوء لا ينتزع إلكترونات من معدن. لو ضاعفنا استطاعة الحزمة (شدّتها) عشر مرات بطول الموجة نفسه، هل يحدث انتزاع؟',
        options: ['نعم — الطاقة صارت كافية', 'لا — الشدة لا تغيّر طاقة الفوتون', 'نعم بعد زمن أطول'],
        correct: 1,
        afterText:
            'الفوتون الواحد يقدّم طاقته hf لإلكترون واحد؛ إن كان hf < Ws فلا انتزاع مهما زادت الشدة أو طال الزمن — الشدة تغيّر عدد الفوتونات (وبالتالي عدد الإلكترونات المنتزَعة) لا طاقة كل منها. هذا ما عجز عنه النموذج الموجي.',
      );

  @override
  LabChallenge? get challenge => const LabChallenge(
        title: '🎯 اجعل Ek = ١ eV (± ٠٫١)',
        target: 1.0,
        tolerance: 0.1,
        hint: 'Ek = hc/λ − Ws — مع Ws = 2.2 eV تحتاج hc/λ ≈ 3.2 eV ⇒ λ ≈ 390 nm (الافتراضي 450 nm لا يكفي)',
      );

  @override
  String explain(Map<String, double> p, double measured, double theory) {
    final ev = photonEv(p);
    final ek = ekEv(p);
    final l0 = thresholdNm(p);
    return 'طاقة الفوتون E = hc/λ = ${ev.toStringAsFixed(2)} eV وعمل الانتزاع Ws = ${p['Ws']!.toStringAsFixed(1)} eV '
        '⇒ ${emits(p) ? 'انتزاع بطاقة حركية Ek = ${ek.toStringAsFixed(2)} eV وكمون إيقاف U0 = ${ek.toStringAsFixed(2)} V.' : 'لا انتزاع (hf < Ws).'} '
        'طول موجة العتبة λ0 = hc/Ws = ${l0.toStringAsFixed(0)} nm: أي λ أطول منه لا ينتزع. '
        'عدد الفوتونات في الثانية N = P/E ≈ ${photonsPerSecond(p).toStringAsExponential(2)} s⁻¹ — الشدة تحدد العدد لا الطاقة.';
  }
}

/// السجل: معرّف ⇒ تجربة. المفتاح هو ما يُكتب في `experimentId` بالحزمة.
const Map<String, LabExperiment> labExperiments = {
  'torsion': TorsionExperiment(),
  'gravity': GravityPendulumExperiment(),
  'lc': LcCircuitExperiment(),
  'string': StringWaveExperiment(),
  'photo': PhotoelectricExperiment(),
};
