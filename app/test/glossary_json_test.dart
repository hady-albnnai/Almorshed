import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fizya_clash/core/content/term_linter.dart';

/// اختبار القاموس الحقيقي الكامل — glossary/terms_data.py (444 مدخلاً)
/// محوَّل آلياً إلى app/assets/content/glossary.json (F2.1 الجزء الثاني).
///
/// هذا يثبت حرفية قرار ١٥: كل لفظ BAN من قاموس الأستاذ يُقبض عليه فعلاً،
/// وكل مرادف SYN يوجَّه إلى رسميه.
void main() {
  late Map<String, dynamic> glossary;

  setUpAll(() {
    final path =
        '${Directory.current.path}/assets/content/glossary.json';
    glossary =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  });

  test('بنية القاموس: 444 مدخلاً · 30 ممنوعاً · مرادفا SYN', () {
    expect((glossary['terms'] as List).length, 444);
    expect(glossary['banned'], hasLength(30));
    expect(glossary['synonyms'],
        {'التردد': 'التواتر', 'الجهد': 'التوتر / فرق الكمون'});
  });

  test('قرار ١٥ حرفياً: كل لفظ من الـ30 الممنوعة يُقبض عليه', () {
    final banned = (glossary['banned'] as List).cast<String>();
    for (final word in banned) {
      final issues = TermLinter.lint(
        'نص اختباري يتضمن $word ضمن سياق فيزيائي.',
        banned: banned.toSet(),
        synonyms: const {},
      );
      expect(issues, hasLength(1), reason: 'لم يُقبض على: $word');
      expect(issues.single.kind, LintKind.ban);
      expect(issues.single.matched, word);
    }
  });

  test('المرادفان SYN يُكتشفان ويوجَّهان إلى الرسمي', () {
    final syn = (glossary['synonyms'] as Map).cast<String, String>();
    syn.forEach((ar, official) {
      final issues = TermLinter.lint(
        'نص يتضمن $ar ضمن سياق.',
        banned: {},
        synonyms: syn,
      );
      expect(issues.single.kind, LintKind.syn);
      expect(issues.single.official, official);
    });
  });

  test('عينات موثقة من قرار الأستاذ موجود بالقاموس', () {
    final banned = (glossary['banned'] as List).cast<String>();
    // قرارات الأستاذ الموثقة بالخطة:
    expect(banned, contains('المفاعلة')); // الرسمي: ردية الوشيعة
    expect(banned, contains('الزنبرك')); // الرسمي: النابض
    expect(banned, contains('أشعة إكس')); // الرسمي: أشعة سينية
    expect(banned, contains('التأثير الكهروضوئي')); // الرسمي: الفعل الكهرضوئي
  });
}
