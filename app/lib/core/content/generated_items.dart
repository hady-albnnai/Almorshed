/// المادة ١٢ — بنود المولّد (tools/gen_items.py) كما تصل للتطبيق.
///
/// المصدر: `assets/content/items.json` (المجمّع الكامل من
/// `content/generated/ALL.items.json` — الوحدات الخمس/١٧ فصلاً). كل بند `approved:false` حتى يعتمده
/// الأستاذ — الفلتر نفسه المعتمد في F2.4: الوضع العادي يعرض المعتمد فقط،
/// ووضع المراجعة يفتح الكل بشارة «قيد المراجعة».
///
/// **بنود الأجزاء (`grading: "parts-v1"` — قرار ٦٨) تدخل هذا الأصل منذ F-GEN3**
/// (`python3 tools/gen_items.py --asset --parts-asset`): `GeneratedPart` هنا يقرأ
/// الأجزاء (خيارات لكل جزء، مفتاح رقمي أو نصّي، `unitRequired`، `rubric` مصحَّح
/// آلياً بحقل `kind`)، وتصحيح «سطراً سطراً» مع متابعة الخطأ في
/// `core/grading/parts_grading.dart`. وبلا `--parts-asset` يعود الأصل إلى البنود
/// المسطّحة وحدها — رجوع آمن بكلمة واحدة إن تعطّل مسار السلّم.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// وسوم داخلية من المولّد (مثل `[invert_ratio]` / `[forget_sqrt]`) — تُزال من
/// خطوات الحل قبل العرض للطالب (عيب أن تظهر أسماء برمجية في الشرح).
final RegExp _internalTagRe = RegExp(r'\s*\[[a-z][a-z0-9_]*\]');

List<String> _cleanSteps(List<dynamic>? raw) => (raw ?? const [])
    .map((e) => e.toString().replaceAll(_internalTagRe, '').trim())
    .toList(growable: false);

/// نمط البند — يحدّد واجهة الإجابة وطريقة التصحيح.
enum ItemKind { mcq, numeric, why, proof }

ItemKind itemKindOf(String type) => switch (type) {
      'numeric' || 'problem' => ItemKind.numeric,
      'why' || 'list' => ItemKind.why,
      'proof' => ItemKind.proof,
      _ => ItemKind.mcq,
    };

/// بند مولَّد — يحمل الخام كاملاً (`raw`) ليُمرَّر لمحرك التصحيح كما هو.
class GeneratedItem {
  const GeneratedItem({
    required this.id,
    required this.templateId,
    required this.chapter,
    required this.kind,
    required this.approved,
    required this.stem,
    required this.options,
    required this.correctIndex,
    required this.solutionSteps,
    required this.weight,
    required this.raw,
    this.parts = const [],
    this.grading,
  });

  final int id;
  final String templateId;
  final String chapter;
  final ItemKind kind;
  final bool approved;
  final String stem;
  final List<String> options;
  final int correctIndex;
  final List<String> solutionSteps;
  final double weight;

  /// الخام (answer/keys/antiKeys/steps/optionRules/answerBasis…).
  final Map<String, dynamic> raw;

  /// أجزاء المسألة (قرار ٦٨) — فارغ إلا في بنود `grading: parts-v1`.
  final List<GeneratedPart> parts;

  /// طابع التصحيح: null = مسطّح (خيار واحد) · `parts-v1` = سلّم سطراً سطراً.
  final String? grading;

  /// بند مسألة بأجزاء: لا مفتاح مسطّح له، وتصحيحه في `core/grading/parts_grading.dart`.
  bool get isParts => grading == partsGradingKey && parts.isNotEmpty;

  /// مجموع أوزان الأجزاء (يُطابق `weight` وقت البناء — يفحصه المولّد في بايثون).
  double get partsWeight =>
      parts.fold<double>(0, (s, p) => s + p.weight);

  /// المفتاح الرقمي إن وُجد.
  ({double value, String unit})? get numericAnswer {
    final a = raw['answer'] as Map<String, dynamic>?;
    if (a == null) return null;
    return (
      value: (a['value'] as num).toDouble(),
      unit: a['unit'] as String? ?? '',
    );
  }

  /// خطوات البرهان الخام (للبرهان فقط).
  List<Map<String, dynamic>> get proofSteps =>
      (raw['steps'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  /// مفاتيح «علّل» و«اذكر».
  List<String> get keys =>
      (raw['keys'] as List<dynamic>? ?? const []).cast<String>();

  String? get answerBasis => raw['answerBasis'] as String?;

  factory GeneratedItem.fromJson(Map<String, dynamic> j) => GeneratedItem(
        id: j['id'] as int,
        templateId: j['templateId'] as String? ?? '',
        chapter: j['chapter'] as String,
        kind: itemKindOf(j['type'] as String? ?? 'mcq'),
        approved: j['approved'] as bool? ?? false,
        stem: j['stem'] as String,
        options: (j['options'] as List<dynamic>? ?? const []).cast<String>(),
        correctIndex: j['correctIndex'] as int? ?? -1,
        solutionSteps: _cleanSteps(j['solutionSteps'] as List<dynamic>?),
        weight: (j['weight'] as num? ?? 10).toDouble(),
        raw: j,
        grading: j['grading'] as String?,
        parts: _readParts(j),
      );
}

// ─────────────────────────── المسألة بأجزاء — parts-v1 ───────────────────────────

/// مفتاح طابع بنود الأجزاء كما يكتبه المولّد (`tools/gen_items.py`).
const String partsGradingKey = 'parts-v1';

/// سطر واحد من سلّم الجزء: `kind` هو ما يُصحَّح به آلياً، و`step` هو ما يُعرض.
/// • relation   العلاقة المطلوبة (مفاتيح + مفاتيح مضادة) — ٥ في السلم
/// • substitution التعويض (أرقام `expect` يجب أن تظهر) — ٣
/// • result     النتيجة العددية — ١
/// • unit       الوحدة — ١ (تُلغى للمقادير بلا بُعد)
class GeneratedRubricEntry {
  const GeneratedRubricEntry({
    required this.step,
    required this.kind,
    required this.points,
    this.keys = const [],
    this.antiKeys = const [],
    this.expect = const [],
  });

  final String step;
  final String kind;
  final double points;
  final List<String> keys;
  final List<String> antiKeys;
  final List<String> expect;

  factory GeneratedRubricEntry.fromJson(Map<String, dynamic> j) =>
      GeneratedRubricEntry(
        step: j['step'] as String? ?? '',
        kind: j['kind'] as String? ?? 'relation',
        points: (j['points'] as num? ?? 0).toDouble(),
        keys: (j['keys'] as List<dynamic>? ?? const []).cast<String>(),
        antiKeys: (j['antiKeys'] as List<dynamic>? ?? const []).cast<String>(),
        expect: (j['expect'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

/// متابعة الخطأ: القيمة المقبولة في هذا الجزء = `scale × (جواب الطالب في
/// `dependsOn`) ^ power`. يبنيها المولّد من المفتاحين ويثبتها آلياً.
class GeneratedFollow {
  const GeneratedFollow({
    required this.dependsOn,
    required this.power,
    required this.scale,
    required this.tolerance,
    this.note,
  });

  final String dependsOn;
  final double power;
  final double scale;
  final double tolerance;
  final String? note;

  factory GeneratedFollow.fromJson(Map<String, dynamic> j) => GeneratedFollow(
        dependsOn: '${j['dependsOn']}',
        power: (j['power'] as num).toDouble(),
        scale: (j['scale'] as num).toDouble(),
        tolerance: (j['tolerance'] as num? ?? 0.02).toDouble(),
        note: j['note'] as String?,
      );
}

/// جزء من مسألة: مطلوب + مفتاح + سلّم + (اختيارياً) أربعة خيارات + متابعات.
class GeneratedPart {
  const GeneratedPart({
    required this.n,
    required this.label,
    required this.prompt,
    required this.weight,
    required this.options,
    required this.correctIndex,
    required this.optionValues,
    required this.solutionSteps,
    required this.rubric,
    required this.answerText,
    required this.answerValue,
    required this.answerUnit,
    required this.unitRequired,
    required this.tolerance,
    required this.follow,
  });

  final int n;
  final String label;
  final String prompt;
  final double weight;
  final List<String> options;
  final int correctIndex;
  final List<double?> optionValues;
  final List<String> solutionSteps;
  final List<GeneratedRubricEntry> rubric;
  final String answerText;
  final double? answerValue;
  final String answerUnit;
  final bool unitRequired;
  final double tolerance;
  final List<GeneratedFollow> follow;

  /// مجموع درجات مجموعة أسطر من نمط واحد (relation/substitution/result/unit).
  double groupPoints(String kind) => rubric
      .where((e) => e.kind == kind)
      .fold<double>(0, (s, e) => s + e.points);

  List<String> groupKeys(String kind) => [
        for (final e in rubric)
          if (e.kind == kind) ...e.keys,
      ];

  List<String> groupAntiKeys(String kind) => [
        for (final e in rubric)
          if (e.kind == kind) ...e.antiKeys,
      ];

  List<String> groupExpect(String kind) => [
        for (final e in rubric)
          if (e.kind == kind) ...e.expect,
      ];

  bool get hasOptions => options.length == 4;

  factory GeneratedPart.fromJson(Map<String, dynamic> j,
      {List<GeneratedFollow> follows = const []}) {
    final a = j['answer'] as Map<String, dynamic>?;
    return GeneratedPart(
      n: (j['n'] as num? ?? 0).toInt(),
      label: '${j['label']}',
      prompt: j['prompt'] as String? ?? '',
      weight: (j['weight'] as num? ?? 0).toDouble(),
      options: (j['options'] as List<dynamic>? ?? const []).cast<String>(),
      correctIndex: (j['correctIndex'] as num? ?? -1).toInt(),
      optionValues: (j['optionValues'] as List<dynamic>? ?? const [])
          .map<double?>((v) => v is num ? v.toDouble() : null)
          .toList(growable: false),
      solutionSteps: _cleanSteps(j['solutionSteps'] as List<dynamic>?),
      rubric: (j['rubric'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(GeneratedRubricEntry.fromJson)
          .toList(growable: false),
      answerText: a?['text'] as String? ?? '',
      answerValue: (a?['value'] as num?)?.toDouble(),
      answerUnit: a?['unit'] as String? ?? '',
      unitRequired: a?['unitRequired'] as bool? ?? true,
      tolerance: (a?['tolerance'] as num? ?? 0.02).toDouble(),
      follow: follows,
    );
  }
}

/// يقرأ الأجزاء ويلصق بها `followThrough` — وهو على مستوى البند لا الجزء:
/// قائمة `{'part': الوسم, 'accept': [{'dependsOn', 'power', 'scale', …}]}`.
List<GeneratedPart> _readParts(Map<String, dynamic> j) {
  // البنود المسطّحة تحمل `followThrough: []` و`rubric` قديمًا — لا تُقرأ هنا
  // إطلاقاً: بوابة الأجزاء هي `grading` وحدها.
  if (j['grading'] != partsGradingKey) return const [];
  final follows = <String, List<GeneratedFollow>>{};
  for (final e in (j['followThrough'] as List<dynamic>? ?? const [])) {
    final m = e as Map<String, dynamic>;
    final accept = (m['accept'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(GeneratedFollow.fromJson)
        .toList(growable: false);
    follows['${m['part']}'] = accept;
  }
  return (j['parts'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map((q) => GeneratedPart.fromJson(q,
          follows: follows['${q['label']}'] ?? const []))
      .toList(growable: false);
}

/// حزمة البنود المولّدة + بياناتها الوصفية.
class GeneratedItemsPack {
  const GeneratedItemsPack({required this.items, required this.meta});

  final List<GeneratedItem> items;
  final Map<String, dynamic> meta;

  static const String defaultAssetPath = 'assets/content/items.json';

  factory GeneratedItemsPack.fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final list = (j['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(GeneratedItem.fromJson)
        .toList(growable: false);
    return GeneratedItemsPack(
      items: list,
      meta: (j['meta'] as Map<String, dynamic>?) ?? const {},
    );
  }

  static Future<GeneratedItemsPack> loadAsset(
      [String path = defaultAssetPath]) async {
    final raw = await rootBundle.loadString(path);
    return GeneratedItemsPack.fromJsonString(raw);
  }

  /// ما يُعرض للطالب: المعتمد فقط.
  List<GeneratedItem> get visible =>
      items.where((i) => i.approved).toList(growable: false);
}

/// أسماء فصول المنهاج الوزاري السبعة عشر (U1C1…U5C1) — تُشارَك بين
/// شاشة الجلسة وشاشة المراجعة؛ المعرّف الخام يعود كما هو إن لم يُعرف.
const Map<String, String> chapterTitles = {
  'U1C1': 'النواس المرن',
  'U1C2': 'نواس الفتل',
  'U1C3': 'النواس الثقلي',
  'U1C4': 'ميكانيك الموائع',
  'U1C5': 'النسبية الخاصة',
  'U2C1': 'المغناطيسية',
  'U2C2': 'القوة المغناطيسية والكهرطيسية',
  'U2C3': 'التحريض الكهرطيسي',
  'U2C4': 'الدارة المهتزة',
  'U2C5': 'التيار المتناوب',
  'U2C6': 'المحوّلات',
  'U3C1': 'الأمواج المستقرة على الأوتار',
  'U3C2': 'الأمواج الصوتية والمزامير',
  'U4C1': 'نموذج بور',
  'U4C2': 'الأشعة المهبطية',
  'U4C3': 'الكهرضوئي والأشعة السينية',
  'U5C1': 'الفلك والكون',
};

String chapterTitleOf(String chapter) => chapterTitles[chapter] ?? chapter;
