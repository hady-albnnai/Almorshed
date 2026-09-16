// ═══════════════════════════════════════════════════════════════════════
// review_mode.dart — F2.4 + وضع المراجعة (قرار المالك 2026-09-14).
//
// وجهان لعملة واحدة:
//  • F2.4 «تجميد المعدَّل»: في الوضع العادي، أي بند approved=false لا يصل
//    للطالب — الفلاتر القائمة (approvedQuestions/duel bank/batch builder)
//    تعتمد على العلم نفسه، فلا حاجة لفلترة إضافية.
//  • وضع المراجعة (جهاز الأستاذ فقط — يفعّله المالك من لوحة الإدارة المخفية):
//    نرفع علم approved لكل الأسئلة داخل الحزمة المحمّلة ⇒ كل الفلاتر تنفتح
//    آلياً ويرى الأستاذ المحتوى كله بسياقه الحقيقي مع شارة «قيد المراجعة».
//
// ما لا يفعله وضع المراجعة: لا يلمس pack.json، لا يزامن XP (مانع في
// SyncManager)، لا يكتب شيئاً للسيرفر — كله محلي + واتساب (قرار ١٨/١٩).
// ═══════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../content/models.dart';

/// علم وضع المراجعة — يعيش على الجهاز فقط.
class ReviewModeStore {
  static const _key = 'review_mode_v1';

  Future<bool> isEnabled() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool on) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, on);
  }
}

/// تحويل الحزمة لوضع المراجعة: كل سؤال يُعتبر معتمداً **للعرض فقط**.
/// الأصل لا يُمسّ — نبني نسخة. (البطاقات والفقرات لا علم لها — ظاهرة أصلاً.)
ContentPack openAllForReview(ContentPack pack) => ContentPack(
  packId: pack.packId,
  year: pack.year,
  edition: pack.edition,
  units: pack.units,
  questions: [
    for (final q in pack.questions)
      Question(
        id: q.id,
        unit: q.unit,
        chapter: q.chapter,
        approved: true,
        stem: q.stem,
        options: q.options,
        correctIndex: q.correctIndex,
        solutionSteps: q.solutionSteps,
        followThrough: q.followThrough,
      ),
  ],
  cards: pack.cards,
);

/// معرّفات الأسئلة غير المعتمدة أصلاً — لعرض شارة «قيد المراجعة» في الوضع.
Set<int> unapprovedQuestionIds(ContentPack original) => {
  for (final q in original.questions)
    if (!q.approved) q.id,
};

// ── دفتر ملاحظات الأستاذ ──

enum ReviewVerdict { ok, edit, remove }

extension ReviewVerdictAr on ReviewVerdict {
  String get ar => switch (this) {
    ReviewVerdict.ok => 'صحيح',
    ReviewVerdict.edit => 'يحتاج تعديل',
    ReviewVerdict.remove => 'احذفه',
  };
  String get emoji => switch (this) {
    ReviewVerdict.ok => '✅',
    ReviewVerdict.edit => '✏️',
    ReviewVerdict.remove => '❌',
  };
}

/// ملاحظة على بند واحد — المفتاح: نوع + معرّف
/// (س101 · ب14 · ف U1C1P3 · بند20001 للبنود المولّدة — المادة ١٣).
class ReviewNote {
  const ReviewNote({
    required this.kind, // q | c | p | g
    required this.itemId,
    required this.verdict,
    this.text = '',
    required this.updatedMs,
  });

  final String kind;
  final String itemId;
  final ReviewVerdict verdict;
  final String text;
  final int updatedMs;

  String get key => '$kind:$itemId';

  /// تسمية عربية قصيرة للبند.
  String get label => switch (kind) {
    'q' => 'س$itemId',
    'c' => 'ب$itemId',
    'g' => 'بند$itemId',
    _ => 'ف $itemId',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'k': kind,
    'i': itemId,
    'v': verdict.name,
    't': text,
    'u': updatedMs,
  };

  static ReviewNote fromJson(Map<String, dynamic> j) => ReviewNote(
    kind: j['k'] as String? ?? 'q',
    itemId: j['i'].toString(),
    verdict: ReviewVerdict.values.firstWhere(
      (v) => v.name == j['v'],
      orElse: () => ReviewVerdict.edit,
    ),
    text: j['t'] as String? ?? '',
    updatedMs: (j['u'] as num?)?.toInt() ?? 0,
  );
}

/// مخزن الملاحظات — حفظ تلقائي فوري، استئناف من أي مكان (قرار ١٩).
class ReviewNotesStore {
  static const _key = 'review_notes_v1';

  Future<Map<String, ReviewNote>> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <String, ReviewNote>{};
      for (final e in list) {
        final n = ReviewNote.fromJson(e as Map<String, dynamic>);
        out[n.key] = n;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> put(ReviewNote note) async {
    final all = await load();
    all[note.key] = note;
    await _save(all);
  }

  Future<void> remove(String key) async {
    final all = await load();
    all.remove(key);
    await _save(all);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }

  Future<void> _save(Map<String, ReviewNote> all) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode([for (final n in all.values) n.toJson()]),
    );
  }
}

/// رسالة واتساب مرتّبة من الملاحظات — نصّ خالص (قرار ١٩).
String formatReviewReport(
  Iterable<ReviewNote> notes, {
  required DateTime now,
  String reviewer = 'الأستاذ فداء',
}) {
  final sorted = notes.toList()..sort((a, b) => a.key.compareTo(b.key));
  final ok = sorted.where((n) => n.verdict == ReviewVerdict.ok).toList();
  final edit = sorted.where((n) => n.verdict == ReviewVerdict.edit).toList();
  final rm = sorted.where((n) => n.verdict == ReviewVerdict.remove).toList();
  final d =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  final b = StringBuffer()
    ..writeln('مراجعة $reviewer — $d')
    ..writeln('المجموع: ${sorted.length} بند');
  if (ok.isNotEmpty) {
    b.writeln('✅ صحيح (${ok.length}): ${ok.map((n) => n.label).join('، ')}');
  }
  if (edit.isNotEmpty) {
    b.writeln('✏️ يحتاج تعديل (${edit.length}):');
    for (final n in edit) {
      b.writeln('• ${n.label}: ${n.text.isEmpty ? '(بلا تفصيل)' : n.text}');
    }
  }
  if (rm.isNotEmpty) {
    b.writeln('❌ حذف (${rm.length}):');
    for (final n in rm) {
      b.writeln('• ${n.label}${n.text.isEmpty ? '' : ': ${n.text}'}');
    }
  }
  return b.toString().trimRight();
}
