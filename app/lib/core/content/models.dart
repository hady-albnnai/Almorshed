import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'term_linter.dart' show ContentPackLike;

/// نماذج حزمة المحتوى — F2.1 (قرارات ١، ٢، ١٤، ١٥: بنية موسومة بـ«سنة+طبعة»،
/// خمس وحدات، رموز حرفية، ألفاظ مُدرَّجة). JSON فقط — يُحمَّل من assets في F2.2.
///
/// بنية الحزمة (schema):
/// ```json
/// {
///   "packId": "syria-2027-v1",
///   "year": 2027, "edition": 1,
///   "units": [{
///     "id": "U1", "title": "الوحدة الأولى: الحركة والتحريك",
///     "chapters": [{
///       "id": "U1C1", "title": "الفصل 1: ...", "page": 6,
///       "paragraphs": [{
///         "id": "U1C1P1", "text": "...", "summary": "📌 خلاصة الفقرة",
///         "experimentId": null
///       }]
///     }]
///   }],
///   "questions": [{
///     "id": 101, "unit": "U1", "chapter": "U1C1", "approved": true,
///     "stem": "نص السؤال", "options": ["أ", "ب", "ج", "د"],
///     "correctIndex": 0, "solutionSteps": [".."], "followThrough": [".."]
///   }],
///   "cards": [{
///     "id": 901, "unit": "U1", "chapter": "U1C1",
///     "front": "سؤال البطاقة", "back": "الجواب", "formula": "T = 2π√(m/k)"
///   }]
/// }
/// ```
@immutable
class ContentPack implements ContentPackLike {
  const ContentPack({
    required this.packId,
    required this.year,
    required this.edition,
    required this.units,
    required this.questions,
    required this.cards,
  });

  final String packId;
  final int year;
  final int edition;
  final List<Unit> units;
  final List<Question> questions;
  final List<CardItem> cards;

  /// فك الحزمة — يرمي FormatException عند أي خلل بنيوي (يفضل الفشل المبكر).
  factory ContentPack.fromJson(Map<String, dynamic> json) {
    final units = (json['units'] as List<dynamic>)
        .map((u) => Unit.fromJson(u as Map<String, dynamic>))
        .toList(growable: false);
    final questions = (json['questions'] as List<dynamic>? ?? const [])
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList(growable: false);
    final cards = (json['cards'] as List<dynamic>? ?? const [])
        .map((c) => CardItem.fromJson(c as Map<String, dynamic>))
        .toList(growable: false);
    return ContentPack(
      packId: json['packId'] as String,
      year: json['year'] as int,
      edition: json['edition'] as int,
      units: units,
      questions: questions,
      cards: cards,
    );
  }

  factory ContentPack.fromJsonString(String raw) =>
      ContentPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// الأسئلة المعتمدة حصراً (قرار ٢٤ — الفلترة هنا قبل أي جلسة).
  List<Question> get approvedQuestions =>
      questions.where((q) => q.approved).toList(growable: false);

  // ── ContentPackLike: مناظير النصوص لفحص TermLinter ──
  @override
  Iterable<MapEntry<String, Iterable<String>>> get unitTexts sync* {
    for (final u in units) {
      final texts = <String>[u.title];
      for (final c in u.chapters) {
        texts.add(c.title);
        for (final p in c.paragraphs) {
          texts.add(p.text);
          texts.add(p.summary);
        }
      }
      yield MapEntry(u.id, texts);
    }
  }

  @override
  Iterable<MapEntry<String, Iterable<String>>> get questionTexts sync* {
    for (final q in questions) {
      yield MapEntry('Q${q.id}', [q.stem, ...q.options, ...q.solutionSteps]);
    }
  }

  @override
  Iterable<MapEntry<String, Iterable<String>>> get cardTexts sync* {
    for (final c in cards) {
      yield MapEntry('C${c.id}', [c.front, c.back, if (c.formula != null) c.formula!]);
    }
  }
}

@immutable
class Unit {
  const Unit({required this.id, required this.title, required this.chapters});

  final String id;
  final String title;
  final List<Chapter> chapters;

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id'] as String,
        title: json['title'] as String,
        chapters: (json['chapters'] as List<dynamic>)
            .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
            .toList(growable: false),
      );
}

@immutable
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.page,
    required this.paragraphs,
  });

  final String id;
  final String title;
  final int page;
  final List<Paragraph> paragraphs;

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as String,
        title: json['title'] as String,
        page: json['page'] as int,
        paragraphs: (json['paragraphs'] as List<dynamic>? ?? const [])
            .map((p) => Paragraph.fromJson(p as Map<String, dynamic>))
            .toList(growable: false),
      );
}

@immutable
class Paragraph {
  const Paragraph({
    required this.id,
    required this.text,
    required this.summary,
    this.experimentId,
  });

  final String id;
  final String text;

  /// «📌 خلاصة الفقرة» — قرار نمط القراءة (فقرة لكل شاشة).
  final String summary;

  /// التجربة داخل الدرس بموقعها (قرار ٣٧) — إن وُجدت.
  final String? experimentId;

  factory Paragraph.fromJson(Map<String, dynamic> json) => Paragraph(
        id: json['id'] as String,
        text: json['text'] as String,
        summary: json['summary'] as String,
        experimentId: json['experimentId'] as String?,
      );
}

@immutable
class Question {
  const Question({
    required this.id,
    required this.unit,
    required this.chapter,
    required this.approved,
    required this.stem,
    required this.options,
    required this.correctIndex,
    required this.solutionSteps,
    required this.followThrough,
  });

  final int id;
  final String unit;
  final String chapter;

  /// false ⇒ محجوب من التدريب والمبارزات (قرار ٢٤ + F2.4 التجميد).
  final bool approved;
  final String stem;
  final List<String> options;
  final int correctIndex;

  /// سلم التصحيح (قرار ١٠).
  final List<String> solutionSteps;
  final List<String> followThrough;

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as int,
        unit: json['unit'] as String,
        chapter: json['chapter'] as String,
        approved: json['approved'] as bool? ?? false,
        stem: json['stem'] as String,
        options: (json['options'] as List<dynamic>).cast<String>(),
        correctIndex: json['correctIndex'] as int,
        solutionSteps:
            (json['solutionSteps'] as List<dynamic>? ?? const []).cast<String>(),
        followThrough:
            (json['followThrough'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

@immutable
class CardItem {
  const CardItem({
    required this.id,
    required this.unit,
    required this.chapter,
    required this.front,
    required this.back,
    this.formula,
  });

  final int id;
  final String unit;
  final String chapter;
  final String front;
  final String back;

  /// القانون بخط ذهبي على وجه الجواب (قرار ٤٢).
  final String? formula;

  factory CardItem.fromJson(Map<String, dynamic> json) => CardItem(
        id: json['id'] as int,
        unit: json['unit'] as String,
        chapter: json['chapter'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
        formula: json['formula'] as String?,
      );
}
