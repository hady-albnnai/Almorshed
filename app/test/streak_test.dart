import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/xp/streak_service.dart';

/// F3.8 — السلسلة اليومية (نافذة ٤ الفجر) + المُسجّل الجسر + فكرة اليوم.
void main() {
  group('نافذة ٤ الفجر — docs/12 §٥ (سماحية ليلة السهر)', () {
    test('٠٣:٥٩ وما قبلها يفتان لليوم السابق — و٠٤:٠٠ فصاعداً لليوم نفسه',
        () {
      expect(studyDateKeyOf(DateTime(2026, 9, 13, 3, 59)), '2026-09-12');
      expect(studyDateKeyOf(DateTime(2026, 9, 13, 0, 5)), '2026-09-12');
      expect(studyDateKeyOf(DateTime(2026, 9, 13, 4, 0)), '2026-09-13');
      expect(studyDateKeyOf(DateTime(2026, 9, 13, 23, 30)), '2026-09-13');
    });
  });

  group('حساب السلسلة من أحداث الدفتر', () {
    test('بلا أحداث = صفر', () {
      final s = computeStreak(const [], DateTime(2026, 9, 13, 20));
      expect(s.days, 0);
      expect(s.todayDone, isFalse);
    });

    test('نشاط اليوم = ١ واليوم منجز', () async {
      final r = XpRecorder.inMemory();
      await r.record('batchDone',
          now: DateTime(2026, 9, 13, 20)); // ١٥+١٠ سلسلة
      final s = computeStreak(await r.ledger.events(),
          DateTime(2026, 9, 13, 22));
      expect(s.days, 1);
      expect(s.todayDone, isTrue);
    });

    test('نشاط أمس حصراً = السلسلة حية ١ واليوم بانتظار', () async {
      final r = XpRecorder.inMemory();
      await r.record('lessonNew', now: DateTime(2026, 9, 12, 20));
      final s = computeStreak(await r.ledger.events(),
          DateTime(2026, 9, 13, 10));
      expect(s.days, 1);
      expect(s.todayDone, isFalse);
    });

    test('اليوم وأمس = ٢ متتاليان', () async {
      final r = XpRecorder.inMemory();
      await r.record('lessonNew', now: DateTime(2026, 9, 12, 20));
      await r.record('batchDone', now: DateTime(2026, 9, 13, 11));
      final s = computeStreak(await r.ledger.events(),
          DateTime(2026, 9, 13, 21));
      expect(s.days, 2);
      expect(s.todayDone, isTrue);
    });

    test('فجوة كاملة بلا نشاط تكسر السلسلة (قرار: بلا تجميد v1)', () async {
      final r = XpRecorder.inMemory();
      await r.record('lessonNew', now: DateTime(2026, 9, 8, 20));
      final s = computeStreak(await r.ledger.events(),
          DateTime(2026, 9, 13, 10));
      expect(s.days, 0); // ٩ و١٠ و١١ و١٢ صمت ⇒ انكسار
    });
  });

  group('المُسجّل — جسر «سلسلة اليوم» التلقائي', () {
    test('أول نشاط باليوم يمنح +١٠ واللاحق لا يكررها — والسلسلة موثقة',
        () async {
      final r = XpRecorder.inMemory();
      final now = DateTime(2026, 9, 13, 17);
      expect(await r.record('batchDone', now: now), isTrue); // +١٥
      expect(await r.record('lessonNew', now: now), isTrue); // +١٠
      final events = await r.ledger.events();
      // batchDone + streakDay + lessonNew — بلا streakDay ثانٍ
      expect(events.map((e) => e.type).toList(),
          ['batchDone', 'streakDay', 'lessonNew']);
      expect(await r.ledger.dayPoints('2026-09-13'), 35);
      final v = await r.ledger.verifyAll();
      expect(v.ok, isTrue);
    });

    test('السقف اليومي يحمي حتى عبر المُسجّل — والتوقيع سليم', () async {
      final r = XpRecorder.inMemory();
      final now = DateTime(2026, 9, 13, 17);
      expect(await r.record('batchDone', now: now), isTrue);
      expect(await r.record('batchDone', now: now), isFalse); // مرة/يوم
      final v = await r.ledger.verifyAll();
      expect(v.ok, isTrue);
    });
  });

  group('فكرة اليوم — دوّارة حتماً', () {
    test('نفس اليوم ⇒ نفس الفكرة، وفرق ١٠ أيام ⇒ دورة كاملة تعود', () {
      final a = factForDay('2026-09-13');
      expect(factForDay('2026-09-13'), a);
      expect(factForDay('2026-09-23'), a); // +١٠ أيام = نفس موضع الدورة
    });

    test('العشر أفكار متمايزة عبر عشرة أيام متتالية', () {
      final seen = <String>{
        for (var i = 0; i < 10; i++) factForDay('2026-09-${10 + i}'),
      };
      expect(seen.length, dailyFacts.length);
    });
  });
}
