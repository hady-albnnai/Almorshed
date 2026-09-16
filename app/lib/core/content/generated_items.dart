/// المادة ١٢ — بنود المولّد (tools/gen_items.py) كما تصل للتطبيق.
///
/// المصدر: `assets/content/items_u1.json` (نسخة من
/// `content/generated/U1.sample100.json`). كل بند `approved:false` حتى يعتمده
/// الأستاذ — الفلتر نفسه المعتمد في F2.4: الوضع العادي يعرض المعتمد فقط،
/// ووضع المراجعة يفتح الكل بشارة «قيد المراجعة».
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
      (raw['steps'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

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
        solutionSteps:
            (j['solutionSteps'] as List<dynamic>? ?? const []).cast<String>(),
        weight: (j['weight'] as num? ?? 10).toDouble(),
        raw: j,
      );
}

/// حزمة البنود المولّدة + بياناتها الوصفية.
class GeneratedItemsPack {
  const GeneratedItemsPack({required this.items, required this.meta});

  final List<GeneratedItem> items;
  final Map<String, dynamic> meta;

  static const String defaultAssetPath = 'assets/content/items_u1.json';

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

  /// ما يُعرض للطالب: المعتمد فقط، أو الكل في وضع المراجعة (F2.4).
  List<GeneratedItem> visible({required bool reviewMode}) => reviewMode
      ? items
      : items.where((i) => i.approved).toList(growable: false);
}
