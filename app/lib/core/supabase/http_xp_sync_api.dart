// ═════════════════════════════════════════════════════════════════════
// F4.5 عميل — XpSyncApi الحقيقية فوق verify_xp_events (العقد §٤).
// الفروقات الحاكمة عن الزيف: رفض 422 من الخادم = SyncResponse(accepted:false)
// (المحرك يجمّد بالـbackoff ولا يلمس السلاسل) — أما انقطاع الشبكة فيُرمى
// استثناءً فيلتقطه المحرك كـoffline (ميّزه docs/14: رفضٌ ≠ انقطاع).
// ═════════════════════════════════════════════════════════════════════
import '../sync/sync_engine.dart';
import 'anonymous_auth.dart';
import 'supabase_transport.dart';

class HttpXpSyncApi implements XpSyncApi {
  HttpXpSyncApi({required this.transport, required this.auth});

  final SupabaseTransport transport;
  final AnonymousAuth auth;

  @override
  Future<SyncResponse> verify(SyncRequest request) async {
    final session = await auth.session();
    final body = <String, dynamic>{
      'device_pubkey_b64': request.devicePubkeyB64,
      'last_synced_seq': request.lastSyncedSeq,
      'events': <Map<String, dynamic>>[
        for (final e in request.events) e.toJson(),
      ],
    };
    try {
      final r = await transport.callFunction('verify_xp_events', body,
          accessToken: session.accessToken);
      return SyncResponse(
        accepted: r['accepted'] == true,
        syncedUpTo: (r['synced_up_to'] as num?)?.toInt() ?? 0,
        serverTimeMs: (r['server_time_ms'] as num?)?.toInt() ?? 0,
        reason: r['reason'] as String? ?? '',
      );
    } on TransportException catch (e) {
      if (e.status == 422) {
        // رفض منطقي موثّق — الجسم يحمل accepted:false + reason (العقد §٤.٣)
        return SyncResponse(
          accepted: false,
          syncedUpTo: (e.body['synced_up_to'] as num?)?.toInt() ?? 0,
          reason: (e.body['reason'] as String?) ?? e.message,
        );
      }
      rethrow; // انقطاع/خادم — المحرك يعاملها offline بbackoff
    }
  }
}
