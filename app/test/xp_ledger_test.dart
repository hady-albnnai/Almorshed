import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:fizya_clash/core/xp/xp_event.dart';
import 'package:fizya_clash/core/xp/xp_ledger.dart';
import 'package:fizya_clash/core/xp/xp_signer.dart';
import 'package:fizya_clash/core/xp/xp_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// F3.7 — اختبارات دفتر XP: السلسلة والتوقيع + ثلاثية التلاعب الإلزامية
/// (docs/12 §٨-4: تعديل payload · حذف حدث · توقيع مزيف ⇒ رفض ١٠٠٪).
void main() {
  // بذرة حتمية — نفس المفتاح في كل اختبار والمتجهات قابلة للإعادة
  Uint8List fixedSeed() =>
      Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

  XpLedgerService ledger({InMemoryXpEventStore? store}) => XpLedgerService(
        store: store ?? InMemoryXpEventStore(),
        vault: InMemoryXpKeyVault(fixedSeed()),
      );

  group('السلسلة والتوقيع — docs/12 §٤.۲', () {
    test('الجذر: seq=1 وprevHash=GENESIS والهاش يطابق إعادة الحساب المستقلة',
        () async {
      final l = ledger();
      final r = await l.append(
          typeId: 'batchDone',
          dateKey: '2026-09-12',
          tsMsOverride: 1790000000000);
      expect(r.ok, isTrue);
      final e = r.event!;
      expect(e.seq, 1);
      expect(e.prevHash, genesisPrevHash);
      // إعادة حساب مستقلة تماماً بالاختبار نفسه
      final core = <String, dynamic>{
        'seq': 1,
        'type': 'batchDone',
        'ts': 1790000000000,
        'payload': {'points': 15, 'dateKey': '2026-09-12'},
        'prevHash': 'GENESIS',
      };
      final expected = crypto.sha256
          .convert(utf8.encode('GENESIS' + jsonEncode(core)))
          .toString();
      expect(e.hash, expected);
    });

    test('سلسلة من 3: روابط prevHash متعاقبة وseq بلا فجوات وتحقق كامل ✓',
        () async {
      final l = ledger();
      await l.append(typeId: 'batchDone', dateKey: '2026-09-12');
      await l.append(typeId: 'lessonNew', dateKey: '2026-09-12');
      await l.append(
          typeId: 'cardReview', dateKey: '2026-09-12'); // بلا سقف
      final events = await l.events();
      expect(events.map((e) => e.seq).toList(), [1, 2, 3]);
      expect(events[1].prevHash, events[0].hash);
      expect(events[2].prevHash, events[1].hash);
      final v = await l.verifyAll();
      expect(v.ok, isTrue);
    });

    test('نفس البذرة ⇒ نفس المفتاح العام (هوية الجهاز حتمية)', () {
      final a = XpSigner.fromSeed(fixedSeed());
      final b = XpSigner.fromSeed(fixedSeed());
      expect(
          a.publicKey.bytes.toString(), b.publicKey.bytes.toString());
    });
  });

  group('ثلاثية التلاعب — رفض ١٠٠٪ (docs/12 §٨-4)', () {
    Future<XpLedgerService> threeEvents(InMemoryXpEventStore store) async {
      final l = XpLedgerService(
          store: store, vault: InMemoryXpKeyVault(fixedSeed()));
      await l.append(typeId: 'batchDone', dateKey: '2026-09-12');
      await l.append(typeId: 'lessonNew', dateKey: '2026-09-12');
      await l.append(typeId: 'cardReview', dateKey: '2026-09-12');
      return l;
    }

    test('١) تعديل payload ⇒ الهاش لا يطابق ⇒ رفض', () async {
      final store = InMemoryXpEventStore();
      final l = await threeEvents(store);
      expect((await l.verifyAll()).ok, isTrue);
      // تلاعب مباشر بالمخزن: رفع النقاط خلسة
      final raw = await store.loadEvents();
      raw[1].payload['points'] = 999;
      await store.saveEvents(raw);
      // التحقق بخدمة جديدة (كإعادة فتح) — الكاش لا يُخفي العبث
      final fresh = XpLedgerService(
          store: store, vault: InMemoryXpKeyVault(fixedSeed()));
      final v = await fresh.verifyAll();
      expect(v.ok, isFalse);
      expect(v.reason, contains('الهاش'));
      // «نقاط بلا سلسلة موقعة = مرفوضة»
      expect(await fresh.verifiedTotalXp(), 0);
    });

    test('٢) حذف حدث أوسط ⇒ فجوة تسلسل ⇒ رفض', () async {
      final store = InMemoryXpEventStore();
      final l = await threeEvents(store);
      final raw = await store.loadEvents();
      raw.removeAt(1); // حذف الثاني — الثالث يحمل seq=3
      await store.saveEvents(raw);
      final fresh = XpLedgerService(
          store: store, vault: InMemoryXpKeyVault(fixedSeed()));
      final v = await fresh.verifyAll();
      expect(v.ok, isFalse);
      expect(v.reason, contains('فجوة'));
    });

    test('٣) توقيع مزيف بمفتاح آخر ⇒ رفض', () async {
      final store = InMemoryXpEventStore();
      final l = await threeEvents(store);
      // مهاجم بمفتاحه يوقّع حدثاً — لكن السلسلة بمفتاح الجهاز
      final attacker = XpSigner.fromSeed(
          Uint8List.fromList(List<int>.generate(32, (i) => 200 - i)));
      final raw = await store.loadEvents();
      final forged = XpEvent(
        seq: raw[0].seq,
        type: raw[0].type,
        tsMs: raw[0].tsMs,
        payload: raw[0].payload,
        prevHash: raw[0].prevHash,
        hash: raw[0].hash,
        sigB64: attacker.signHash(
            Uint8List.fromList(_hexBytes(raw[0].hash))),
      );
      raw[0] = forged;
      await store.saveEvents(raw);
      final fresh = XpLedgerService(
          store: store, vault: InMemoryXpKeyVault(fixedSeed()));
      final v = await fresh.verifyAll();
      expect(v.ok, isFalse);
      expect(v.reason, contains('توقيع'));
    });
  });

  group('الحدود اليومية ومهام اليوم (§٤.١)', () {
    test('نوع مرة/يوم: مرة ينام والثاني يُرفض — وغداً يعود', () async {
      final l = ledger();
      expect(
          (await l.append(typeId: 'batchDone', dateKey: '2026-09-12')).ok,
          isTrue);
      final second = await l.append(
          typeId: 'batchDone', dateKey: '2026-09-12');
      expect(second.ok, isFalse); // السقف اليومي
      expect(
          (await l.append(typeId: 'batchDone', dateKey: '2026-09-13')).ok,
          isTrue); // يوم جديد
    });

    test('نوع بلا سقف: بطاقة المراجعة ×3 والنقاط تجمّع', () async {
      final l = ledger();
      for (var i = 0; i < 3; i++) {
        expect(
            (await l.append(typeId: 'cardReview', dateKey: '2026-09-12'))
                .ok,
            isTrue);
      }
      expect(await l.totalXp(), 3); // +1 ×3
    });

    test('مهام اليوم: dayDone وdayPoints يجيبان بدقة', () async {
      final l = ledger();
      await l.append(typeId: 'batchDone', dateKey: '2026-09-12'); // 15
      await l.append(typeId: 'labChallenge', dateKey: '2026-09-12'); // 10
      expect(await l.dayDone('batchDone', '2026-09-12'), isTrue);
      expect(await l.dayDone('lessonNew', '2026-09-12'), isFalse);
      expect(await l.dayPoints('2026-09-12'), 25);
      expect(await l.dayPoints('2026-09-13'), 0);
    });

    test('إجمالي XP عبر أيام وأنواع', () async {
      final l = ledger();
      await l.append(typeId: 'batchDone', dateKey: '2026-09-12'); // 15
      await l.append(typeId: 'cardReview', dateKey: '2026-09-12'); // 1
      await l.append(typeId: 'lessonNew', dateKey: '2026-09-13'); // 10
      expect(await l.totalXp(), 26);
    });
  });

  group('النقاط اليدوية والرفض الآمن', () {
    test('manual: نقاط مخصصة بسبب — بلا سقف', () async {
      final l = ledger();
      final r = await l.append(
        typeId: 'manual',
        dateKey: '2026-09-12',
        pointsOverride: 30,
        extra: {'reason': 'جائزة الأستاذ على حل الواجب'},
      );
      expect(r.ok, isTrue);
      expect(r.event!.payload['points'], 30);
      expect(r.event!.payload['reason'], contains('الأستاذ'));
      // بلا سقف — ثانية تعمل
      expect(
          (await l.append(
                  typeId: 'manual',
                  dateKey: '2026-09-12',
                  pointsOverride: 5,
                  extra: {'reason': 'مبادرة'}))
              .ok,
          isTrue);
    });

    test('manual بلا نقاط ⇒ رفض، ونوع مجهول ⇒ رفض', () async {
      final l = ledger();
      expect(
          (await l.append(typeId: 'manual', dateKey: '2026-09-12')).ok,
          isFalse);
      expect((await l.append(typeId: 'hackType', dateKey: '2026-09-12')).ok,
          isFalse);
    });
  });

  group('الاستمرارية عبر إعادة البناء', () {
    test('مخزن وخزنة نفسهما ⇒ السلسلة تكمل seq=4 وتتحقق', () async {
      final store = InMemoryXpEventStore();
      var l = XpLedgerService(
          store: store, vault: InMemoryXpKeyVault(fixedSeed()));
      await l.append(typeId: 'batchDone', dateKey: '2026-09-12');
      await l.append(typeId: 'lessonNew', dateKey: '2026-09-12');
      // خدمة جديدة كلياً (كإعادة فتح التطبيق)
      l = XpLedgerService(
          store: store, vault: InMemoryXpKeyVault(fixedSeed()));
      final r = await l.append(typeId: 'streakDay', dateKey: '2026-09-12');
      expect(r.ok, isTrue);
      expect(r.event!.seq, 3);
      final v = await l.verifyAll();
      expect(v.ok, isTrue);
      expect(await l.totalXp(), 35); // 15+10+10
    });
  });
}

/// hex → بايتات للاختبارات (مطابق لمسار الخدمة).
Uint8List _hexBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
