/// المادة ١٤ — نواة تجربة فاراداي (١): مغناطيس ووشيعة (تحريض كهرومغناطيسي).
/// النموذج المرجعي المعتمد من المالك ٢٠٢٦-١٠-٠٢ (docs/prototypes/
/// flash-faraday1.html v1.1) منقول حرفياً بالثوابت نفسها.
///
/// كل شيء خالص وحتمي: خطوة ثابتة dt = 1/240 ث (docs/12 §٦) — نفس السحب ⇒
/// نفس المسار بتّاً. ε = −N·dΦ/dt بمشتقّة تحليلية (لا أرقام مزيفة)، والإبرة
/// معادلة إبرة الجلفانومتر ang″ = 60·target − 30·ang − 7·angV بدراية RK4
/// (خطية ⇒ RK4 مطابقة للحل الدقيق على الخطوة).
library;

import 'dart:math' as math;

import 'spring_sim.dart' show simDt;

// ── هندسة المشهد المنطقي (960×440) — كما بالمعتمد v1.1 ──
const double faradaySceneW = 960.0;
const double faradaySceneH = 440.0;
const double faradayCoilX = 230.0; // مركز الوشيعة
const double faradayMagnetLen = 130.0;
const double faradayMagnetMinX = 330.0; // حاجز الوشيعة (وجهها + هامش)
const double faradayMagnetMaxX = 660.0;
const double faradayEpsRef = 2.0; // المقياس المطلق للقراءة ٪

/// بُعد نواة التدفق a (النموذج المعتمد): Φ(u) = (a²/(a²+u²))^1.5 بـ a = 0.7.
const double _a2 = 0.49;

double _faradayCoilFace() => faradayCoilX + 26.0;

/// المسافة الاسمية بين وجه المغناطيس ووجه الوشيعة (بوحدات ١٠٠ بكسل).
double faradayUOf(double mx) =>
    (mx - faradayMagnetLen / 2.0 - _faradayCoilFace()) / 100.0;

/// التدفق النسبي Φ(u) — منحل من مغلق مغناطيسي مختصر (نموذج المعتمد).
double faradayFluxOf(double u) =>
    math.pow(_a2 / (_a2 + u * u), 1.5).toDouble();

/// dΦ/du تحليلياً: −3a²·u/(a²+u²)^2.5.
double faradayFluxDeriv(double u) =>
    -3.0 * 0.343 * u / math.pow(_a2 + u * u, 2.5).toDouble();

/// القوة الدافعة الكهربية المتحرّضة ε = −N·dΦ/dt مع v بوحدات المشهد
/// (v/100 ⇒ m/ث اسمية) وقطبية المغناطيس ±1 — مقيسة على `faradayEpsRef`.
double faradayEmf(
  double u,
  double v, {
  required int turns,
  required int polarity,
}) =>
    -(turns / 15.0) *
    faradayFluxDeriv(u) *
    (v / 100.0) *
    polarity;

/// قراءة المقياس المنمّطة (٪) — تُعرض على الإبرة بعد clamp داخل الخطوة.
double faradayEpsPercent(double u, double v,
        {required int turns, required int polarity}) =>
    (faradayEmf(u, v, turns: turns, polarity: polarity) / faradayEpsRef) *
    100.0;

/// إعدادات يتحكم بها المستخدم: قطبية المغناطيس (±1) وعدد اللفات N.
class Faraday1Config {
  const Faraday1Config({this.polarity = 1, this.turns = 15});

  /// ‎+1: الوجه N نحو الوشيعة · ‎−1: الوجه S.
  final int polarity;
  final int turns;

  Faraday1Config flipPolarity() =>
      Faraday1Config(polarity: -polarity, turns: turns);

  Faraday1Config withTurns(int n) =>
      Faraday1Config(polarity: polarity, turns: n);
}

/// الحركة التلقائية (عند عدم السحب): اقتراب بطيء/سريع أو إبعاد.
enum Faraday1Drive { none, slow, fast, away }

/// حالة اللحظية: موضع المغناطيس وسرعته، زاوية الإبرة وسرعتها الزاوية، الزمن.
class Faraday1State {
  const Faraday1State({
    this.mx = 620.0,
    this.v = 0.0,
    this.ang = 0.0,
    this.angV = 0.0,
    this.t = 0.0,
  });

  final double mx; // مركز المغناطيس بوحدات المشهد المنطقي
  final double v; // سرعته (بوحدات المشهد/ث — موجبة = إبعاد)
  final double ang; // زاوية الإبرة المنمّطة (±1 = نهاية المقياس)
  final double angV; // سرعتها الزاوية
  final double t; // زمن المحاكاة (ث)

  bool get magnetAtCoilStop => mx <= faradayMagnetMinX + 1e-9;
  bool get magnetAtFarStop => mx >= faradayMagnetMaxX - 1e-9;

  double get u => faradayUOf(mx);

  /// Φ مع إشارة القطبية (للعرض على عدّاد التدفق والراسم).
  double phiOf(Faraday1Config cfg) =>
      cfg.polarity * faradayFluxOf(u);

  /// خطوة حتمة واحدة (simDt): حركة المغناطيس + إبرة RK4.
  ///
  /// أثناء السحب `dragging = true` يبقى الموضع والسرعة كما ضبطهما
  /// المستخدم (الشاشة تحدّثهما مباشرة) وتُخطى الحركة التلقائية.
  Faraday1State step({
    required Faraday1Config cfg,
    required Faraday1Drive drive,
    required bool dragging,
  }) {
    // ١) حركة المغناطيس — تخطّى أثناء السحب
    var mx = this.mx;
    var v = this.v;
    if (!dragging) {
      v = switch (drive) {
        Faraday1Drive.slow => -90.0,
        Faraday1Drive.fast => -260.0,
        Faraday1Drive.away => 180.0,
        Faraday1Drive.none => v * math.exp(-3.0 * simDt), // تخلخف طبيعي
      };
      mx += v * simDt;
      if (mx < faradayMagnetMinX) mx = faradayMagnetMinX;
      if (mx > faradayMagnetMaxX) mx = faradayMagnetMaxX;
      if (mx == faradayMagnetMinX || mx == faradayMagnetMaxX) v = 0.0;
    }

    // ٢) هدف الإبرة = القراءة المنمّطة (±1)
    final epsN = faradayEmf(faradayUOf(mx), v,
            turns: cfg.turns, polarity: cfg.polarity) /
        faradayEpsRef;
    final target = epsN.clamp(-1.0, 1.0).toDouble();

    // ٣) إبرة الجلفانومتر: ang″ = 60·target − 30·ang − 7·angV — RK4
    double acc(double a, double av) => 60.0 * target - 30.0 * a - 7.0 * av;
    final k1a = angV;
    final k1w = acc(ang, angV);
    final k2a = angV + simDt / 2.0 * k1w;
    final k2w = acc(ang + simDt / 2.0 * k1a, angV + simDt / 2.0 * k1w);
    final k3a = angV + simDt / 2.0 * k2w;
    final k3w = acc(ang + simDt / 2.0 * k2a, angV + simDt / 2.0 * k2w);
    final k4a = angV + simDt * k3w;
    final k4w = acc(ang + simDt * k3a, angV + simDt * k3w);
    final ang2 = ang + simDt / 6.0 * (k1a + 2.0 * k2a + 2.0 * k3a + k4a);
    final angV2 =
        angV + simDt / 6.0 * (k1w + 2.0 * k2w + 2.0 * k3w + k4w);

    return Faraday1State(
      mx: mx,
      v: v,
      ang: ang2,
      angV: angV2,
      t: t + simDt,
    );
  }

  double uOf(double x) => faradayUOf(x);

  /// ε المنمّطة للحالة الحالية (قبل clamp — للراسم والعرض).
  double epsNormalized(Faraday1Config cfg) =>
      faradayEmf(u, v, turns: cfg.turns, polarity: cfg.polarity) /
      faradayEpsRef;
}

/// عيّنة قياس لحظية — سجل الراسم والذيول والإعادة.
class Faraday1Sample {
  const Faraday1Sample(this.t, this.epsN, this.phi, this.ang);
  final double t; // زمن المحاكاة
  final double epsN; // القراءة المنمّطة (±1 بعد clamp للعرض)
  final double phi; // التدفق الموقّع المنمّط
  final double ang; // زاوية الإبرة
}

/// حالة الإعادة البطيئة ×٠٫٢٥ — التقدّم بزمن الحائط لا بزمن المحاكاة
/// (المحاكاة متوقفة أثناءها) — كما بالمعتمد v1.1.
class Faraday1Replay {
  const Faraday1Replay({required this.t0, required this.progress});

  final double t0; // بداية النافذة (آخر ٣ث)
  final double progress; // كم أُعيد حتى الآن (ث ×٠٫٢٥)

  Faraday1Replay advance(double dtReal) =>
      Faraday1Replay(t0: t0, progress: progress + dtReal * 0.25);

  bool get done => progress >= 3.0;
}

/// مسجّل القياس: نافذة ٦ث، ذيول الإبرة ٠٫٩ث، قمم مُحتفَظة، منفتاح الشرح
/// وتحدّي الانحرافين المتعاكسين — تغذيته خالصة (نفس روح `PeriodMeter`).
class Faraday1Recorder {
  /// نافذة الراسم: ٦ ث × ٢٤٠ خطوة (قصّ على دفعات — بلا removeAt كل خطوة).
  static const int windowSteps = 6 * 240;

  /// فتح «اشرح» بعد أول انحراف ملموس (نموذج المعتمد: |ang| > 0.15).
  static const double explainThreshold = 0.15;

  /// التحدّي: دفعتان متعاكستان ≥ ٦٠٪ من المقياس.
  static const double challengeAim = 0.6;

  final List<Faraday1Sample> buf = <Faraday1Sample>[];
  final List<Faraday1Sample> ghosts = <Faraday1Sample>[]; // ذيول ٠٫٩ث
  double peakHold = 0.0; // أكبر |ang| (إبرة قمّة باهتة)
  double peakPos = 0.0; // أعلى قراءة موجبة (٪ منمّطة)
  double peakNeg = 0.0; // أدنى قراءة سالبة
  bool explained = false;
  bool challengeDone = false;
  Faraday1Replay? replay;

  void feed(Faraday1State s, {required double epsN, required double phi}) {
    buf.add(Faraday1Sample(s.t, epsN.clamp(-1.0, 1.0).toDouble(), phi, s.ang));
    if (buf.length > windowSteps + 240) {
      buf.removeRange(0, buf.length - windowSteps);
    }
    // ذيول الإبرة: عيّنة كل ٢٠ms وتُسقط الأقدم من ٠٫٩ث.
    if (ghosts.isEmpty || s.t - ghosts.last.t >= 0.02) {
      ghosts.add(buf.last);
    }
    while (ghosts.isNotEmpty && s.t - ghosts.first.t > 0.9) {
      ghosts.removeAt(0);
    }
    if (s.ang.abs() > peakHold.abs()) peakHold = s.ang;
    if (epsN > peakPos) peakPos = epsN;
    if (epsN < peakNeg) peakNeg = epsN;
    if (!explained && s.ang.abs() > explainThreshold) explained = true;
    if (!challengeDone && peakPos >= challengeAim && peakNeg <= -challengeAim) {
      challengeDone = true;
    }
  }

  /// العيّنة الأولى التي زمنها ≥ t — لإبرة الشبح أثناء الإعادة.
  Faraday1Sample? sampleAt(double t) {
    for (var i = buf.length - 1; i >= 0; i--) {
      if (buf[i].t >= t) return buf[i];
    }
    return buf.isEmpty ? null : buf.first;
  }

  /// الشرط الكافي لتفعيل زر الإعادة: نصف ثانية مقيسة على الأقل.
  bool get canReplay =>
      replay == null && buf.length >= 120 && buf.last.t - buf.first.t >= 0.5;

  void startReplay() {
    if (!canReplay) return;
    final t1 = buf.last.t;
    final t0 = (t1 - 3.0 > buf.first.t) ? t1 - 3.0 : buf.first.t;
    replay = Faraday1Replay(t0: t0, progress: 0.0);
  }

  void reset() {
    buf.clear();
    ghosts.clear();
    peakHold = 0.0;
    peakPos = 0.0;
    peakNeg = 0.0;
    explained = false;
    challengeDone = false;
    replay = null;
  }
}

/// سؤال توقّع فاراداي (١) — الخيار الصحيح فهرس ٠ (نصّه كما بالمعتمد).
const List<String> faraday1PredictOptions = <String>[
  'ينحرف المؤشر لحظة الاقتراب ثم يعود إلى الصفر عند السكون',
  'ينحرف ويبقى منحرفاً ما دام المغناطيس قريباً',
  'لا يتحرك المؤشر لأن المغناطيس لم يلمس الوشيعة',
];
const int faraday1PredictCorrect = 0;

/// نقاط بطاقة «اشرح» — تُعرض بعد أول قياس (منفتاح الشرح).
const String faraday1Law = 'ε = −N · dΦ/dt';
const List<String> faraday1ExplainBullets = <String>[
  'القراءة تظهر فقط أثناء تغيّر التدفق: اقتراب وإبعاد يعطيان انحرافين متعاكسين، والسكون يعطي صفراً.',
  'كلما أسرعت بالسحب كبرت القراءة — قارن «اقتراب بطيء» بـ«سريع».',
  'قلب قطبية المغناطيس يعكس جهة القراءة كاملة.',
  'زيادة عدد اللفات N تضخّم القراءة بالقدر نفسه.',
  'اتجاه التيار المتحرّض يقاوم التغيّر (قاعدة لينز): عند اقتراب N تتكلّف وجه الوشيعة بقطب N للنفور.',
];
