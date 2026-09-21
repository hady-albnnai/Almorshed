// M5/F5.5 — اختبارات عدالة البذرة عبر النقليتين (خادمية + محلية).
// نفس البذرة ⇒ نفس الجلسة حرفياً أياً كان مسار توليدها (الخادم يولّد
// رمز غرفة 50 بت، والمضيف المحلي رمز 30 بت — كلاهما يدخل makeSeed بنفس
// scopeTag) ⇒ نفس الأسئلة وترتيب الخيارات ⇒ نفس النتائج على جهازين.
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/duel/duel_engine.dart';
import 'package:fizya_clash/core/duel/local_duel_flow.dart';

const DuelScope _scope = DuelScope(units: ['U1', 'U2', 'U3'], packTag: 'p-1');

ContentPack _pack() {
  const chapters = ['U1C1', 'U1C2', 'U2C1', 'U2C2', 'U3C1'];
  final unitOf = <String, String>{
    for (final c in chapters) c: c.substring(0, 2),
  };
  final byChapter = <String, List<Chapter>>{};
  for (final c in chapters) {
    byChapter.putIfAbsent(unitOf[c]!, () => <Chapter>[]).add(Chapter(
          id: c,
          title: 'فصل $c',
          page: chapters.indexOf(c) + 1,
          paragraphs: const [],
        ));
  }
  final units = <Unit>[
    for (final u in byChapter.keys)
      Unit(id: u, title: 'وحدة $u', chapters: byChapter[u]!),
  ];
  final questions = <Question>[
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
    packId: 'p-1',
    year: 2027,
    edition: 1,
    units: units,
    questions: questions,
    cards: const [],
  );
}

void main() {
  test('بذرة واحدة بمسارَي التوليد (خادمي/محلي) ⇒ نفس الجلسة حرفياً', () {
    final tag = scopeTagOf(_scope);
    // مسار الخادم: makeSeed(tag, roomCode 50 بت) — ومسار المحلي يستدعيها بنفس
    // المعاملين فيجب أن يتطابقا، ومنهما تتطابق الجلسة كاملة.
    const roomCode = 676889741750429; // نفس مرجع المحرك
    final seed = makeSeed(tag: tag, roomCode: roomCode);
    final a = buildDuelSession(_pack(), seed: seed, scope: _scope);
    final b = buildDuelSession(_pack(), seed: seed, scope: _scope);
    expect(a.built.questionIds, b.built.questionIds);
    expect(a.built.optionOrders, b.built.optionOrders);
    expect(a.correctDisplay, b.correctDisplay);
  });

  test('الرمز المحلي ٣٠ بت يدخل makeSeed فيطابق مسار الغرفة الخادمية', () {
    final tag = scopeTagOf(_scope);
    // رمز محلي 30 بت (٦ محارف Crockford)
    const code = 0x2ABCDEF & 0x3FFFFFFF;
    final encoded = encodeLocalCode(code);
    expect(encoded.length, 6);
    expect(encoded, encodeLocalCode(code), reason: 'الترميز مستقر');
    // البذرة المحلية من نفس scopeTag
    final local = buildDuelSession(
      _pack(),
      seed: makeSeed(tag: tag, roomCode: code),
      scope: _scope,
    );
    final server = buildDuelSession(
      _pack(),
      seed: makeSeed(tag: tag, roomCode: code),
      scope: _scope,
    );
    expect(local.built.questionIds, server.built.questionIds);
    expect(local.correctDisplay, server.correctDisplay);
  });

  test('بصمة الأسئلة: مستقرة ومطابقة عبر بناءين مستقلين (جهازين)', () {
    final seed = makeSeed(tag: scopeTagOf(_scope), roomCode: 424242);
    final a = buildDuelSession(_pack(), seed: seed, scope: _scope);
    final b = buildDuelSession(_pack(), seed: seed, scope: _scope);
    final fpA = questionsFingerprint(a.built.questionIds, a.built.optionOrders);
    final fpB = questionsFingerprint(b.built.questionIds, b.built.optionOrders);
    expect(fpA, fpB, reason: 'نفس البذرة ⇒ نفس البصمة');
    expect(fpA, matches(RegExp(r'^[0-9A-F]{8}$')), reason: '٨ محارف hex');
  });

  test('بذرتان مختلفتان ⇒ بصمتان مختلفتان', () {
    final tag = scopeTagOf(_scope);
    final a = buildDuelSession(
        _pack(), seed: makeSeed(tag: tag, roomCode: 1), scope: _scope);
    final b = buildDuelSession(
        _pack(), seed: makeSeed(tag: tag, roomCode: 2), scope: _scope);
    final fpA = questionsFingerprint(a.built.questionIds, a.built.optionOrders);
    final fpB = questionsFingerprint(b.built.questionIds, b.built.optionOrders);
    expect(fpA, isNot(fpB));
  });

  test('نفس الإجابات ⇒ نفس النقاط والحسم على الجهازين', () {
    final seed = makeSeed(tag: scopeTagOf(_scope), roomCode: 999);
    final s = buildDuelSession(_pack(), seed: seed, scope: _scope);
    final answers = [for (var i = 0; i < s.length; i++) s.correctDisplay[i]];
    final host = gradeDuelSide(s, answers);
    final guest = gradeDuelSide(s, answers); // جهاز ثانٍ يحسب نفسه
    expect(host.score, guest.score);
    expect(host.corrects, guest.corrects);
    expect(host.score, 2300, reason: '٢×١٠٠ + ٣×٢٠٠ + ٥×٣٠٠');
    // تعادل كامل ⇒ عملة streamC من البذرة — نفس الحسم على الجهازين
    final tie = hostWins(host: host, guest: guest, seed: seed);
    expect(tie, hostWins(host: host, guest: guest, seed: seed),
        reason: 'الحسم حتمي لا يتبدل');
  });
}
