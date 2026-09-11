/// TermLinter — حارس قرار ١٤ («الرموز تطابق الكتاب حرفياً») وقرار ١٥
/// (ألفاظ رسمي/SYN/BAN) — يعمل على كل نص حزمة المحتوى قبل اعتمادها (F2.4).
///
/// القاموس يُحقن من حزمة المحتوى (توليده من glossary/terms_data.py بمحول
/// tools — لا يُكتب يدوياً أبداً).
library;

import 'package:flutter/foundation.dart';


abstract final class TermLinter {
  /// يفحص نصاً ويعيد قائمة الانتهاكات (فارغة = سليم).
  ///
  /// - أي ظرف من [banned] ظهر نصياً ⇒ انتهاك BAN فوري.
  /// - أي مرادف من [synonyms] ظهر ⇒ تحذير SYN (مسموح لكن يُوحَّد للرسمي
  ///   في المراجعة — قرار ١٥).
  static List<LintIssue> lint(
    String text, {
    required Set<String> banned,
    required Map<String, String> synonyms,
  }) {
    final issues = <LintIssue>[];
    for (final word in banned) {
      if (word.isEmpty) continue;
      if (text.contains(word)) {
        issues.add(LintIssue(kind: LintKind.ban, matched: word));
      }
    }
    synonyms.forEach((syn, official) {
      if (syn.isNotEmpty && text.contains(syn)) {
        issues.add(LintIssue(kind: LintKind.syn, matched: syn, official: official));
      }
    });
    return issues;
  }

  /// فحص حزمة كاملة (أسئلة + بطاقات + فقرات) — يعيد خريطة معرف العنصر ← انتهاكاته.
  static Map<String, List<LintIssue>> lintPack(
    ContentPackLike pack, {
    required Set<String> banned,
    required Map<String, String> synonyms,
  }) {
    final result = <String, List<LintIssue>>{};
    void check(String key, Iterable<String> texts) {
      for (final t in texts) {
        final found = lint(t, banned: banned, synonyms: synonyms);
        if (found.isNotEmpty) {
          result.putIfAbsent(key, () => <LintIssue>[]).addAll(found);
        }
      }
    }

    for (final u in pack.unitTexts) {
      check(u.key, u.value);
    }
    for (final q in pack.questionTexts) {
      check(q.key, q.value);
    }
    for (final c in pack.cardTexts) {
      check(c.key, c.value);
    }
    return result;
  }
}

enum LintKind { ban, syn }

@immutable
class LintIssue {
  const LintIssue({required this.kind, required this.matched, this.official});

  final LintKind kind;
  final String matched;

  /// الرسمي المقابل للمرادف (للـSYN فقط).
  final String? official;

  @override
  String toString() => kind == LintKind.ban
      ? 'BAN: «$matched» ممنوع حصراً'
      : 'SYN: «$matched» ← استخدم الرسمي «$official»';
}

/// واجهة خفيفة تفرّق الحزمة عن التبعية الدائرية (models تنفذها).
abstract interface class ContentPackLike {
  Iterable<MapEntry<String, Iterable<String>>> get unitTexts;
  Iterable<MapEntry<String, Iterable<String>>> get questionTexts;
  Iterable<MapEntry<String, Iterable<String>>> get cardTexts;
}
