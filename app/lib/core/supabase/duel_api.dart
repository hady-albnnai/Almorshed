// ═══════════════════════════════════════════════════════════════════════
// duel_api.dart — قراءات وكتابات المبارزات عبر PostgREST+Edge (M5/F5.1+F5.2).
// العقد: docs/16 §٦. كل الكتابات عبر RLS (لا service_role هنا) — والزناد
// duels_guard يمنع لمس أعمدة الحكم. duel_finish يقرر النتيجة حصراً.
// ═══════════════════════════════════════════════════════════════════════
import 'supabase_transport.dart';

/// صف مبارزة كما يعود من القاعدة (مختصر ما تحتاجه الواجهة).
class DuelRow {
  const DuelRow({
    required this.id,
    required this.roomCode,
    required this.seed,
    required this.status,
    required this.scopeJson,
    this.hostDevice,
    this.guestDevice,
    this.hostName,
    this.guestName,
    this.hostScore,
    this.guestScore,
    this.winnerDevice,
  });

  final String id;
  final String roomCode;
  final int seed;
  final String status;
  final Map<String, dynamic> scopeJson;
  final String? hostDevice;
  final String? guestDevice;
  final String? hostName;
  final String? guestName;
  final int? hostScore;
  final int? guestScore;
  final String? winnerDevice;

  static DuelRow fromJson(Map<String, dynamic> j) => DuelRow(
        id: j['id'] as String,
        roomCode: j['room_code'] as String,
        seed: (j['seed'] as num).toInt(),
        status: j['status'] as String,
        scopeJson: (j['scope'] as Map<String, dynamic>?) ?? const {},
        hostDevice: j['host_device'] as String?,
        guestDevice: j['guest_device'] as String?,
        hostName: j['host_name'] as String?,
        guestName: j['guest_name'] as String?,
        hostScore: (j['host_score'] as num?)?.toInt(),
        guestScore: (j['guest_score'] as num?)?.toInt(),
        winnerDevice: j['winner_device'] as String?,
      );
}

/// نتيجة الحكم الخادمي (duel_finish).
class DuelVerdict {
  const DuelVerdict({
    required this.hostScore,
    required this.guestScore,
    required this.winnerDevice,
    required this.already,
    required this.myDevice,
    this.corrects = const [],
  });

  final int hostScore;
  final int guestScore;
  final String winnerDevice;
  final bool already; // أُقفلت بنداء سابق
  final String myDevice;
  final List<int> corrects; // الصحيح بالعرض لكل موضع (ترتيب الجلسة)
}

class DuelApi {
  DuelApi(this._transport);

  final SupabaseTransport _transport;

  Map<String, String> _authHeaders(String accessToken) => <String, String>{
        'Authorization': 'Bearer $accessToken',
        'apikey': _transport.anonKey,
      };

  static const String _duelsSelect = 'id,room_code,seed,status,scope,'
      'host_device,guest_device,host_name,guest_name,host_score,guest_score,'
      'winner_device';

  /// جهازي من المفتاح العام — uuid محلي (RLS: جهازي حصراً).
  Future<String?> myDeviceId({
    required String accessToken,
    required String pubkeyB64,
  }) async {
    final rows = await _transport.getJson(
      '${_transport.baseUrl}/rest/v1/devices?pubkey_b64=eq.$pubkeyB64&select=id',
      _authHeaders(accessToken),
    ) as List<dynamic>;
    if (rows.isEmpty) return null;
    return (rows.first as Map<String, dynamic>)['id'] as String;
  }

  /// إنشاء مبارزة (المضيف) — لوبي فارغ برمز غرفة.
  Future<DuelRow> createDuel({
    required String accessToken,
    required String roomCode,
    required int seed,
    required Map<String, dynamic> scopeJson,
    required String hostDevice,
    required String hostName,
  }) async {
    final rows = await _transport.postJsonRaw(
      '${_transport.baseUrl}/rest/v1/duels',
      <String, dynamic>{
        'room_code': roomCode,
        'seed': seed,
        'scope': scopeJson,
        'host_device': hostDevice,
        'host_name': hostName,
      },
      {
        ..._authHeaders(accessToken),
        'Prefer': 'return=representation',
      },
    ) as List<dynamic>;
    return DuelRow.fromJson(rows.first as Map<String, dynamic>);
  }

  /// لوبي برمز الغرفة — null إن لم يوجد.
  Future<DuelRow?> findLobbyDuel({
    required String accessToken,
    required String roomCode,
  }) async {
    final rows = await _transport.getJson(
      '${_transport.baseUrl}/rest/v1/duels?room_code=eq.$roomCode'
      '&status=eq.lobby&select=$_duelsSelect',
      _authHeaders(accessToken),
    ) as List<dynamic>;
    if (rows.isEmpty) return null;
    return DuelRow.fromJson(rows.first as Map<String, dynamic>);
  }

  /// جلوس الضيف — الزناد يمنع الممتلئ وغير الجهاز (DUEL_FULL/DUEL_NOT_YOURS).
  Future<DuelRow> joinAsGuest({
    required String accessToken,
    required String duelId,
    required String guestDevice,
    required String guestName,
  }) async {
    final rows = await _transport.patchJson(
      '${_transport.baseUrl}/rest/v1/duels?id=eq.$duelId',
      <String, dynamic>{'guest_device': guestDevice, 'guest_name': guestName},
      {
        ..._authHeaders(accessToken),
        'Prefer': 'return=representation',
      },
    ) as List<dynamic>;
    return DuelRow.fromJson(rows.first as Map<String, dynamic>);
  }

  /// بدء المضيف — الزناد يسمح له حصراً ومن لوبي فيه الضيف.
  Future<void> startDuel({
    required String accessToken,
    required String duelId,
  }) async {
    await _transport.patchJson(
      '${_transport.baseUrl}/rest/v1/duels?id=eq.$duelId',
      <String, dynamic>{
        'status': 'live',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      },
      _authHeaders(accessToken),
    );
  }

  /// قراءة مبارزة بالمعرف (استطلاع اللوبي/الحالة).
  Future<DuelRow> fetchDuel({
    required String accessToken,
    required String duelId,
  }) async {
    final rows = await _transport.getJson(
      '${_transport.baseUrl}/rest/v1/duels?id=eq.$duelId&select=$_duelsSelect',
      _authHeaders(accessToken),
    ) as List<dynamic>;
    if (rows.isEmpty) {
      throw const TransportException(404, 'NO_DUEL');
    }
    return DuelRow.fromJson(rows.first as Map<String, dynamic>);
  }

  /// تسجيل إجابة — الحقيقة المخزنة التي يصحح عليها الخادم.
  Future<void> insertAnswer({
    required String accessToken,
    required String duelId,
    required String deviceId,
    required int qIndex,
    required int chosen,
  }) async {
    await _transport.postJson(
      '${_transport.baseUrl}/rest/v1/duel_answers',
      <String, dynamic>{
        'duel_id': duelId,
        'device_id': deviceId,
        'q_index': qIndex,
        'chosen': chosen,
      },
      {
        ..._authHeaders(accessToken),
        'Prefer': 'return=minimal',
      },
    );
  }

  /// إعلان «أنهيتُ» — شرط إقفال الحكم.
  Future<void> markDone({
    required String accessToken,
    required String duelId,
    required String deviceId,
  }) async {
    await _transport.postJson(
      '${_transport.baseUrl}/rest/v1/duel_status',
      <String, dynamic>{'duel_id': duelId, 'device_id': deviceId},
      {
        ..._authHeaders(accessToken),
        'Prefer': 'return=minimal',
      },
    );
  }

  /// الحكم الخادمي — يعيد النتيجة أو يرمي TransportException بالسبب.
  Future<DuelVerdict> finish({
    required String accessToken,
    required String duelId,
    required String myDevice,
  }) async {
    final r = await _transport.postJson(
      '${_transport.baseUrl}/functions/v1/duel_finish',
      <String, dynamic>{'duel_id': duelId},
      _authHeaders(accessToken),
    );
    if (r['ok'] != true) {
      throw TransportException(422, (r['reason'] ?? 'REJECTED').toString(),
          body: r);
    }
    return DuelVerdict(
      hostScore: (r['host_score'] as num).toInt(),
      guestScore: (r['guest_score'] as num).toInt(),
      winnerDevice: r['winner_device'] as String,
      already: r['already'] == true,
      myDevice: myDevice,
      corrects: [
        for (final c in (r['corrects'] as List<dynamic>? ?? const []))
          (c as num).toInt()
      ],
    );
  }
}
