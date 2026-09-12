// ═════════════════════════════════════════════════════════════════════
// F4.5/F4.4 — verify_xp_events: تحقق سلسلة XP وإيداعها في الدوري
// العقد الكامل: docs/16-SERVER-CONTRACT.md §٤ — اقرأه قبل أي تعديل.
// القاعدة الحاكمة (docs/12 §٨-4): أي خلل = رفض ١٠٠٪ — فجوة، هاش،
// توقيع، نوع مجهول، نقاط مخالفة، تكرار سقف. الرفض لا يودّع شيئاً.
// ═════════════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';
import nacl from 'npm:tweetnacl@1.0.3';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

const encoder = new TextEncoder();
const MAX_BATCH = 500;

const hexToBytes = (hex: string): Uint8Array => {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
};
const b64ToBytes = (b64: string): Uint8Array =>
  Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
const sha256Hex = async (s: string): Promise<string> =>
  [...new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(s)))]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

// ── أنواع XP العشرة — docs/12 §٤.١ (نقاط/سقف مرة-يوم) ──
// capped: يُمنع تكرار (type + payload.dateKey) لكل جهاز — العقد §٤.٥
const CAPPED: Record<string, number> = {
  batchDone: 15,
  mistakesFive: 10,
  lessonNew: 10,
  streakDay: 10,
  queueDone: 15,
  labChallenge: 10,
};
const UNLIMITED: Record<string, number> = {
  cardReview: 1,
  duelWin: 45,
  duelLoss: 15,
};
// manual: نقاط مخصصة ١..١٠٠٠ + سبب إلزامي

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ accepted: false, reason: 'METHOD' }, 405);

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const body = await req.json();
    const pubkeyB64 = String(body.device_pubkey_b64 ?? '');
    const events = Array.isArray(body.events) ? body.events : [];
    if (!/^[A-Za-z0-9+/]{43}=$/.test(pubkeyB64))
      return json({ accepted: false, reason: 'PUBKEY_FORMAT' }, 422);
    if (events.length === 0)
      return json({ accepted: true, synced_up_to: body.last_synced_seq ?? 0,
        server_time_ms: Date.now() });
    if (events.length > MAX_BATCH)
      return json({ accepted: false, reason: 'BATCH_TOO_LARGE' }, 413);

    // ── ١) الجهاز من القاعدة (لا ثقة بالادعاء) ──
    const { data: st, error: stErr } = await admin
      .rpc('device_state_for_verify', { p_pubkey_b64: pubkeyB64 })
      .single();
    if (stErr || !st)
      return json({ accepted: false, reason: 'DEVICE_UNKNOWN' }, 404);
    const deviceId = st.device_id as string;
    const pubkey = b64ToBytes(st.pubkey_b64 as string);
    let lastSeq = st.last_seq as number;
    let lastHash = (st.last_hash as string | null) ?? 'GENESIS';

    // ── ٢) التحقق المتسلسل — كل الخطوات لكل حدث بالترتيب (العقد §٤.٤) ──
    const accepted: Record<string, unknown>[] = [];
    const seenCaps = new Set<string>();
    for (const ev of events) {
      lastSeq++;
      // ٢-أ التسلسل بلا فجوات
      if (ev.seq !== lastSeq)
        return json({ accepted: false, reason: 'SEQ_GAP',
          synced_up_to: lastSeq - 1 }, 422);
      // ٢-ب الرابط
      if (ev.prevHash !== lastHash)
        return json({ accepted: false, reason: 'CHAIN_BREAK',
          synced_up_to: lastSeq - 1 }, 422);
      // ٢-ج الهاش — canonical كما ورد حرفياً (لا إعادة بناء للحمولة!)
      const core = JSON.stringify({
        seq: ev.seq, type: ev.type, ts: ev.ts,
        payload: ev.payload, prevHash: ev.prevHash,
      });
      const expected = await sha256Hex(ev.prevHash + core);
      if (expected !== ev.hash)
        return json({ accepted: false, reason: 'HASH_MISMATCH',
          synced_up_to: lastSeq - 1 }, 422);
      // ٢-د التوقيع بمفتاح الجهاز المسجل
      const ok = nacl.sign.detached.verify(
        hexToBytes(ev.hash), b64ToBytes(ev.sig), pubkey);
      if (!ok)
        return json({ accepted: false, reason: 'BAD_SIGNATURE',
          synced_up_to: lastSeq - 1 }, 422);
      // ٢-هـ النوع والنقاط
      const type: string = ev.type;
      const points = ev.payload?.points;
      if (type in CAPPED) {
        if (points !== CAPPED[type])
          return json({ accepted: false,
            reason: `POINTS_MISMATCH:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
        const dk = ev.payload?.dateKey;
        if (typeof dk !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(dk))
          return json({ accepted: false, reason: 'DATEKEY_FORMAT',
            synced_up_to: lastSeq - 1 }, 422);
        // السقف اليومي: ضد القاعدة + ضد الدفعة الحالية (العقد §٤.٥)
        const key = `${type}:${dk}`;
        if (seenCaps.has(key))
          return json({ accepted: false, reason: `DUP_CAP:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
        const { count } = await admin
          .from('xp_events')
          .select('seq', { count: 'exact', head: true })
          .eq('device_id', deviceId)
          .eq('type', type)
          .eq('payload->>dateKey', dk);
        if ((count ?? 0) > 0)
          return json({ accepted: false, reason: `DUP_CAP_DB:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
        seenCaps.add(key);
      } else if (type in UNLIMITED) {
        if (points !== UNLIMITED[type])
          return json({ accepted: false,
            reason: `POINTS_MISMATCH:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
      } else if (type === 'manual') {
        if (!Number.isInteger(points) || points < 1 || points > 1000)
          return json({ accepted: false, reason: 'MANUAL_POINTS_RANGE',
            synced_up_to: lastSeq - 1 }, 422);
        if (typeof ev.payload?.reason !== 'string' ||
            ev.payload.reason.trim().length === 0)
          return json({ accepted: false, reason: 'MANUAL_REASON',
            synced_up_to: lastSeq - 1 }, 422);
      } else {
        return json({ accepted: false, reason: 'UNKNOWN_TYPE',
          synced_up_to: lastSeq - 1 }, 422);
      }
      accepted.push(ev);
    }

    // ── ٣) الإيداع الذري (إعادة فحص الاستمرارية داخل المعاملة) ──
    const serverTimeMs = Date.now();
    const { data: committed, error: commitErr } = await admin.rpc('verify_commit', {
      p_device: deviceId,
      p_events: accepted,
      p_expect_last_seq: lastSeq - accepted.length,
      p_expect_last_hash: lastHash,
      p_server_ms: serverTimeMs,
    });
    if (commitErr) {
      const gap = commitErr.message.includes('VZ_GAP');
      return json({
        accepted: false,
        reason: gap ? 'SEQ_GAP' : 'COMMIT_INTERNAL',
        synced_up_to: lastSeq - accepted.length,
        detail: gap ? undefined : commitErr.message,
      }, gap ? 422 : 500);
    }
    return json({
      accepted: true,
      synced_up_to: committed.synced_up_to,
      server_time_ms: serverTimeMs,
    });
  } catch (e) {
    return json({ accepted: false, reason: 'INTERNAL', detail: String(e) }, 500);
  }
});
