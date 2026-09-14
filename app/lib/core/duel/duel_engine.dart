// ═══════════════════════════════════════════════════════════════════════
// duel_engine.dart — جوهر المبارزة الحتمي (M5 / docs/12 §٢ + العقد §٦).
// نفس البذرة على الجهازين وعلى السيرفر ⇒ نفس الأسئلة وترتيب الخيارات؛
// الحسم: نقاط (١٠٠×مضاعف المتتالية) ← عدد الصحيحات ← عملة streamC.
// ⚠️ scopeTag ب13 بت (لا 14): bigint بpostgres موقّع ⇒ البذرة < 2^63 —
// قرار تقني موثق بالعقد §٦.٠.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../content/models.dart';
import '../rng/session.dart';
import '../rng/splitmix64.dart';

/// ثوابت المبارزة — مطابقة لـ duel_finish (العقد §٦.٢).
abstract final class DuelConstants {
  static const int questionSeconds = 20; // مهلة السؤال الواحد
  static const int count = 10; // عدد أسئلة المبارزة
  static const String mode = 'quiz';
  static const int pointsPerCorrect = 100;
  static const int defaultQuestionMs = questionSeconds * 1000;
}

/// نطاق المبارزة — يُرمَّز داخل scopeTag بالبذرة ويثبت البنك للطرفين.
class DuelScope {
  const DuelScope({
    required this.units,
    required this.packTag,
    this.count = DuelConstants.count,
    this.mode = DuelConstants.mode,
  });

  final List<String> units; // مثل [U1..U5]
  final String packTag; // مثل syria-2027-v1-1
  final int count;
  final String mode;

  /// النص القياسي — مطابق حرفياً لـ scopeString بـTS (العقد §٦.٠).
  /// ⚠️ بلا cascade-على-انتشار وبلا اقتباسات متداخلة داخل الاستقراء —
  /// ذلك النمط يُسقط محلّل Flutter (درس جولة M5 المثبت بالتنصيف D2/D3/D4).
  String get scopeString {
    final sorted = List<String>.of(units);
    sorted.sort();
    final joined = sorted.join(',');
    return 'duel-v1|$joined'
        '|count=$count|mode=$mode|pack=$packTag';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'units': units,
        'count': count,
        'mode': mode,
        'pack': packTag,
      };

  static DuelScope fromJson(Map<String, dynamic> json) => DuelScope(
        units: (json['units'] as List<dynamic>).cast<String>(),
        packTag: json['pack'] as String,
        count: json['count'] as int,
        mode: json['mode'] as String,
      );
}

/// تاج النطاق: أول 13 بت من sha256(نص النطاق) — مطابق لـTS حرفياً.
int scopeTagOf(DuelScope scope) {
  final digest = sha256.convert(utf8.encode(scope.scopeString)).bytes;
  return ((digest[0] << 8) | digest[1]) & 0x1FFF;
}

/// البذرة الكاملة = (تاج<<50) | رمز الغرفة — دائماً < 2^63 (تصريف موجب).
int makeSeed({required int tag, required int roomCode}) =>
    ((tag & 0x1FFF) << 50) | (roomCode & 0x3FFFFFFFFFFFF);

/// Crockford Base32 — docs/12 §٢.١ (بلا I L O U؛ التطبيع يقبل أخطاءها).
abstract final class RoomCode {
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// ترميز 50 بت ⇒ ١٠ محارف بمسرة بعد الخامسة: K7M2P-9QW4X.
  static String encode(int value) {
    var v = value & 0x3FFFFFFFFFFFF;
    final chars = List<String>.generate(10, (i) {
      // من الأعلى للأسفل: الخانة i تحمل 5*(9-i) بت
      return alphabet[(v >> (5 * (9 - i))) & 31];
    });
    return '${chars.sublist(0, 5).join()}-${chars.sublist(5).join()}';
  }

  /// فك الرمز — يقبل الصغر/الخلط بمسرة وخدع I→1 وO→0 وL→1.
  static int decode(String code) {
    final norm = code.toUpperCase().replaceAll('-', '').replaceAllMapped(
          RegExp('[OIL]'),
          (m) => m.group(0) == 'O' ? '0' : '1',
        );
    if (norm.length != 10) throw const FormatException('ROOM_CODE_LEN');
    var v = 0;
    for (final ch in norm.runes) {
      final idx = alphabet.indexOf(String.fromCharCode(ch));
      if (idx < 0) throw const FormatException('ROOM_CODE_CHAR');
      v = (v << 5) | idx;
    }
    return v;
  }
}

/// جلسة مبارزة مبنية: الترتيب + فهرس الصحيح المعروض لكل سؤال.
class DuelSession {
  const DuelSession({required this.built, required this.correctDisplay});

  final BuiltSession built;

  /// فهرس الإجابة الصحيحة بالعرض (بعد خلط الخيارات) لكل موضع بالترتيب.
  final List<int> correctDisplay;

  int get length => built.questionIds.length;

  List<int> optionOrderAt(int index) =>
      built.optionOrders[built.questionIds[index]]!;
}

/// بناء جلسة المبارزة من الحزمة — بنك المعتمد حصراً (قرار ٢٤)، فهرس
/// الفصول بترتيب وحدات الحزمة (مطابق batch_builder — العقد §٦.١).
DuelSession buildDuelSession(
  ContentPack pack, {
  required int seed,
  required DuelScope scope,
}) {
  final approved = [
    for (final q in pack.questions)
      if (q.approved && scope.units.contains(q.unit)) q,
  ];
  if (approved.length < scope.count) {
    throw const FormatException('DUEL_BANK_SMALL');
  }
  final chapterIndex = <String, int>{};
  for (final u in pack.units) {
    for (final c in u.chapters) {
      chapterIndex.putIfAbsent(c.id, () => chapterIndex.length);
    }
  }
  final chapterOf = <int, int>{};
  final optionsOf = <int, List<int>>{};
  for (final q in approved) {
    chapterOf[q.id] = chapterIndex[q.chapter] ?? 0;
    optionsOf[q.id] = List<int>.generate(q.options.length, (i) => i);
  }
  final built = buildSession(SessionSpec(
    seed: seed,
    count: scope.count,
    bankIds: approved.map((q) => q.id).toList(),
    chapterOf: chapterOf,
    optionsOf: optionsOf,
  ));
  final correctDisplay = <int>[];
  final byId = {for (final q in approved) q.id: q};
  for (final qid in built.questionIds) {
    final order = built.optionOrders[qid]!;
    correctDisplay.add(order.indexOf(byId[qid]!.correctIndex));
  }
  return DuelSession(built: built, correctDisplay: correctDisplay);
}

/// نتيجة طرف واحد بتصحيح الخادم/العميل المتطابق.
class DuelSideResult {
  const DuelSideResult({required this.score, required this.corrects});

  final int score;
  final int corrects;
}

/// تصحيح إجابات طرف: إجابات بترتيب الجلسة (null = بلا إجابة/مهلة).
/// المضاعف: ٣ صحيحة متتالية ⇒ ×٢، ٦ ⇒ ×٣ — أثناء المبارزة فقط (docs/12 §٤.١).
DuelSideResult gradeDuelSide(
  DuelSession session,
  List<int?> chosenByIndex,
) {
  var score = 0;
  var corrects = 0;
  var streak = 0;
  for (var i = 0; i < session.length; i++) {
    final chosen = chosenByIndex[i];
    if (chosen != null && chosen == session.correctDisplay[i]) {
      streak++;
      corrects++;
      final mult = streak >= 6 ? 3 : (streak >= 3 ? 2 : 1);
      score += DuelConstants.pointsPerCorrect * mult;
    } else {
      streak = 0;
    }
  }
  return DuelSideResult(score: score, corrects: corrects);
}

/// الحسم النهائي: نقاط ← صحيحات ← عملة streamC (تعريف العملة مطابق
/// للخادم: أول قيمة من SplitMix64(seed ⊕ 0xC0FFEE)؛ زوجي ⇒ المضيف).
bool hostWinsTieCoin({required int seed}) =>
    SplitMix64(SessionStreams.streamC(seed)).next() % 2 == 0;

/// من فاز؟ يعيد true للمضيف (الحسم ثلاثي السلم — العقد §٦.٣).
bool hostWins({
  required DuelSideResult host,
  required DuelSideResult guest,
  required int seed,
}) {
  if (host.score != guest.score) return host.score > guest.score;
  if (host.corrects != guest.corrects) return host.corrects > guest.corrects;
  return hostWinsTieCoin(seed: seed);
}

/// بصمة أسئلة الجلسة — ٨ محارف hex من sha256(قائمة الأسئلة+ترتيب خياراتها).
/// تُعرض على الجهازين للتثبت البصري أن نفس البذرة ⇒ نفس الأسئلة (F5.5) —
/// بلا سيرفر ولا شبكة.
String questionsFingerprint(
  List<int> questionIds,
  Map<int, List<int>> optionOrders,
) {
  final b = StringBuffer();
  for (final qid in questionIds) {
    b.write(qid);
    b.write(':');
    b.write(optionOrders[qid]?.join(',') ?? '');
    b.write(';');
  }
  final digest = sha256.convert(utf8.encode(b.toString())).bytes;
  return digest
      .take(4)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}
