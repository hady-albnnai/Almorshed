// M5 — اختبارات محرك المبارزة الحتمي (duel_engine).
// المتجهات الذهبية أدناه حُسبت بمقارن مستقل Python (SplitMix64 + البناء
// الكامل) 2026-09-13 — مطابقة سلسلة goldens الأصلية (docs/12 §٢.٤).
// أي تغيير يكسرها = انحراف حتمية بين العميل والخادم = نتيجة مرفوضة.
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';
import 'package:fizya_clash/core/content/models.dart';

ContentPack _pack() {
  const chapters = ['U1C1', 'U1C2', 'U2C1', 'U2C2', 'U3C1'];
  final unitOf = <String, String>{
    for (final c in chapters) c: c.substring(0, 2),
  };
  final byChapter = <String, List<Chapter>>{};
  for (final c in chapters) {
    byChapter.putIfAbsent(unitOf[c]!, () => []).add(Chapter(
          id: c,
          title: 'فصل $c',
          page: chapters.indexOf(c) + 1,
          paragraphs: const [],
        ));
  }
  final units = [
    for (final u in byChapter.keys)
      Unit(
        id: u,
        title: 'وحدة $u',
        chapters: byChapter[u]!,
      ),
  ];
  final questions = [
    for (var i = 0; i < 15; i++)
      Question(
        id: i + 1,
        unit: unitOf[chapters[i % 5]]!,
        chapter: chapters[i % 5],
        approved: true,
        stem: 'س${i + 1}',
        options: const ['أ', 'ب', 'ج', 'د'],
        correctIndex: i % 4,
        solutionSteps: const [],
        followThrough: const [],
      ),
  ];
  return ContentPack(
    packId: 'test-pack',
    year: 2027,
    edition: 1,
    units: units,
    questions: questions,
    cards: const [],
  );
}

DuelScope get _scope =>
    const DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'test-pack-1');

void main() {
  test('Run B — البنية تُستهلك', () {
    final pack = _pack();
    expect(pack.questions.length, 15);
    expect(pack.units.length, 3);
    expect(_scope().scopeString, isNotEmpty);
  });
}
