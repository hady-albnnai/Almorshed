/// المادة ١١ — محرك التصحيح (docs/22 §٤ البند ١١ · docs/14 §د · docs/20 §٢).
///
/// أربعة أنماط، كلها حتمية وبلا شبكة وبلا ذكاء اصطناعي:
///  • [gradeMcq]      مطابقة اختياري مباشرة.
///  • [gradeNumeric]  رقمي: ±٢٪ من المفتاح + الوحدة إلزامية (قاعدة السلم ٢:
///                    الوحدة درجة مستقلة — تُخصم درجة واحدة إن غابت أو أخطأت).
///  • [gradeKeywords] «اذكر N» و«علّل»: مجموعات مفاتيح مع تطبيع عربي؛ درجة
///                    لكل عنصر بحد N (قاعدة ٧)، ومفاتيح مضادة (anti_keys) تُصفّر
///                    البند لأنها تعليل مغلوط بعينه.
///  • [gradeProof]    برهان: خطوات مرتّبة بعلامات السلم، وخصومات حرفية
///                    (إهمال الإشارة −٤ · إهمال φ −١ — قاعدتا ٤ و٥)، مع قبول
///                    الطريق البديل (قاعدة ٦) بترك ترتيب الخطوات مرناً داخل
///                    الكتلة الواحدة.
///
/// المدخلات تأتي من بنود المولّد (`content/generated/*.json`): حقل `answer`
/// للرقمي، `keys/antiKeys` للتعليل، `steps/stepDistractors` للبرهان.
library;

import 'dart:math' as math;

import 'arabic_normalizer.dart';

/// نتيجة تصحيح موحّدة لكل الأنماط.
class GradeResult {
  const GradeResult({
    required this.points,
    required this.maxPoints,
    required this.correct,
    this.notes = const [],
  });

  /// الدرجة الممنوحة (≥ 0).
  final double points;

  /// الدرجة العظمى للبند.
  final double maxPoints;

  /// صحيح كلياً (الدرجة الكاملة).
  final bool correct;

  /// ملاحظات تُعرض للطالب بعبارات السلم (لماذا خُصم؟).
  final List<String> notes;

  double get ratio =>
      maxPoints <= 0 ? 0 : (points / maxPoints).clamp(0, 1).toDouble();

  @override
  String toString() => 'GradeResult($points/$maxPoints, correct=$correct)';
}

/// التسامح النسبي الافتراضي للأجوبة الرقمية (docs/14 §د).
const double numericTolerance = 0.02;

/// خصم غياب الوحدة أو خطئها (قاعدة السلم ٢).
const double unitPenalty = 1;

// ─────────────────────────── ١) اختيار من متعدد ───────────────────────────

GradeResult gradeMcq({
  required int chosenIndex,
  required int correctIndex,
  double weight = 10,
}) {
  final ok = chosenIndex == correctIndex;
  return GradeResult(
    points: ok ? weight : 0,
    maxPoints: weight,
    correct: ok,
    notes: ok ? const [] : const ['الخيار غير صحيح'],
  );
}

// ─────────────────────────── ٢) رقمي ± ٢٪ + وحدة ───────────────────────────

const Map<String, String> _superscripts = {
  '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
  '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9', '⁻': '-',
};

String _plainExponents(String s) {
  final buf = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    buf.write(_superscripts[ch] ?? ch);
  }
  return buf.toString();
}

/// مرادفات الواحدات (عربية وشائعة) → الرمز القياسي.
const Map<String, String> _unitAlias = {
  'م': 'm', 'متر': 'm', 'ثا': 's', 'ث': 's', 'ثانيه': 's', 'ثانية': 's',
  'sec': 's', 'كغ': 'kg', 'نيوتن': 'n', 'جول': 'j', 'هرتز': 'hz',
  'راد': 'rad', 'هزه': 'هزة', 'هزات': 'هزة',
};

final RegExp _unitFactor = RegExp(r'^([^\d\-]+)(-?\d+)?$');

/// شكل قياسي للوحدة: `m/s ≡ m·s⁻¹ ≡ m.s-1`، ترتيب العوامل ثابت، مرادفات
/// عربية. الوحدة الفارغة ترجع ''.
String canonicalUnit(String unit) {
  var u = _plainExponents(unit.trim().toLowerCase())
      .replaceAll('−', '-')
      .replaceAll('×', '·')
      .replaceAll('*', '·')
      .replaceAll('.', '·')
      .replaceAll('^', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll(' ', '');
  if (u.isEmpty) return '';
  final parts = u.split('/');
  final factors = <String>[];
  for (var i = 0; i < parts.length; i++) {
    for (final f in parts[i].split('·')) {
      if (f.isEmpty || f == '1') continue;
      final m = _unitFactor.firstMatch(f);
      if (m == null) {
        factors.add(f);
        continue;
      }
      final base = _unitAlias[m.group(1)] ?? m.group(1)!;
      var exp = m.group(2) == null ? 1 : int.parse(m.group(2)!);
      if (i > 0) exp = -exp;
      factors.add(exp == 1 ? base : '$base$exp');
    }
  }
  factors.sort();
  return factors.join('·');
}

/// أول تعبير عددي في النص: إشارة اختيارية ثم (√عدد | [معامل]π[/مقام] |
/// عدد[×10^أس]). لا يُلتقط رقم ملتصق بحرف قبله (T0 ⇒ لا).
final RegExp _numberExpr = RegExp(
  r'(?<![\p{L}\p{N}.])([+\-±]?)\s*(?:√\s*\(?\s*(\d+(?:\.\d+)?)\s*\)?'
  r'|(\d+(?:\.\d+)?)?\s*π\s*(?:/\s*(\d+(?:\.\d+)?))?'
  r'|(\d+(?:\.\d+)?)(?:\s*[×x*]\s*10\s*\^?\s*([+\-]?\d+))?)',
  unicode: true,
);

/// تحليل إجابة رقمية حرّة مثل «−0.4 m·s⁻²» أو «٢ ثا» أو «8π/5 rad/s» أو
/// «√10 rad·s⁻¹». يرجع null إذا لم يُعثر على عدد. `±` تُهمل (المفتاح موجب).
({double value, String unit})? parseNumericAnswer(String raw) {
  final text = _plainExponents(ArabicNormalizer.latinDigits(raw.trim()))
      .replaceAll('−', '-')
      .replaceAll('٬', '')
      .replaceAll('٫', '.')
      .replaceAll(',', '.');
  final m = _numberExpr.firstMatch(text);
  if (m == null) return null;
  double value;
  if (m.group(2) != null) {
    value = math.sqrt(double.parse(m.group(2)!));
  } else if (m.group(5) != null) {
    value = double.parse(m.group(5)!);
    if (m.group(6) != null) {
      value *= math.pow(10, int.parse(m.group(6)!)).toDouble();
    }
  } else {
    final a = m.group(3) == null ? 1.0 : double.parse(m.group(3)!);
    final b = m.group(4) == null ? 1.0 : double.parse(m.group(4)!);
    value = a * math.pi / b;
  }
  if (m.group(1) == '-') value = -value;
  var rest = text.substring(m.end).trim();
  if (rest.startsWith('·')) rest = rest.substring(1).trim();
  final unit = rest.isEmpty ? '' : rest.split(RegExp(r'\s+')).first;
  return (value: value, unit: unit);
}

/// تصحيح رقمي: مرّر [studentValue]/[studentUnit] بعد التحليل، أو [raw]
/// ليُحلَّل هنا. الوحدة إلزامية حين [unitRequired] (−١ إن غابت أو أخطأت).
/// [signMatters] = false يقبل القيمة المطلقة (حين يطلب السؤال الشدة فقط).
GradeResult gradeNumeric({
  required double keyValue,
  required String keyUnit,
  double? studentValue,
  String? studentUnit,
  String? raw,
  double tolerance = numericTolerance,
  double weight = 10,
  bool unitRequired = true,
  bool signMatters = true,
}) {
  var v = studentValue;
  var u = studentUnit ?? '';
  if (v == null && raw != null) {
    final parsed = parseNumericAnswer(raw);
    if (parsed == null) {
      return GradeResult(
        points: 0,
        maxPoints: weight,
        correct: false,
        notes: const ['لم يُعثر على قيمة عددية في الإجابة'],
      );
    }
    v = parsed.value;
    u = parsed.unit;
  }
  if (v == null) {
    return GradeResult(points: 0, maxPoints: weight, correct: false);
  }
  final scale = keyValue.abs() < 1e-12 ? 1.0 : keyValue.abs();
  final band = tolerance * scale;
  final magnitudeOk = signMatters
      ? (v - keyValue).abs() <= band
      : (v.abs() - keyValue.abs()).abs() <= band;
  if (!magnitudeOk) {
    final signOnly = signMatters &&
        (v.abs() - keyValue.abs()).abs() <= band &&
        v.isNegative != keyValue.isNegative;
    return GradeResult(
      points: 0,
      maxPoints: weight,
      correct: false,
      notes: [
        signOnly ? 'القيمة صحيحة لكن الإشارة معكوسة' : 'القيمة خارج حدود ±٢٪',
      ],
    );
  }
  final notes = <String>[];
  var points = weight;
  final unitOk = canonicalUnit(u) == canonicalUnit(keyUnit);
  if (unitRequired && !unitOk) {
    points = math.max(0.0, weight - unitPenalty);
    notes.add(u.trim().isEmpty ? 'الوحدة ناقصة (−١)' : 'الوحدة خاطئة (−١)');
  }
  return GradeResult(
    points: points,
    maxPoints: weight,
    correct: points == weight,
    notes: notes,
  );
}

// ─────────────────────────── ٣) «اذكر N» و«علّل» ───────────────────────────

/// [keyGroups]: كل عنصر قائمة صياغات مترادفة لعنصر واحد من السلم.
/// «اذكر ٣ عوامل» ⇒ ثلاث مجموعات، [pointsPerItem] درجة لكل مجموعة تُصاب،
/// بحد [maxItems] (قاعدة ٧). مع [weight] تُقسَّم درجة البند على المجموعات.
/// [antiKeys]: تعليل مغلوط بعينه ⇒ صفر.
GradeResult gradeKeywords({
  required String answer,
  required List<List<String>> keyGroups,
  List<String> antiKeys = const [],
  int? maxItems,
  double pointsPerItem = 1,
  double? weight,
}) {
  final n = math.min(maxItems ?? keyGroups.length, keyGroups.length);
  final max = weight ?? n * pointsPerItem;
  if (n == 0) {
    return GradeResult(points: 0, maxPoints: max, correct: false);
  }
  for (final anti in antiKeys) {
    if (ArabicNormalizer.contains(answer, anti)) {
      return GradeResult(
        points: 0,
        maxPoints: max,
        correct: false,
        notes: ['تعليل مغلوط: «$anti»'],
      );
    }
  }
  final notes = <String>[];
  var hits = 0;
  for (final group in keyGroups) {
    if (group.any((k) => ArabicNormalizer.contains(answer, k))) {
      hits++;
    } else {
      notes.add('ناقص: «${group.first}»');
    }
  }
  final counted = math.min(hits, n);
  final points = weight == null ? counted * pointsPerItem : max * counted / n;
  return GradeResult(
    points: points,
    maxPoints: max,
    correct: counted >= n,
    notes: notes,
  );
}

// ─────────────────────────── ٤) برهان بخطوات مرتّبة ───────────────────────────

/// خطوة برهان كما في قالب المولّد: نص السلم، علامتها، وخصومات اختيارية عند
/// أخطاء بعينها (`missing_minus: -4` · `missing_phi: -1`).
class ProofStep {
  const ProofStep({
    required this.n,
    required this.text,
    required this.points,
    this.penalty = const {},
    this.block = 0,
  });

  final int n;
  final String text;
  final double points;

  /// {missing_minus: -4, missing_phi: -1}
  final Map<String, double> penalty;

  /// الكتلة: الخطوات داخل الكتلة نفسها يجوز تبديل ترتيبها (قاعدة ٦: الطريق
  /// البديل مقبول)، أما بين الكتل فالترتيب ملزم.
  final int block;

  factory ProofStep.fromJson(Map<String, dynamic> j, {int? block}) => ProofStep(
        n: j['n'] as int,
        text: j['text'] as String,
        points: (j['points'] as num).toDouble(),
        penalty: {
          for (final e
              in (j['penalty'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: (e.value as num).toDouble(),
        },
        block: block ?? (j['block'] as int? ?? j['n'] as int),
      );
}

/// ما قدّمه الطالب: ترتيب الخطوات (بأرقامها) + أعلام الأخطاء لكل خطوة.
class ProofAttempt {
  const ProofAttempt({
    required this.orderedStepNumbers,
    this.flags = const {},
  });

  /// أرقام الخطوات بالترتيب الذي رتّبها الطالب (الغائبة = لم يكتبها).
  final List<int> orderedStepNumbers;

  /// أعلام الخطأ لكل خطوة: {4: {'missing_minus'}, 1: {'missing_phi'}}.
  final Map<int, Set<String>> flags;
}

GradeResult gradeProof({
  required List<ProofStep> steps,
  required ProofAttempt attempt,
}) {
  final max = steps.fold<double>(0, (s, st) => s + st.points);
  final byN = {for (final s in steps) s.n: s};
  final blockOrder = <int>[];
  for (final s in steps) {
    if (!blockOrder.contains(s.block)) blockOrder.add(s.block);
  }
  final notes = <String>[];
  final seen = <int>{};
  var lastBlockIdx = -1;
  var points = 0.0;
  for (final n in attempt.orderedStepNumbers) {
    final s = byN[n];
    if (s == null || seen.contains(n)) continue;
    seen.add(n);
    final bIdx = blockOrder.indexOf(s.block);
    if (bIdx < lastBlockIdx) {
      // خطوة قبل أوانها: تسلسل البرهان ملزم بين الكتل فلا تُحتسب.
      notes.add('الخطوة ${s.n} في غير موضعها من التسلسل');
      continue;
    }
    lastBlockIdx = bIdx;
    var p = s.points;
    for (final f in attempt.flags[n] ?? const <String>{}) {
      final pen = s.penalty[f];
      if (pen != null) {
        p += pen; // pen سالب — وقد يتجاوز درجة الخطوة (−٤ على خطوة بـ٢،
        notes.add(_penaltyNote(f, pen)); // فيُخصم من المجموع كما في السلم)
      }
    }
    points += p;
  }
  for (final s in steps) {
    if (!seen.contains(s.n)) notes.add('ناقص: ${s.text}');
  }
  points = points.clamp(0, max).toDouble();
  return GradeResult(
    points: points,
    maxPoints: max,
    correct: points >= max - 1e-9,
    notes: notes,
  );
}

String _penaltyNote(String flag, double pen) {
  final a = pen.abs();
  final p = a == a.roundToDouble() ? a.toInt().toString() : a.toString();
  switch (flag) {
    case 'missing_minus':
      return 'إهمال الإشارة السالبة في المعادلة (−$p)';
    case 'missing_phi':
      return 'إهمال الطور الابتدائي φ (−$p)';
    case 'wrong_symbol':
      return 'رمز غير رمز الكتاب (−$p)';
    default:
      return 'خصم $flag (−$p)';
  }
}

// ─────────────────────────── موزّع حسب نوع البند ───────────────────────────

/// تصحيح بند من مخرجات المولّد بحسب حقله `type`.
/// [response]: للاختياري int · للرقمي String خام (أو int إن أُجيب اختيارياً)
/// · لـ«علّل/اذكر» String · للبرهان [ProofAttempt].
GradeResult gradeItem(Map<String, dynamic> item, Object response) {
  final type = item['type'] as String? ?? 'mcq';
  final weight = (item['weight'] as num? ?? 10).toDouble();
  GradeResult mcq(int chosen) => gradeMcq(
        chosenIndex: chosen,
        correctIndex: item['correctIndex'] as int,
        weight: weight,
      );
  switch (type) {
    case 'numeric':
    case 'problem':
      final a = item['answer'] as Map<String, dynamic>?;
      if (a != null && response is String) {
        return gradeNumeric(
          keyValue: (a['value'] as num).toDouble(),
          keyUnit: a['unit'] as String? ?? '',
          raw: response,
          tolerance: (a['tolerance'] as num? ?? numericTolerance).toDouble(),
          weight: weight,
        );
      }
      if (response is int) return mcq(response);
    case 'why':
    case 'list':
      if (response is String) {
        final keys =
            (item['keys'] as List<dynamic>? ?? const []).cast<String>();
        return gradeKeywords(
          answer: response,
          keyGroups: [
            for (final k in keys) [k],
          ],
          antiKeys:
              (item['antiKeys'] as List<dynamic>? ?? const []).cast<String>(),
          weight: weight,
        );
      }
      if (response is int) return mcq(response);
    case 'proof':
      if (response is ProofAttempt) {
        final raw =
            (item['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
        return gradeProof(
          steps: [for (final s in raw) ProofStep.fromJson(s)],
          attempt: response,
        );
      }
    default:
      if (response is int) return mcq(response);
  }
  throw ArgumentError('نوع البند $type لا يقبل هذا الشكل من الإجابة');
}
