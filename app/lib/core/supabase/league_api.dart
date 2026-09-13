// ═════════════════════════════════════════════════════════════════════
// F4.6 — عميل الدوري: قراءتان بـRLS (جهازي ثم ترتيب أحدث أسبوع) وتجميع
// العرض محلياً. بلا هويات — أرقام وترتيب حصراً (docs/12: «نيوكليوس»).
// الرفض 401/403 (غير مفعّل) يصعد TransportException للشاشة برسالة لطيفة.
// ═════════════════════════════════════════════════════════════════════
import 'anonymous_auth.dart';
import 'supabase_transport.dart';

/// صف ترتيب واحد بمجموعتي.
class LeagueRow {
  const LeagueRow({required this.rank, required this.xp, required this.isMe});

  final int rank;
  final int xp;
  final bool isMe;
}

/// لقطة الدوري الجاهزة للعرض.
class LeagueView {
  const LeagueView({
    required this.isoWeek,
    required this.groupNo,
    required this.rows,
    this.myRank,
  });

  final int isoWeek; // 0 = لا ترتيب بعد (أول إقفال لم يحدث)
  final int groupNo; // 0 = لست ضمن ترتيب هذا الأسبوع (لا XP مُودَّع)
  final List<LeagueRow> rows;
  final int? myRank;

  bool get isEmpty => isoWeek == 0 || rows.isEmpty;
}

class LeagueApi {
  LeagueApi({required this.transport, required this.auth});

  final SupabaseTransport transport;
  final AnonymousAuth auth;

  Future<LeagueView> fetch(String devicePubkeyB64) async {
    final session = await auth.session();
    Future<dynamic> get(String path, String query) => transport.getJson(
          '${transport.baseUrl}$path?$query',
          <String, String>{
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${session.accessToken}',
            'Accept': 'application/json',
          },
        );

    // ١) جهازي (RLS: أرى أجهزتي حصراً)
    final me = await get('/rest/v1/devices',
        'select=id&pubkey_b64=eq.${Uri.encodeComponent(devicePubkeyB64)}');
    final meList = me as List<dynamic>;
    if (meList.isEmpty) {
      throw const TransportException(404, 'DEVICE_UNKNOWN');
    }
    final myId = (meList.first as Map<String, dynamic>)['id'] as String;

    // ٢) ترتيب أحدث أسبوع (RLS: المفعّلون يقرؤون الكل — بلا هويات)
    final raw = await get('/rest/v1/league_standings',
        'select=iso_week,group_no,rank_no,device_id,xp'
        '&order=iso_week.desc,rank_no.asc&limit=300');
    final rows = raw as List<dynamic>;
    if (rows.isEmpty) return const LeagueView(isoWeek: 0, groupNo: 0, rows: []);

    final latestWeek = (rows.first as Map<String, dynamic>)['iso_week'] as int;
    final weekRows = rows
        .map((e) => e as Map<String, dynamic>)
        .where((r) => r['iso_week'] == latestWeek)
        .toList();
    final mine = weekRows.where((r) => r['device_id'] == myId).toList();
    if (mine.isEmpty) {
      return LeagueView(isoWeek: latestWeek, groupNo: 0, rows: const []);
    }
    final myGroup = mine.first['group_no'] as int;
    final groupRows = weekRows
        .where((r) => r['group_no'] == myGroup)
        .map((r) => LeagueRow(
              rank: r['rank_no'] as int,
              xp: r['xp'] as int,
              isMe: r['device_id'] == myId,
            ))
        .toList();
    return LeagueView(
      isoWeek: latestWeek,
      groupNo: myGroup,
      rows: groupRows,
      myRank: mine.first['rank_no'] as int,
    );
  }
}
