import 'splitmix64.dart';

/// محرك بناء الجلسة الحتمي — docs/12 §٢.٣.
/// نفس البذرة + نفس البنك ⇒ نفس الأسئلة ونفس ترتيب الخيارات على كل الأجهزة.
///
/// الوحدة هنا تعمل على معرفات فقط (M2 يوصلها ببنك الأسئلة الحقيقي).

/// نتيجة بناء جلسة: ترتيب أسئلة + ترتيب خيارات كل سؤال.
class BuiltSession {
  const BuiltSession({required this.questionIds, required this.optionOrders});

  /// معرفات الأسئلة بالترتيب النهائي (طولها = count).
  final List<int> questionIds;

  /// لكل معرف سؤال: ترتيب معرفات خياراته (الأول = الاختيار A المعروض).
  final Map<int, List<int>> optionOrders;
}

/// مواصفة جلسة: البذرة، العدد، البنك المتاح، فصلُ كل سؤال، وخيارات كل سؤال.
class SessionSpec {
  SessionSpec({
    required this.seed,
    required this.count,
    required this.bankIds,
    required this.chapterOf,
    required this.optionsOf,
  })  : assert(count > 0, 'count يجب أن يكون موجباً'),
        assert(bankIds.length >= count, 'البنك أصغر من العدد المطلوب');

  /// بذرة 64 بت (قرار ٢٢ / docs/12 §٢.١).
  final int seed;
  final int count;

  /// معرفات الأسئلة المعتمدة المتاحة (قرار ٢٤: المعتمد حصراً — الفلترة قبل هنا).
  final List<int> bankIds;

  /// معرف السؤال ← معرف الفصل (للتوازن round-robin).
  final Map<int, int> chapterOf;

  /// معرف السؤال ← معرفات خياراته (بترتيبها الأصلي؛ الخلط يحدث هنا حتماً).
  final Map<int, List<int>> optionsOf;
}

/// التيارات المستقلة — docs/12 §٢.٢ (تفادي الارتباط بين التيارات).
abstract final class SessionStreams {
  /// ثوابت تعليمية منفصلة جذرها مختلف (نمط stream-tagging).
  static int streamA(int seed) => seed ^ 0xA11CE; // ترتيب الأسئلة
  static int streamB(int seed) => seed ^ 0xB0B; // احتياطي (خلط عناصر أخرى)
  static int streamC(int seed) => seed ^ 0xC0FFEE; // كسر التعادل
}

/// Fisher–Yates حتمي بمولّد معطى — يُعدّل القائمة بالعادة ويُعيدها.
/// (docs/12 §٢.٣: مسموح وحده — بدون انحياز، O(n)).
List<int> fisherYates(List<int> input, SplitMix64 rng) {
  final list = List<int>.of(input);
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.next() % (i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}

/// بناء الجلسة الكاملة — القرار ٢٢ + docs/12 §٢.٣ خطوة بخطوة.
BuiltSession buildSession(SessionSpec spec) {
  // ٣) خلط البنك بتيار A
  final shuffled =
      fisherYates(spec.bankIds, SplitMix64(SessionStreams.streamA(spec.seed)));

  // ٤) توازن الفصول round-robin: مجموعات مسبقة الترتيب لكل فصل، سحب بالدور.
  final byChapter = <int, List<int>>{};
  for (final id in shuffled) {
    byChapter.putIfAbsent(spec.chapterOf[id] ?? 0, () => <int>[]).add(id);
  }
  final chapters = byChapter.keys.toList()..sort(); // ترتيب حتمي بالمعرف
  final cursors = <int, int>{for (final c in chapters) c: 0};
  final chosen = <int>[];
  var guard = 0;
  while (chosen.length < spec.count && guard <= spec.bankIds.length) {
    var progressed = false;
    for (final c in chapters) {
      if (chosen.length == spec.count) break;
      final pool = byChapter[c]!;
      final i = cursors[c]!;
      if (i < pool.length) {
        chosen.add(pool[i]);
        cursors[c] = i + 1;
        progressed = true;
      }
    }
    if (!progressed) break; // استُهلك البنك كله
    guard++;
  }

  // ٥) خلط الخيارات: بذرة مشتقة حتماً لكل سؤال — mix64(seed ⊕ q.id)
  final optionOrders = <int, List<int>>{};
  for (final id in chosen) {
    final opts = spec.optionsOf[id];
    if (opts == null) continue; // سؤال بلا خيارات (مستقبلاً: إدخالي)
    final optSeed = SplitMix64.mix64(spec.seed ^ id);
    optionOrders[id] =
        fisherYates(opts, SplitMix64(optSeed));
  }

  return BuiltSession(questionIds: chosen, optionOrders: optionOrders);
}
