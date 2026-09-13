// ═════════════════════════════════════════════════════════════════════
// بوابة التفعيل — مسارها الحقيقي بواجهات مضخّة (اختبارات Widgets).
// الفصل عن ملف التجسس إلزامي: testWidgets يفعّل الربط الاختباري الذي
// يجيب أي HTTP بـ400 زائف — لصقة 15.
// ═════════════════════════════════════════════════════════════════════
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/license/license_core.dart';
import 'package:fizya_clash/core/license/license_store.dart';
import 'package:fizya_clash/core/supabase/activation_api.dart';
import 'package:fizya_clash/core/supabase/anonymous_auth.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';
import 'package:fizya_clash/features/activation/activation_gate.dart';

const _now = 1790000000000;

void main() {
  testWidgets('F4.4: البوابة بالمسار الحقيقي — توكن سليم ⇒ مرخّص + مخزن محفوظ',
      (tester) async {
    // زوج مفاتيح اختبار — البوابة تفحص به (حقن كامل)
    final priv = ed.newKeyFromSeed(
        Uint8List.fromList(List<int>.generate(32, (i) => i + 1)));
    final pub = ed.public(priv);
    final token = LicenseToken.issue(
      const LicensePayload(
        codeId: 'K7M2P9QW4X4TR8N',
        // ربط الجهاز: sha256('ABCDEFGH') — متجه العقد §٦
        deviceKeyHash: '9ac2197d9258257b1ae8463e4214e4cd0a578bc1517f2415928b91be4283fc48',
        releaseId: '2027-v1',
        expiresAtMs: _now + 86400000,
        hardDeadlineMs: 1835904000000,
        flags: <String>{'full'},
      ),
      priv,
    );
    var modeSet = false;
    final store = InMemoryLicenseStore();

    await tester.pumpWidget(MaterialApp(
        home: ActivationGate(
      licenseStore: store,
      onModeSet: () => modeSet = true,
      devicePubkeyB64: 'QUJDREVGR0g=',
      licenseKey: pub,
      activationApi: _StaticActivationApi(ActivationAttempt(
        ok: true,
        token: token,
        serverTimeMs: _now,
        devicesUsed: 1,
      )),
    )));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), 'K7M2P-9QW4X-4TR8N');
    await tester.pump();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pumpAndSettle();

    expect(modeSet, true);
    final saved = await store.load();
    expect(saved.mode, LicenseMode.licensed);
    expect(saved.token?.payloadB64, token.payloadB64);
    expect(saved.lastWallMs, _now); // مرساة السيرفر
    expect(saved.failures, 0);
  });

  testWidgets('F4.4: فشل منطقي يعدّ العداد وشبكي لا يعدّه', (tester) async {
    final store = InMemoryLicenseStore();
    await tester.pumpWidget(MaterialApp(
        home: ActivationGate(
      licenseStore: store,
      onModeSet: () {},
      devicePubkeyB64: 'QUJDREVGR0g=',
      activationApi: _StaticActivationApi(const ActivationAttempt(
          ok: false, errorAr: 'الكود غير معروف', countsAsAttempt: true)),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K7M2P-9QW4X-4TR8N');
    await tester.pump();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pumpAndSettle();
    expect((await store.load()).failures, 1);

    await tester.pumpWidget(MaterialApp(
        home: ActivationGate(
      licenseStore: store,
      onModeSet: () {},
      devicePubkeyB64: 'QUJDREVGR0g=',
      activationApi: _StaticActivationApi(const ActivationAttempt(
          ok: false, errorAr: 'انقطع الاتصال', countsAsAttempt: false)),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K7M2P-9QW4X-4TR8N');
    await tester.pump();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pumpAndSettle();
    expect((await store.load()).failures, 1); // لم يزد — عادل
  });
}

/// زيف ثابت الرد — مسار البوابة بلا شبكة إطلاقاً.
class _StaticActivationApi extends ActivationApi {
  _StaticActivationApi(this._result)
      : super(
          transport: SupabaseTransport(baseUrl: 'http://127.0.0.1:1'),
          auth: AnonymousAuth(
              transport: SupabaseTransport(baseUrl: 'http://127.0.0.1:1'),
              store: InMemorySessionStore()),
        );

  final ActivationAttempt _result;

  @override
  Future<ActivationAttempt> activate(
          String code, String pubkeyB64, String deviceFp) async =>
      _result;
}
