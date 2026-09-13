// ═════════════════════════════════════════════════════════════════════
// F4.3/F4.4/F4.5 عميل — نقلية Supabase ضد خادم تجسس محلي حقيقي:
// أشكال الطلبات (مسار/رؤوس/جسم) + كاش الجلسة والتجديد + ترجمة الأخطاء
// + عقد verify_xp_events (رفض 422 = ردّ لا انقطاع). صفر شبكة خارجية.
// ═════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizya_clash/core/license/license_core.dart';
import 'package:fizya_clash/core/license/license_store.dart';
import 'package:fizya_clash/core/supabase/activation_api.dart';
import 'package:fizya_clash/core/supabase/anonymous_auth.dart';
import 'package:fizya_clash/core/supabase/http_xp_sync_api.dart';
import 'package:fizya_clash/core/supabase/supabase_transport.dart';
import 'package:fizya_clash/core/sync/sync_engine.dart';
import 'package:fizya_clash/core/xp/xp_event.dart';

const _now = 1790000000000;

/// خادم تجسس: يسجّل (مسار، بروتوكول مصادقة، جسم) ويردّ بحسب السيناريو.
class _SpyServer {
  _SpyServer(this._handler);

  final Future<Map<String, dynamic>> Function(
          String path, Map<String, String> headers, Map<String, dynamic> body)
      _handler;

  late final HttpServer server;
  final List<String> paths = <String>[];

  Future<String> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final bodyRaw = await utf8.decoder.bind(req).join();
      Map<String, dynamic> body = const {};
      try {
        final d = jsonDecode(bodyRaw);
        if (d is Map<String, dynamic>) body = d;
      } catch (_) {}
      final headers = <String, String>{
        'authorization': req.headers.value('authorization') ?? '',
        'apikey': req.headers.value('apikey') ?? '',
      };
      paths.add(req.uri.path);
      final resp = await _handler(req.uri.path, headers, body);
      req.response.statusCode = (resp[':status'] as int?) ?? 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(resp[':payload'] ?? resp));
      await req.response.close();
    });
    return 'http://127.0.0.1:${server.port}';
  }

  Future<void> stop() => server.close(force: true);
}

XpEvent _event() => XpEvent(
      seq: 1,
      type: 'batchDone',
      tsMs: 1790000000000,
      payload: <String, dynamic>{'points': 15, 'dateKey': '2026-09-12'},
      prevHash: 'GENESIS',
      hash: 'ab' * 32,
      sigB64: 'QUFBQQ==',
    );

void main() {
  test('F4.3: تسجيل مجهول — الجسم والرؤوس بالعقد + الكاش يمنع الطلب الثاني',
      () async {
    final spy = _SpyServer((path, headers, body) {
      expect(path, '/auth/v1/signup');
      expect(body['email'], '');
      expect(headers['apikey'], 'test-key');
      return <String, dynamic>{
        'access_token': 'a1',
        'refresh_token': 'r1',
        'expires_in': 3600,
        'user': <String, dynamic>{'id': 'u-1'},
      };
    });
    final base = await spy.start();
    try {
      final transport = SupabaseTransport(baseUrl: base, anonKey: 'test-key');
      final auth = AnonymousAuth(
          transport: transport,
          store: InMemorySessionStore(),
          nowMs: () => _now);
      final s1 = await auth.session();
      expect(s1.userId, 'u-1');
      expect(s1.accessToken, 'a1');
      final s2 = await auth.session(); // من الكاش — طلب واحد حصراً
      expect(s2.accessToken, 'a1');
      expect(spy.paths.length, 1);
    } finally {
      await spy.stop();
    }
  });

  test('F4.3: جلسة قاربت الانتهاء ⇒ تجديد refresh_token', () async {
    final spy = _SpyServer((path, headers, body) {
      if (path == '/auth/v1/signup') {
        return <String, dynamic>{
          'access_token': 'old',
          'refresh_token': 'rot1',
          'expires_in': 10, // يهبط تحت هامش الدقيقة ⇒ غير صالح
          'user': <String, dynamic>{'id': 'u-1'},
        };
      }
      expect(path, '/auth/v1/token?grant_type=refresh_token');
      expect(body['refresh_token'], 'rot1');
      return <String, dynamic>{
        'access_token': 'new',
        'refresh_token': 'rot2',
        'expires_in': 3600,
        'user': <String, dynamic>{'id': 'u-1'},
      };
    });
    final base = await spy.start();
    try {
      final transport = SupabaseTransport(baseUrl: base, anonKey: 'test-key');
      final auth = AnonymousAuth(
          transport: transport,
          store: InMemorySessionStore(),
          nowMs: () => _now);
      final s = await auth.session();
      expect(s.accessToken, 'new');
      expect(spy.paths, <String>['/auth/v1/signup', '/auth/v1/token']);
    } finally {
      await spy.stop();
    }
  });

  test('F4.4: license_activate — الرؤوس والجسم والرد يفكك توكناً', () async {
    final spy = _SpyServer((path, headers, body) {
      if (path == '/auth/v1/signup') {
        return <String, dynamic>{
          'access_token': 'a1',
          'refresh_token': 'r1',
          'expires_in': 3600,
          'user': <String, dynamic>{'id': 'u-1'},
        };
      }
      expect(path, '/functions/v1/license_activate');
      expect(headers['authorization'], 'Bearer a1');
      expect(body['code'], 'K7M2P-9QW4X-4TR8N');
      expect(body['device_pubkey_b64'], 'QUJD');
      return <String, dynamic>{
        'ok': true,
        'token': <String, dynamic>{'payload': 'cGF5', 'sig': 'c2ln'},
        'server_time_ms': _now,
        'release_id': '2027-v1',
        'expires_at': _now + 30 * 86400000,
        'hard_deadline': 1835904000000,
        'devices_used': 1,
        'activated_now': true,
      };
    });
    final base = await spy.start();
    try {
      final transport = SupabaseTransport(baseUrl: base, anonKey: 'test-key');
      final api = ActivationApi(
          transport: transport,
          auth: AnonymousAuth(
              transport: transport,
              store: InMemorySessionStore(),
              nowMs: () => _now));
      final r = await api.activate('K7M2P-9QW4X-4TR8N', 'QUJD', 'fp123456');
      expect(r.ok, true);
      expect(r.token?.payloadB64, 'cGF5');
      expect(r.token?.sigB64, 'c2ln');
      expect(r.devicesUsed, 1);
    } finally {
      await spy.stop();
    }
  });

  test('F4.4: رفض منطقي (409 حدّ الجهازين) يُحسب محاولة — و500 لا يُحسب',
      () async {
    var status = 409;
    final spy = _SpyServer((path, headers, body) {
      if (path == '/auth/v1/signup') {
        return <String, dynamic>{
          'access_token': 'a1',
          'refresh_token': 'r1',
          'expires_in': 3600,
          'user': <String, dynamic>{'id': 'u-1'},
        };
      }
      return <String, dynamic>{
        ':status': status,
        'ok': false,
        'error': status == 409 ? 'ACT_DEVICE_LIMIT' : 'INTERNAL',
      };
    });
    final base = await spy.start();
    try {
      final transport = SupabaseTransport(baseUrl: base, anonKey: 'test-key');
      final api = ActivationApi(
          transport: transport,
          auth: AnonymousAuth(
              transport: transport,
              store: InMemorySessionStore(),
              nowMs: () => _now));
      final r409 = await api.activate('K7M2P-9QW4X-4TR8N', 'QUJD', 'fp123456');
      expect(r409.countsAsAttempt, true);
      expect(r409.errorAr, contains('جهازين'));
      status = 500;
      final r500 = await api.activate('K7M2P-9QW4X-4TR8N', 'QUJD', 'fp123456');
      expect(r500.countsAsAttempt, false);
    } finally {
      await spy.stop();
    }
  });

  test('F4.5: verify_xp_events — القبول يفكك synced_up_to والجسم مطابق',
      () async {
    final spy = _SpyServer((path, headers, body) {
      if (path == '/auth/v1/signup') {
        return <String, dynamic>{
          'access_token': 'a1',
          'refresh_token': 'r1',
          'expires_in': 3600,
          'user': <String, dynamic>{'id': 'u-1'},
        };
      }
      expect(path, '/functions/v1/verify_xp_events');
      expect(body['device_pubkey_b64'], 'QUJD');
      expect(body['last_synced_seq'], 0);
      expect((body['events'] as List).first['seq'], 1);
      return <String, dynamic>{
        'accepted': true,
        'synced_up_to': 7,
        'server_time_ms': 999,
      };
    });
    final base = await spy.start();
    try {
      final transport = SupabaseTransport(baseUrl: base, anonKey: 'test-key');
      final api = HttpXpSyncApi(
          transport: transport,
          auth: AnonymousAuth(
              transport: transport,
              store: InMemorySessionStore(),
              nowMs: () => _now));
      final r = await api.verify(SyncRequest(
          devicePubkeyB64: 'QUJD', lastSyncedSeq: 0, events: <XpEvent>[_event()]));
      expect(r.accepted, true);
      expect(r.syncedUpTo, 7);
      expect(r.serverTimeMs, 999);
    } finally {
      await spy.stop();
    }
  });

  test('F4.5: الرفض 422 = SyncResponse موثّق (لا استثناء ⇒ لا backoff انقطاع)',
      () async {
    final spy = _SpyServer((path, headers, body) {
      if (path == '/auth/v1/signup') {
        return <String, dynamic>{
          'access_token': 'a1',
          'refresh_token': 'r1',
          'expires_in': 3600,
          'user': <String, dynamic>{'id': 'u-1'},
        };
      }
      return <String, dynamic>{
        ':status': 422,
        'accepted': false,
        'reason': 'SEQ_GAP',
        'synced_up_to': 2,
      };
    });
    final base = await spy.start();
    try {
      final transport = SupabaseTransport(baseUrl: base, anonKey: 'test-key');
      final api = HttpXpSyncApi(
          transport: transport,
          auth: AnonymousAuth(
              transport: transport,
              store: InMemorySessionStore(),
              nowMs: () => _now));
      final r = await api.verify(SyncRequest(
          devicePubkeyB64: 'QUJD', lastSyncedSeq: 0, events: <XpEvent>[_event()]));
      expect(r.accepted, false);
      expect(r.reason, 'SEQ_GAP');
      expect(r.syncedUpTo, 2);
    } finally {
      await spy.stop();
    }
  });

  testWidgets('F4.4: البوابة بالمسار الحقيقي — توكن سليم ⇒ مرخّص + مخزن محفوظ',
      (tester) async {
    // زوج مفاتيح اختبار — البوابة تفحص به (حقن كامل)
    final priv = ed.newKeyFromSeed(
        Uint8List.fromList(List<int>.generate(32, (i) => i + 1)));
    final pub = ed.public(priv);
    final token = LicenseToken.issue(
      const LicensePayload(
        codeId: 'K7M2P9QW4X4TR8N',
        deviceKeyHash: '',
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
    await tester.pump();

    await tester.enterText(
        find.byType(TextField), 'K7M2P-9QW4X-4TR8N');
    await tester.pump();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pump();

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
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'K7M2P-9QW4X-4TR8N');
    await tester.pump();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pump();
    expect((await store.load()).failures, 1);

    await tester.pumpWidget(MaterialApp(
        home: ActivationGate(
      licenseStore: store,
      onModeSet: () {},
      devicePubkeyB64: 'QUJDREVGR0g=',
      activationApi: _StaticActivationApi(const ActivationAttempt(
          ok: false, errorAr: 'انقطع الاتصال', countsAsAttempt: false)),
    )));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'K7M2P-9QW4X-4TR8N');
    await tester.pump();
    await tester.tap(find.text('تفعيل ✓'));
    await tester.pump();
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
