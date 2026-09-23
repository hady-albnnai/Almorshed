// F2.4 + وضع المراجعة — اختبارات المنطق الخالص (بلا واجهة/تخزين).
import 'dart:convert';

import 'package:fizya_clash/core/content/models.dart';
import 'package:fizya_clash/core/license/license_core.dart';
import 'package:fizya_clash/core/license/license_store.dart';
import 'package:fizya_clash/core/review/review_mode.dart';
import 'package:flutter_test/flutter_test.dart';

ContentPack _pack() => ContentPack.fromJson(<String, dynamic>{
  'packId': 't',
  'year': 2027,
  'edition': 1,
  'units': <dynamic>[],
  'questions': [
    {
      'id': 1,
      'unit': 'U1',
      'chapter': 'U1C1',
      'approved': true,
      'stem': 'معتمد',
      'options': ['أ', 'ب'],
      'correctIndex': 0,
    },
    {
      'id': 2,
      'unit': 'U1',
      'chapter': 'U1C1',
      'approved': false,
      'stem': 'غير معتمد',
      'options': ['أ', 'ب'],
      'correctIndex': 1,
    },
    {
      'id': 3,
      'unit': 'U2',
      'chapter': 'U2C1',
      'stem': 'بلا علم = غير معتمد',
      'options': ['أ', 'ب'],
      'correctIndex': 0,
    },
  ],
  'cards': <dynamic>[],
});

void main() {
  mainTeacherFlag();
  group('F2.4 تجميد المعدَّل (الوضع العادي)', () {
    test('approvedQuestions يحجب غير المعتمد وبلا علم', () {
      final p = _pack();
      expect(p.approvedQuestions.map((q) => q.id), [1]);
    });
  });

  group('وضع المراجعة', () {
    test('openAllForReview يفتح الكل ولا يمسّ الأصل', () {
      final original = _pack();
      final opened = openAllForReview(original);
      expect(opened.approvedQuestions.length, 3);
      expect(original.approvedQuestions.length, 1); // الأصل سليم
      // المحتوى نفسه محفوظ
      expect(opened.questions[1].stem, 'غير معتمد');
      expect(opened.questions[1].correctIndex, 1);
    });

    test('unapprovedQuestionIds تحدد ما يحمل شارة «قيد المراجعة»', () {
      expect(unapprovedQuestionIds(_pack()), {2, 3});
    });
  });

  group('دفتر الملاحظات', () {
    test('ReviewNote — جولة JSON + المفتاح + التسمية', () {
      const n = ReviewNote(
        kind: 'q',
        itemId: '101',
        verdict: ReviewVerdict.edit,
        text: 'الخيار الثالث خطأ',
        updatedMs: 5,
      );
      final back = ReviewNote.fromJson(n.toJson());
      expect(back.key, 'q:101');
      expect(back.label, 'س101');
      expect(back.verdict, ReviewVerdict.edit);
      expect(back.text, 'الخيار الثالث خطأ');
      expect(
        const ReviewNote(
          kind: 'c',
          itemId: '14',
          verdict: ReviewVerdict.ok,
          updatedMs: 0,
        ).label,
        'ب14',
      );
      expect(
        const ReviewNote(
          kind: 'p',
          itemId: 'U1C1P3',
          verdict: ReviewVerdict.ok,
          updatedMs: 0,
        ).label,
        'ف U1C1P3',
      );
    });

    test('حكم مجهول في JSON ⇒ يحتاج تعديل (لا انفجار)', () {
      final n = ReviewNote.fromJson({'k': 'q', 'i': 1, 'v': 'zzz'});
      expect(n.verdict, ReviewVerdict.edit);
      expect(n.itemId, '1');
    });

    test('formatReviewReport — تقرير واتساب مرتّب بالأقسام', () {
      final notes = [
        const ReviewNote(
          kind: 'q',
          itemId: '103',
          verdict: ReviewVerdict.ok,
          updatedMs: 0,
        ),
        const ReviewNote(
          kind: 'q',
          itemId: '101',
          verdict: ReviewVerdict.ok,
          updatedMs: 0,
        ),
        const ReviewNote(
          kind: 'q',
          itemId: '102',
          verdict: ReviewVerdict.edit,
          text: 'الصحيح T0/2',
          updatedMs: 0,
        ),
        const ReviewNote(
          kind: 'c',
          itemId: '14',
          verdict: ReviewVerdict.remove,
          updatedMs: 0,
        ),
      ];
      final r = formatReviewReport(notes, now: DateTime(2026, 9, 20));
      expect(r, contains('مراجعة المطوّر — 2026-09-20'));
      expect(r, contains('المجموع: 4 بند'));
      expect(r, contains('✅ صحيح (2): س101، س103')); // مرتّبة
      expect(r, contains('✏️ يحتاج تعديل (1):'));
      expect(r, contains('• س102: الصحيح T0/2'));
      expect(r, contains('❌ حذف (1):'));
      expect(r, contains('• ب14'));
    });

    test('تقرير فارغ — رأس فقط', () {
      final r = formatReviewReport(const [], now: DateTime(2026, 9, 20));
      expect(r.split('\n').length, 2);
      expect(r, isNot(contains('✅')));
    });
  });
}

// ── قرار ٥٥: كود المراجعة ⇒ علم 'teacher' في التوكن الموقّع ──
LicenseData _licWithFlags(List<String> flags) {
  final payload = jsonEncode({
    'code_id': 'X',
    'device_key_hash': '',
    'release_id': 'r',
    'expires_at': 1,
    'hard_deadline': 2,
    'flags': flags,
  });
  return LicenseData(
    mode: LicenseMode.licensed,
    token: LicenseToken(
      payloadB64: base64Encode(utf8.encode(payload)),
      sigB64: 'AA==',
    ),
  );
}

void mainTeacherFlag() {
  group('كود المراجعة (0008)', () {
    test('توكن بعلم teacher ⇒ isTeacher', () {
      expect(_licWithFlags(['full', 'teacher']).isTeacher, isTrue);
      expect(_licWithFlags(['full']).isTeacher, isFalse);
    });
    test('بلا توكن أو حمولة تالفة ⇒ false بلا انفجار', () {
      expect(const LicenseData().isTeacher, isFalse);
      expect(
        const LicenseData(
          token: LicenseToken(payloadB64: '!!', sigB64: ''),
        ).isTeacher,
        isFalse,
      );
    });
  });
}
