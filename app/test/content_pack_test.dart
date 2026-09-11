import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/content/term_linter.dart';

void main() {
  final fixturePath =
      '${Directory.current.path}/test/fixtures/sample_pack.json';
  late ContentPack pack;

  setUpAll(() {
    pack = ContentPack.fromJsonString(File(fixturePath).readAsStringSync());
  });

  group('F2.1 — تحميل حزمة المحتوى', () {
    test('الفك: وحدة/فصل/فقرة/سؤال/بطاقة بالمعرفات الصحيحة', () {
      expect(pack.packId, 'syria-2027-v1');
      expect(pack.year, 2027);
      expect(pack.edition, 1);
      expect(pack.units.single.id, 'U1');
      expect(pack.units.single.chapters.single.id, 'U1C1');
      expect(pack.units.single.chapters.single.paragraphs.length, 2);
      expect(pack.questions.length, 2);
      expect(pack.cards.single.formula, 'F = −k·x');
    });

    test('قرار ٢٤: approvedQuestions تعيد المعتمد حصراً', () {
      final ids = pack.approvedQuestions.map((q) => q.id).toList();
      expect(ids, [101]); // 102 غير معتمد ⇒ محجوب
    });

    test('قرار ٣٧: التجربة داخل فقرتها بموقعها', () {
      final p1 = pack.units.single.chapters.single.paragraphs.first;
      expect(p1.experimentId, 'EXP_SPRING');
      final p2 = pack.units.single.chapters.single.paragraphs[1];
      expect(p2.experimentId, isNull);
    });

    test('الفشل المبكر: JSON ناقص يرمي FormatException', () {
      expect(
        () => ContentPack.fromJson(
            jsonDecode('{"packId":"x","year":2027,"edition":1}')
                as Map<String, dynamic>),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('F2.1 — TermLinter (قرار ١٤/١٥ — القاموس الحقيقي مصغّر)', () {
    // عينة من القاموس الفعلي (glossary/terms_data.py — الحقل الخامس BAN):
    final banned = {'المفاعلة', 'المحاثة', 'الزنبرك', 'الفيض المغناطيسي'};
    final synonyms = {'شبه موصل': 'أنصاف نواقل', 'أشعة إكس': 'أشعة سينية'};

    test('نص سليم يعيد صفر انتهاكات', () {
      final issues = TermLinter.lint(
        'نابض يخضع للقوة F = −k·x في أنصاف نواقل مشوبة',
        banned: banned,
        synonyms: synonyms,
      );
      expect(issues, isEmpty);
    });

    test('لفظ BAN يُكتشف فوراً', () {
      final issues = TermLinter.lint(
        'تسري التيار في المفاعلة الحثية',
        banned: banned,
        synonyms: synonyms,
      );
      expect(issues.single.kind, LintKind.ban);
    });

    test('المرادف المسموح SYN يُنذر بالتوجيه نحو الرسمي', () {
      final issues = TermLinter.lint(
        'بلورة شبه موصل نقية',
        banned: banned,
        synonyms: synonyms,
      );
      expect(issues.single.kind, LintKind.syn);
      expect(issues.single.official, 'أنصاف نواقل');
    });

    test('فحص حزمة كاملة: يجد اللفظ الممنوع في السؤال غير المعتمد', () {
      // نحقن سؤالاً فيه لفظ ممنوع للتأكد أن الفحص يشمل حتى غير المعتمد
      // (يُحجب عن الطالب لكن القاموس يعلّمه عند المراجعة).
      final dirty = ContentPack.fromJson(jsonDecode(jsonEncode({
        'packId': 'dirty', 'year': 2027, 'edition': 1,
        'units': pack.units.map((u) => u).toList(),
        'questions': [
          {
            'id': 500, 'unit': 'U1', 'chapter': 'U1C1', 'approved': false,
            'stem': 'ما دور الزنبرك في الدارة؟',
            'options': ['أ'], 'correctIndex': 0,
            'solutionSteps': [], 'followThrough': []
          }
        ],
        'cards': const [],
      })) as Map<String, dynamic>);

      final violations = TermLinter.lintPack(
        dirty,
        banned: banned,
        synonyms: synonyms,
      );
      expect(violations['Q500'], isNotNull);
      expect(violations['Q500']!.single.matched, 'الزنبرك');
    });
  });
}
