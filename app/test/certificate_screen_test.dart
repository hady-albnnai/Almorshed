// F6.5 — اختبارات شاشة شهادة الموسم:
// عرض الشهادة الجاهزة (initial) + حالات الأخطاء الصريحة عبر مُصدِر وهمي.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/cert/certificate.dart';
import 'package:fizya_clash/core/supabase/cert_api.dart';
import 'package:fizya_clash/features/account/certificate_screen.dart';

/// مُصدِر وهمي يرمي خطأً محدّدًا (أو يعيد شهادة) لاختبار كل حالة.
class _FakeIssuer implements CertIssuer {
  _FakeIssuer.throws(this._error) : _cert = null;
  _FakeIssuer.returns(this._cert) : _error = null;

  final Object? _error;
  final Certificate? _cert;

  @override
  Future<Certificate> issue(String season) async {
    if (_error != null) throw _error;
    return _cert!;
  }
}

Certificate _sample({CertTier tier = CertTier.goldTwoYears}) => Certificate(
      id: 'cert-1',
      season: '2026-2027',
      tier: tier,
      years: tier == CertTier.goldTwoYears ? 2 : 1,
      xp: 1234,
      devicePubkeyB64: 'AAAA',
      issuedAtMs: 1700000000000,
      notice: '',
      signatureB64: 'sig',
    );

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('عرض شهادة جاهزة: العنوان + الطبقة الذهبية + النقاط + شارة التوثيق',
      (tester) async {
    await pump(tester,
        CertificateScreen(season: '2026-2027', initial: _sample()));
    expect(find.byKey(const Key('cert_card')), findsOneWidget);
    expect(find.text(certTitle), findsOneWidget);
    expect(find.text('🥇 سنتان'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('2026-2027'), findsOneWidget);
    expect(find.byKey(const Key('cert_verified')), findsOneWidget);
    expect(find.byKey(const Key('cert_share')), findsOneWidget);
  });

  testWidgets('الطبقة الفضية تظهر مع سنة واحدة', (tester) async {
    await pump(
        tester,
        CertificateScreen(
            season: '2026-2027',
            initial: _sample(tier: CertTier.silverOneYear)));
    expect(find.text('🥈 سنة'), findsOneWidget);
  });

  testWidgets('زر المشاركة ينسخ نصّ الشهادة إلى الحافظة', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await pump(tester,
        CertificateScreen(season: '2026-2027', initial: _sample()));
    await tester.tap(find.byKey(const Key('cert_share')));
    await tester.pumpAndSettle();
    expect(copied, contains(certTitle));
    expect(copied, contains('2026-2027'));
    expect(find.byType(SnackBar), findsOneWidget);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('الموسم لم يُغلق ⇒ رسالة SEASON_OPEN', (tester) async {
    await pump(
        tester,
        CertificateScreen(
            season: '2026-2027',
            api: _FakeIssuer.throws(const CertApiException('SEASON_OPEN'))));
    expect(find.byKey(const Key('cert_season_open')), findsOneWidget);
  });

  testWidgets('لم يشارك ⇒ رسالة NOT_PARTICIPATED', (tester) async {
    await pump(
        tester,
        CertificateScreen(
            season: '2026-2027',
            api: _FakeIssuer.throws(
                const CertApiException('NOT_PARTICIPATED'))));
    expect(find.byKey(const Key('cert_not_participated')), findsOneWidget);
  });

  testWidgets('توقيع محلي مرفوض ⇒ رسالة تحقق فاشلة', (tester) async {
    await pump(
        tester,
        CertificateScreen(
            season: '2026-2027',
            api: _FakeIssuer.throws(
                const CertApiException('BAD_LOCAL_SIGNATURE'))));
    expect(find.byKey(const Key('cert_bad_sig')), findsOneWidget);
  });

  testWidgets('خطأ شبكة عام ⇒ حالة عدم الاتصال + زر إعادة', (tester) async {
    await pump(
        tester,
        CertificateScreen(
            season: '2026-2027',
            api: _FakeIssuer.throws(Exception('no net'))));
    expect(find.byKey(const Key('cert_offline')), findsOneWidget);
    expect(find.byKey(const Key('cert_retry')), findsOneWidget);
  });

  testWidgets('مُصدِر يعيد شهادة ⇒ تُعرض البطاقة بعد التحميل', (tester) async {
    // ملاحظة: verifyEmbedded يُنفَّذ داخل CertApi الحقيقي لا هنا؛ المُصدِر الوهمي
    // يعيد الشهادة مباشرة، فالشاشة تعرضها (مسار النجاح عبر الشبكة الوهمية).
    await pump(
        tester,
        CertificateScreen(
            season: '2026-2027',
            api: _FakeIssuer.returns(_sample())));
    expect(find.byKey(const Key('cert_card')), findsOneWidget);
    expect(find.text(certTitle), findsOneWidget);
  });
}
