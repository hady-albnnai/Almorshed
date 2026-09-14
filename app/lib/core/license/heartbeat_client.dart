// ═══════════════════════════════════════════════════════════════════════
// heartbeat_client.dart — F7.4 (قسم الكود): نبض الترخيص + كشف عبث الساعة.
// العقد: docs/16 §٣ (heartbeat) + docs/11 §٥ (التجديد الصامت) + L4.
//
// ماذا يفعل (عند كل انطلاق وعند أي اتصال ناجح — صامتاً):
//  ١) يرسل المفتاح العام + ساعة الجهاز إلى heartbeat.
//  ٢) يستقبل زمن السيرفر ⇒ يرفع «أرضية الساعة الرتيبة» lastWallMs — فلا
//     تعود الساعة خلف آخر زمن معروف من السيرفر (كشف الرجوع L4).
//  ٣) إن أعاد السيرفر توكناً مجدَّداً (آخر ٧ أيام من الإيجار) — يتحقق منه
//     محلياً بمفتاح المالك العام + ربط الجهاز قبل حفظه (لا ثقة عمياء).
//  ٤) clock_suspected من السيرفر = حكمه النهائي؛ يُعرض للمستخدم فقط.
//
// حدود مقصودة: بلا نت ⇒ لا شيء يتغيّر (الترخيص المحلي يبقى سيّد الموقف
// حتى انتهائه)؛ أي فشل شبكة يُبتلع — النبض ليس بوابة.
// ═══════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import '../supabase/anonymous_auth.dart';
import '../supabase/supabase_transport.dart';
import 'license_core.dart';
import 'license_store.dart';

/// نتيجة نبضة واحدة — للعرض والاختبار.
class HeartbeatOutcome {
  const HeartbeatOutcome({
    required this.reached,
    this.renewed = false,
    this.clockSuspected = false,
    this.serverTimeMs = 0,
    this.error = '',
  });

  /// وصلنا للسيرفر ورد بـ ok (بغض النظر عن التجديد).
  final bool reached;
  final bool renewed;
  final bool clockSuspected;
  final int serverTimeMs;
  final String error;

  static const offline = HeartbeatOutcome(reached: false, error: 'offline');
}

/// المنطق الخالص (بلا شبكة) — يُختبر وحده: ماذا نفعل بردّ heartbeat؟
/// يعيد البيانات المحدثة أو null إن لم يتغير شيء يستحق الحفظ.
LicenseData? applyHeartbeatResponse(
  LicenseData data,
  Map<String, dynamic> r, {
  required Uint8List? devicePubkeyBytes,
  ed.PublicKey? key, // للاختبارات — الإنتاج: مفتاح المالك المضمّن
}) {
  final serverMs = (r['server_time_ms'] as num?)?.toInt() ?? 0;
  if (serverMs <= 0) return null;

  var updated = data;
  // ١) الأرضية الرتيبة: لا تتراجع أبداً (max)
  if (serverMs > data.lastWallMs) {
    updated = updated.copyWith(lastWallMs: serverMs);
  }

  // ٢) توكن مجدَّد — يُقبل فقط إن اجتاز التحقق المحلي كاملاً
  final tokenJson = r['token'];
  if (tokenJson is Map<String, dynamic>) {
    final payload = tokenJson['payload'];
    final sig = tokenJson['sig'];
    if (payload is String && sig is String) {
      final candidate = LicenseToken(payloadB64: payload, sigB64: sig);
      final check = checkLicense(
        candidate,
        nowMs: serverMs,
        key: key,
        devicePubkeyBytes: devicePubkeyBytes,
      );
      if (check.ok) {
        updated = updated.copyWith(
          mode: LicenseMode.licensed,
          token: candidate,
        );
      }
      // توكن مرفوض (توقيع/جهاز آخر/منتهٍ) ⇒ يُهمل صامتاً — القديم يبقى
    }
  }
  return identical(updated, data) ? null : updated;
}

/// نبض الترخيص الفعلي — يُستدعى من التطبيق عند الانطلاق ودورياً.
class HeartbeatClient {
  HeartbeatClient({
    required this.transport,
    required this.auth,
    required this.store,
    required this.devicePubkeyB64,
  });

  final SupabaseTransport transport;
  final AnonymousAuth auth;
  final LicenseStore store;
  final String devicePubkeyB64;

  /// أدنى فاصل بين نبضتين (لا نطرق السيرفر بكل إعادة بناء للشاشة).
  static const minInterval = Duration(hours: 6);
  int _lastBeatMs = 0;

  Future<HeartbeatOutcome> beat({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastBeatMs < minInterval.inMilliseconds) {
      return const HeartbeatOutcome(reached: false, error: 'throttled');
    }
    if (devicePubkeyB64.isEmpty) return HeartbeatOutcome.offline;

    final data = await store.load();
    // بلا ترخيص ⇒ لا نبض (لا جهاز مسجّل أصلاً)
    if (data.mode != LicenseMode.licensed || data.token == null) {
      return const HeartbeatOutcome(reached: false, error: 'unlicensed');
    }

    var session = await auth.session();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await transport.callFunction('heartbeat', <String, dynamic>{
          'device_pubkey_b64': devicePubkeyB64,
          'client_now_ms': now,
        }, accessToken: session.accessToken);
        _lastBeatMs = now;
        final updated = applyHeartbeatResponse(
          data,
          r,
          devicePubkeyBytes: base64Decode(devicePubkeyB64),
        );
        if (updated != null) await store.save(updated);
        return HeartbeatOutcome(
          reached: r['ok'] == true,
          renewed: r['renewed'] == true,
          clockSuspected: r['clock_suspected'] == true,
          serverTimeMs: (r['server_time_ms'] as num?)?.toInt() ?? 0,
        );
      } on TransportException catch (e) {
        if (e.status == 401 && attempt == 0) {
          session = await auth.session(forceNew: true);
          continue;
        }
        return HeartbeatOutcome(reached: false, error: e.message);
      } catch (e) {
        return HeartbeatOutcome(reached: false, error: e.toString());
      }
    }
    return HeartbeatOutcome.offline;
  }
}
