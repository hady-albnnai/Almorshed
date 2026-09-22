/// المادة ١١-ب — تصحيح «المسألة بأجزاء» (parts-v1 — قرار ٦٨ · F-GEN3).
///
/// السلم الوزاري يُطبَّق **سطراً سطراً** كما هو موصوف في docs/20 §٢ قاعدة ١:
///  • العلاقة (٥) تُطابَق بمفاتيحها بعد التطبيع العربي، وتُصفَر بالمفاتيح المضادة.
///  • التعويض (٣) يُقاس بأرقام السلم: كل رقم متوقع مكتوباً ⇒ كامل، بعضها ⇒ نصف،
///    لا شيء ⇒ صفر — لا تخمين في النص.
///  • النتيجة (١) عددية بتفاوت ±٢٪ كما في [gradeNumeric]، و**متابعة الخطأ** تُقبل:
///    من أخطأ في الجزء السابق ومشى صح عليه أن يُكافأ (scale × جوابه^power).
///  • الوحدة (١) درجة مستقلة، ولا تُمنح إلا لمن صحت نتيجته (قاعدة السلم ٢).
///
/// بلا شبكة وبلا ذكاء اصطناعي وبلا حالة داخلية: المدخل بند + أجوبة الطالب،
/// والمخرج درجات مرقّمة سطراً سطراً تُعرض له كما تعرض للمصحّح.
library;

import 'dart:math' as math;

import '../content/generated_items.dart';
import '../util/arabic_number.dart';
import 'arabic_normalizer.dart';
import 'grading_engine.dart';

/// إجابة الطالب في جزء واحد. [chosen] فهرس الخيار إن كان للجزء خيارات — وعندها
/// تُصحَّح النتيجة والوحدة به، وإلا فبسطر [result] (قيمة + وحدة معاً).
typedef PartAnswer = ({
  String relation,
  String substitution,
  String result,
  int? chosen,
});

/// جزء لم يُجب عنه — للاكتمال وإلا فالفرق بين صفرَين.
const PartAnswer emptyPartAnswer =
    (relation: '', substitution: '', result: '', chosen: null);

/// درجة سطر واحد من السلّم (ما يستحقه الطالب وما أخذ ولماذا).
class PartLineScore {
  const PartLineScore({
    required this.step,
    required this.kind,
    required this.points,
    required this.maxPoints,
    this.note,
  });

  final String step;
  final String kind;
  final double points;
  final double maxPoints;
  final String? note;

  bool get lost => points < maxPoints;
  bool get full => !lost;

  @override
  String toString() =>
      '$step: ${points.toStringAsFixed(1)}/${maxPoints.toStringAsFixed(1)}'
      '${note == null ? '' : ' — $note'}';
}

/// نتيجة جزء كامل.
class PartScore {
  const PartScore({
    required this.label,
    required this.prompt,
    required this.lines,
    required this.points,
    required this.maxPoints,
    this.followThrough = false,
  });

  final String label;
  final String prompt;
  final List<PartLineScore> lines;
  final double points;
  final double maxPoints;

  /// أُعطي حقّه لأن نتيجته مبنية على جوابه الخاطئ في جزء سابق.
  final bool followThrough;

  List<String> get notes => [
        for (final l in lines)
          if (l.note != null) l.note!,
      ];

  @override
  String toString() => 'الجزء $label: $points/$maxPoints';
}

/// نتيجة المسألة كلها — تُحوَّل إلى [GradeResult] واحدة لنفس مسار العرض.
class PartsGrade {
  const PartsGrade({
    required this.parts,
    required this.points,
    required this.maxPoints,
  });

  final List<PartScore> parts;
  final double points;
  final double maxPoints;

  bool get correct => maxPoints > 0 && points >= maxPoints;

  List<String> get notes {
    final out = <String>[];
    for (final p in parts) {
      for (final n in p.notes) {
        out.add('الجزء ${p.label}: $n');
      }
      if (p.followThrough) {
        out.add('الجزء ${p.label}: متابعة للخطأ (FT) — النتيجة مبنية على جوابك '
            'السابق، والرقم الصحيح مختلف');
      }
    }
    return out;
  }

  GradeResult toGrade() => GradeResult(
        points: points,
        maxPoints: maxPoints,
        correct: correct,
        notes: notes,
      );

  static final PartsGrade empty =
      PartsGrade(parts: const [], points: 0, maxPoints: 0);
}

/// تصحيح بند بأجزاء: [answers] مفهرسة بوسم الجزء (`١`، `٢`، …) كما يولّده المولّد.
PartsGrade gradeParts(GeneratedItem item, Map<String, PartAnswer> answers) {
  final parts = item.parts;
  if (parts.isEmpty) return PartsGrade.empty;
  final byLabel = {for (final p in parts) p.label: p};
  final scores = <PartScore>[];
  var total = 0.0;
  var max = 0.0;
  for (final p in parts) {
    final a = answers[p.label] ?? emptyPartAnswer;
    final lines = <PartLineScore>[];
    lines.add(_relationLine(p, a));
    final sub = _substitutionLine(p, a);
    if (sub != null) lines.add(sub);
    final res = _resultLine(p, a, byLabel, answers);
    lines.add(res.score);
    final unit = _unitLine(p, a, res);
    if (unit != null) lines.add(unit);
    lines.removeWhere((l) => l.maxPoints <= 0);
    final got = lines.fold<double>(0, (s, l) => s + l.points);
    total += got;
    max += p.weight;
    scores.add(PartScore(
      label: p.label,
      prompt: p.prompt,
      lines: lines,
      points: got,
      maxPoints: p.weight,
      followThrough: res.followThrough,
    ));
  }
  return PartsGrade(parts: scores, points: total, maxPoints: max);
}

// ───────────────────────────── الأسطر ─────────────────────────────

PartLineScore _relationLine(GeneratedPart p, PartAnswer a) {
  final max = p.groupPoints('relation');
  if (max <= 0) {
    return PartLineScore(step: 'العلاقة', kind: 'relation', points: 0, maxPoints: 0);
  }
  // المفتاح يُطابَق على النص الخام: `contains` يعمل بالكلمات المتتالية بعد
  // التطبيع، وحذف المسافات قبله يكسر المطابقة.
  final typed = '${a.relation} ${a.substitution} ${a.result}';
  if (a.relation.trim().isEmpty) {
    return PartLineScore(
      step: 'العلاقة',
      kind: 'relation',
      points: 0,
      maxPoints: max,
      note: 'لم تُكتب العلاقة ⇒ تُخصم درجتها',
    );
  }
  for (final anti in p.groupAntiKeys('relation')) {
    if (ArabicNormalizer.contains(typed, anti)) {
      return PartLineScore(
        step: 'العلاقة',
        kind: 'relation',
        points: 0,
        maxPoints: max,
        note: 'صيغة مغلوضة عند المصحّح: $anti',
      );
    }
  }
  final keys = p.groupKeys('relation');
  final hit = keys.isEmpty || keys.any((k) => ArabicNormalizer.contains(typed, k));
  return PartLineScore(
    step: 'العلاقة',
    kind: 'relation',
    points: hit ? max : 0,
    maxPoints: max,
    note: hit ? null : 'العلاقة المطلوبة لم ترد كما في السلم',
  );
}

PartLineScore? _substitutionLine(GeneratedPart p, PartAnswer a) {
  final max = p.groupPoints('substitution');
  if (max <= 0) return null;
  final typed = _flat('${a.relation} ${a.substitution} ${a.result}');
  final expect = p.groupExpect('substitution');
  if (expect.isEmpty) {
    final wrote = a.substitution.trim().isNotEmpty;
    return PartLineScore(
      step: 'التعويض',
      kind: 'substitution',
      points: wrote ? max : 0,
      maxPoints: max,
      note: wrote ? null : 'لم يُكتب التعويض',
    );
  }
  final hits =
      expect.where((t) => typed.contains(_flat(t))).toList(growable: false).length;
  final got = hits == expect.length
      ? max
      : (hits > 0 ? max / 2 : 0.0);
  return PartLineScore(
    step: 'التعويض',
    kind: 'substitution',
    points: got,
    maxPoints: max,
    note: got == max
        ? null
        : 'من أرقام السلم المكتوبة: ${ArabicNumber.from(hits)} '
            'من ${ArabicNumber.from(expect.length)}',
  );
}

/// نتيجة الجزء: من الخيار المختار أو من سطر «النتيجة والوحدة».
_ResultOutcome _resultLine(GeneratedPart p, PartAnswer a,
    Map<String, GeneratedPart> byLabel, Map<String, PartAnswer> answers) {
  final max = p.groupPoints('result');
  if (max <= 0) {
    return _ResultOutcome(
      score: PartLineScore(
          step: 'النتيجة', kind: 'result', points: 0, maxPoints: 0),
    );
  }
  double? student;
  if (p.hasOptions && a.chosen != null) {
    student = _optionValue(p, a.chosen!);
    if (a.chosen == p.correctIndex) {
      return _ResultOutcome(
        score: PartLineScore(
            step: 'النتيجة', kind: 'result', points: max, maxPoints: max),
      );
    }
    if (student != null && _followThroughHit(p, student, byLabel, answers)) {
      return _ResultOutcome(
        score: PartLineScore(
            step: 'النتيجة',
            kind: 'result',
            points: max,
            maxPoints: max,
            note: 'خيارك خاطئ لكنه متسق مع جوابك السابق ⇒ متابعة مقبولة'),
        followThrough: true,
      );
    }
    return _ResultOutcome(
      score: PartLineScore(
          step: 'النتيجة',
          kind: 'result',
          points: 0,
          maxPoints: max,
          note: 'القيمة غير صحيحة'),
    );
  }
  student = a.result.trim().isEmpty ? null : _parseResult(a.result)?.value;
  if (student == null) {
    return _ResultOutcome(
      score: PartLineScore(
          step: 'النتيجة',
          kind: 'result',
          points: 0,
          maxPoints: max,
          note: 'لم تُكتب النتيجة بوحدتها'),
    );
  }
  final key = p.answerValue;
  if (key == null) return _textKeyLine(p, a, max);
  final band = p.tolerance * (key.abs() < 1e-12 ? 1.0 : key.abs());
  if ((student - key).abs() <= band) {
    return _ResultOutcome(
      score: PartLineScore(
          step: 'النتيجة', kind: 'result', points: max, maxPoints: max),
    );
  }
  if (_followThroughHit(p, student, byLabel, answers)) {
    return _ResultOutcome(
      score: PartLineScore(
          step: 'النتيجة',
          kind: 'result',
          points: max,
          maxPoints: max,
          note: 'متابعة للخطأ (FT): النتيجة مبنية على جوابك في الجزء السابق'),
      followThrough: true,
    );
  }
  return _ResultOutcome(
    score: PartLineScore(
        step: 'النتيجة',
        kind: 'result',
        points: 0,
        maxPoints: max,
        note: 'القيمة خارج حدود ±'
            '${ArabicNumber.from((p.tolerance * 100).round())}٪'),
  );
}

PartLineScore? _unitLine(
    GeneratedPart p, PartAnswer a, _ResultOutcome res) {
  final max = p.groupPoints('unit');
  if (max <= 0) return null;
  if (res.score.points <= 0) {
    return PartLineScore(
      step: 'الوحدة',
      kind: 'unit',
      points: 0,
      maxPoints: max,
      note: 'بلا نتيجة صحيحة ⇒ لا درجة وحدة',
    );
  }
  if (!p.unitRequired) {
    return PartLineScore(step: 'الوحدة', kind: 'unit', points: max, maxPoints: max);
  }
  // الوحدة من نفس تحليل النتيجة: «√a/b Ω» لا يُقرأ منه شيء لولا _parseResult
  final unit = p.hasOptions && a.chosen != null
      ? (parseNumericAnswer(_unitOfOption(p, a.chosen!))?.unit ?? '')
      : (_parseResult(a.result)?.unit ?? '');
  final ok = canonicalUnit(unit) == canonicalUnit(p.answerUnit);
  return PartLineScore(
    step: 'الوحدة',
    kind: 'unit',
    points: ok ? max : 0,
    maxPoints: max,
    note: ok
        ? null
        : (unit.trim().isEmpty
            ? 'الوحدة ناقصة (−${max.toStringAsFixed(0)})'
            : 'الوحدة خاطئة — الصحيح ${p.answerUnit}'),
  );
}

/// جزء مفتاحه نصّي/رمزي بلا قيمة عددية: تُقاس نتيجته بمطابقة نصّ المفتاح بعد
/// التطبيع — لا تقدير ولا تخمين (ولا تُمنح درجة إلا لنصّ السلم).
_ResultOutcome _textKeyLine(GeneratedPart p, PartAnswer a, double max) {
  final wrote =
      a.result.trim().isNotEmpty || (p.hasOptions && a.chosen != null);
  final hit = wrote &&
      (p.hasOptions
          ? a.chosen == p.correctIndex
          : ArabicNormalizer.contains(a.result, p.answerText));
  return _ResultOutcome(
    score: PartLineScore(
      step: 'النتيجة',
      kind: 'result',
      points: hit ? max : 0,
      maxPoints: max,
      note: hit
          ? null
          : (wrote ? 'لم تطابق الصيغة المتوقعة في السلم' : 'لم تُكتب النتيجة'),
    ),
  );
}

// ───────────────────────────── أدوات ─────────────────────────────

bool _followThroughHit(GeneratedPart p, double studentValue,
    Map<String, GeneratedPart> byLabel, Map<String, PartAnswer> answers) {
  for (final f in p.follow) {
    final dep = byLabel[f.dependsOn];
    if (dep == null) continue;
    final dv = _studentValue(dep, answers[dep.label] ?? emptyPartAnswer);
    if (dv == null || dv == 0) continue;
    final derived = f.scale * math.pow(dv, f.power).toDouble();
    if (derived == 0) continue;
    if ((studentValue - derived).abs() <= f.tolerance * derived.abs()) return true;
  }
  return false;
}

double? _studentValue(GeneratedPart p, PartAnswer a) {
  if (p.hasOptions && a.chosen != null) return _optionValue(p, a.chosen!);
  if (a.result.trim().isEmpty) return null;
  return _parseResult(a.result)?.value;
}

final RegExp _radicalQuotient =
    RegExp(r'√\s*\(?\s*(\d+(?:[.]\d+)?)\s*\)?\s*[÷/]\s*(\d+(?:[.]\d+)?)');

/// تحليل نتيجة الطالب: محرك الرقمي المشترك، مع تصحيح جذر على صورة `√a/b`
/// (صيغة الكتاب في المسائل) — وإلا فُهمت √10000/100 على أنها √10000 وحده.
/// لا يمسّ هذا المسار المسطّح (numeric) في `gradeNumeric` لا من قريب ولا بعيد.
({double value, String unit})? _parseResult(String raw) {
  final hit = _radicalQuotient.firstMatch(raw);
  if (hit == null) return parseNumericAnswer(raw);
  final radical = double.parse(hit.group(1)!);
  final den = double.parse(hit.group(2)!);
  if (den == 0) return parseNumericAnswer(raw);
  final rest = raw.substring(hit.end).trim();
  return (
    value: math.sqrt(radical) / den,
    unit: rest.isEmpty ? '' : rest.split(RegExp(r'\s+')).first,
  );
}

double? _optionValue(GeneratedPart p, int i) =>
    (i >= 0 && i < p.optionValues.length) ? p.optionValues[i] : null;

String _unitOfOption(GeneratedPart p, int i) =>
    (i >= 0 && i < p.options.length) ? p.options[i] : '';

/// تطبيع للمقارنة النصية: أرقام لاتينية، فاصلة عشرية نقطية، وحذف المسافات.
String _flat(String s) => ArabicNormalizer.latinDigits(s)
    .replaceAll('٫', '.')
    .replaceAll('،', ',')
    .replaceAll(' ', '');

class _ResultOutcome {
  const _ResultOutcome({required this.score, this.followThrough = false});

  final PartLineScore score;
  final bool followThrough;
}
