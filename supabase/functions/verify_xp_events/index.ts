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

// ═══ جدول النقاط — قرار ٦٠ (اقتصاد النقاط) ═══════════════════════════
// ⚠️ يجب أن يطابق app/lib/core/xp/xp_ledger.dart حرفياً. أي اختلاف في رقم
// ⇒ رفض الدفعة كلها (POINTS_MISMATCH). القاعدة الحاكمة: «التحديات هي الفاصل».
//
// نقاط التعلّم: شخصية، بلا سقف، بلا جوائز، ولا تُحسب في الترتيب الأسبوعي
// (league_rollup يقرأ أنواع arena فقط — هجرة 0009). الغش فيها يضر صاحبها.
const TRAINING: Record<string, number> = {
  batchDone: 15,
  mistakesFive: 10,
  lessonNew: 0, // قراءة الدرس = ٠ نقطة (علامة ✓ فقط)
  cardReview: 1,
  queueDone: 15,
  labChallenge: 10,
};
// السلسلة اليومية وحدها «مرة/يوم» — بحكم تعريفها، لا لمنع تكرار نشاط.
const CAPPED: Record<string, number> = { streakDay: 10 };

// ── التحديات — النقاط التناقصية مع الزمن (قرار ٦٠) ──
// نفس الثوابت ونفس الدالة في app/lib/core/xp/challenge_points.dart حرفياً:
//   elapsed >= budget  ⇒  0        (انتهى الوقت بلا إجابة = بلا نقاط)
//   غير ذلك            ⇒  min + (base − min) × (budget − elapsed) ÷ budget
// القسمة مقطوعة نحو الصفر طرفياً (Math.trunc ⇄ `~/`) والقيم موجبة ⇒ تطابق بتّي.
const CHALLENGE_KINDS: Record<
  string,
  { base: number; min: number; budget: number }
> = {
  mcq: { base: 12, min: 4, budget: 22000 }, // اختياري — ٢٢ ث (نطاق ٢٠–٢٥)
  step: { base: 18, min: 6, budget: 40000 }, // خطوة مسألة (قرار ٦١/أ)
  numeric: { base: 30, min: 10, budget: 90000 }, // مسألة رقمية (قرار ٦١/ب)
};
const challengePoints = (
  base: number,
  min: number,
  budget: number,
  elapsed: number,
): number => {
  if (!Number.isInteger(elapsed) || elapsed < 0 || elapsed >= budget) return 0;
  return min + Math.trunc(((base - min) * (budget - elapsed)) / budget);
};

// المبارزة: الفوز وحده يُكافأ؛ الخسارة صفر (قرار ٦٠).
// الدعوى الخادمية (صف المبارزة/الفائز/٤٨ ساعة/بلا ادعاء مكرر) تبقى داخل
// verify_commit ذرياً (0005) — هذا الفحص طبقة نقاط فقط.
const DUEL_POINTS: Record<string, number> = { duelWin: 45, duelLoss: 0 };

// manual: نقاط مخصصة ١..١٠٠٠ + سبب إلزامي (جائزة الأستاذ)
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

type Admin = ReturnType<typeof createClient>;

/// هل أُنهي هذا التحدي بمغادرة؟ (القرار ٦٠: المغادرة = إنهاء + احتساب،
/// وبعدها يُقفل التحدي فلا تُقبل منه أي نقاط.)
const hasAbandon = async (
  admin: Admin,
  deviceId: string,
  cid: string,
): Promise<boolean> => {
  const { count } = await admin
    .from('xp_events')
    .select('seq', { count: 'exact', head: true })
    .eq('device_id', deviceId)
    .eq('type', 'challengeAbandon')
    .eq('payload->>challengeId', cid);
  return (count ?? 0) > 0;
};

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
    // تحديات أُنهيت بالمغادرة داخل هذه الدفعة نفسها (قبل الإيداع) —
    // فلا تُقبل نقاطها حتى لو وردت بترتيب مقلوب.
    const abandoned = new Set<string>();
    for (const ev of events) {
      lastSeq++;
      // ٢-٠ شكل الحدث: كائن، نوع نصي قصير، حمولة ≤ 2KB (تدقيق الحقن 2026-09-14)
      if (typeof ev !== 'object' || ev === null ||
          typeof ev.type !== 'string' || !/^[a-zA-Z]{2,32}$/.test(ev.type) ||
          typeof ev.seq !== 'number' || typeof ev.ts !== 'number' ||
          typeof ev.prevHash !== 'string' || typeof ev.hash !== 'string' ||
          typeof ev.sig !== 'string' ||
          JSON.stringify(ev.payload ?? null).length > 2048)
        return json({ accepted: false, reason: 'EVENT_SHAPE',
          synced_up_to: lastSeq - 1 }, 422);
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
      // ٢-هـ النوع والنقاط (قرار ٦٠ — التحديات هي الفاصل)
      const type: string = ev.type;
      const points = ev.payload?.points;
      if (type in CAPPED) {
        // السلسلة اليومية — مرة/يوم بحكم تعريفها
        if (points !== CAPPED[type])
          return json({ accepted: false, reason: `POINTS_MISMATCH:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
        const dk = ev.payload?.dateKey;
        if (typeof dk !== 'string' || !DATE_RE.test(dk))
          return json({ accepted: false, reason: 'DATEKEY_FORMAT',
            synced_up_to: lastSeq - 1 }, 422);
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
      } else if (type in TRAINING) {
        // نقاط تعلّم شخصية — بلا سقف (الغش فيها يضر صاحبها فقط)
        if (points !== TRAINING[type])
          return json({ accepted: false, reason: `POINTS_MISMATCH:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
      } else if (type === 'challengeQ') {
        // إجابة صحيحة داخل تحدي اليوم — النقاط تناقصية مع الزمن
        const kind = typeof ev.payload?.qType === 'string'
          ? CHALLENGE_KINDS[ev.payload.qType]
          : undefined;
        if (!kind)
          return json({ accepted: false, reason: 'CHALLENGE_KIND',
            synced_up_to: lastSeq - 1 }, 422);
        const cid = ev.payload?.challengeId;
        if (typeof cid !== 'string' || !UUID_RE.test(cid))
          return json({ accepted: false, reason: 'CHALLENGE_ID_FORMAT',
            synced_up_to: lastSeq - 1 }, 422);
        const qi = ev.payload?.qIndex;
        if (!Number.isInteger(qi) || qi < 0 || qi > 49)
          return json({ accepted: false, reason: 'CHALLENGE_QINDEX',
            synced_up_to: lastSeq - 1 }, 422);
        const el = ev.payload?.elapsedMs;
        if (!Number.isInteger(el) || el < 0 || el > kind.budget)
          return json({ accepted: false, reason: 'CHALLENGE_ELAPSED',
            synced_up_to: lastSeq - 1 }, 422);
        // النقاط من الدالة الحتمية — لا ثقة برقم الجهاز
        if (points !== challengePoints(kind.base, kind.min, kind.budget, el))
          return json({ accepted: false, reason: 'POINTS_MISMATCH:challengeQ',
            synced_up_to: lastSeq - 1 }, 422);
        // المغادرة أنهت التحدي ⇒ مُقفل: لا نقاط بعدها (قرار ٦٠)
        if (abandoned.has(cid) || (await hasAbandon(admin, deviceId, cid)))
          return json({ accepted: false, reason: 'CHALLENGE_CLOSED',
            synced_up_to: lastSeq - 1 }, 422);
        // كل سؤال مرة واحدة لكل تحدي (ضد القاعدة وضد الدفعة)
        const key = `q:${cid}:${qi}`;
        if (seenCaps.has(key))
          return json({ accepted: false, reason: 'DUP_CAP:challengeQ',
            synced_up_to: lastSeq - 1 }, 422);
        const { count } = await admin
          .from('xp_events')
          .select('seq', { count: 'exact', head: true })
          .eq('device_id', deviceId)
          .eq('type', 'challengeQ')
          .eq('payload->>challengeId', cid)
          .eq('payload->>qIndex', String(qi));
        if ((count ?? 0) > 0)
          return json({ accepted: false, reason: 'DUP_CAP_DB:challengeQ',
            synced_up_to: lastSeq - 1 }, 422);
        seenCaps.add(key);
      } else if (type === 'challengeAbandon') {
        // إنهاء التحدي بمغادرة التطبيق — ٠ نقطة ويُقفل التحدي
        const cid = ev.payload?.challengeId;
        if (typeof cid !== 'string' || !UUID_RE.test(cid))
          return json({ accepted: false, reason: 'CHALLENGE_ID_FORMAT',
            synced_up_to: lastSeq - 1 }, 422);
        const why = ev.payload?.reason;
        if (typeof why !== 'string' || why.length === 0 || why.length > 100)
          return json({ accepted: false, reason: 'CHALLENGE_REASON',
            synced_up_to: lastSeq - 1 }, 422);
        if (points !== 0)
          return json({ accepted: false,
            reason: 'POINTS_MISMATCH:challengeAbandon',
            synced_up_to: lastSeq - 1 }, 422);
        if (abandoned.has(cid))
          return json({ accepted: false, reason: 'DUP_CAP:challengeAbandon',
            synced_up_to: lastSeq - 1 }, 422);
        abandoned.add(cid);
      } else if (type === 'duelWin' || type === 'duelLoss') {
        // القرار ٦٠: الفوز وحده يُكافأ؛ الخسارة صفر
        if (points !== DUEL_POINTS[type])
          return json({ accepted: false, reason: `POINTS_MISMATCH:${type}`,
            synced_up_to: lastSeq - 1 }, 422);
        const duelId = ev.payload?.duelId;
        if (typeof duelId !== 'string' || !UUID_RE.test(duelId))
          return json({ accepted: false, reason: 'DUEL_ID_FORMAT',
            synced_up_to: lastSeq - 1 }, 422);
        // مفتاح اليوم لازم لقاعدة «الخصم نفسه مرة/يوم» — تُطبَّق خادمياً
        // داخل verify_commit (هجرة 0009) لأن الخصم يُقرأ من صف المبارزة
        // نفسه، لا من ادعاء الجهاز (لا ثقة بالحمولة في قرار النقاط).
        const dk = ev.payload?.dateKey;
        if (typeof dk !== 'string' || !DATE_RE.test(dk))
          return json({ accepted: false, reason: 'DATEKEY_FORMAT',
            synced_up_to: lastSeq - 1 }, 422);
      } else if (type === 'manual') {
        if (!Number.isInteger(points) || points < 1 || points > 1000)
          return json({ accepted: false, reason: 'MANUAL_POINTS_RANGE',
            synced_up_to: lastSeq - 1 }, 422);
        if (typeof ev.payload?.reason !== 'string' ||
            ev.payload.reason.trim().length === 0 ||
            ev.payload.reason.length > 200)
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
      const msg = commitErr.message;
      const gap = msg.includes('VZ_GAP');
      // قرار ٦٠: رُفضت الدفعة بقاعدة «الخصم نفسه مرة/يوم للنقاط» —
      // خطأ عمل (٤٢٢) لا عطل سيرفر: الطالب يعرف أن النقاط لم تُحتسب
      // لأنه لعب مع الخصم نفسه اليوم، لا لأن الخادم تعطّل.
      const oppDay = msg.includes('VZ_DUEL_OPP_DAY');
      return json({
        accepted: false,
        reason: gap ? 'SEQ_GAP'
            : oppDay ? 'DUEL_OPP_ONCE_PER_DAY'
            : 'COMMIT_INTERNAL',
        synced_up_to: lastSeq - accepted.length,
        detail: (gap || oppDay) ? undefined : msg,
      }, (gap || oppDay) ? 422 : 500);
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
