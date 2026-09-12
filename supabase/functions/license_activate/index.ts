// ═════════════════════════════════════════════════════════════════════
// F4.4 — license_activate: تفعيل الكود وإصدار «الإيجار الموقّع» Ed25519
// العقد الكامل: docs/16-SERVER-CONTRACT.md §٢ — اقرأه قبل أي تعديل.
// القاعدة القانونية الحاكمة: حمولة التوكن canonical مطابقة بايتاً بايتاً
// لحمولة العميل (license_core.dart) — لا فراغات، ترتيب الحقول ثابت،
// flags مرتبة. المتجهات الذهبية: العقد §٦.
// ═════════════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';
import nacl from 'npm:tweetnacl@1.0.3';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

const encoder = new TextEncoder();
const hexToBytes = (hex: string): Uint8Array => {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
};
const sha256Hex = async (s: string): Promise<string> =>
  [...new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(s)))]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

// ⚠️ ثابت التوافق: حتى ترقية العميل لفحص Keystore (F4.4-عميل) يُبَعث
// device_key_hash فارغاً — فحص العميل الحالي يرفض أي قيمة غير فارغة
// (wrongDevice). الرفع لاحقاً = تحويل هذا الثابت إلى true حصراً.
const EMIT_DEVICE_HASH = false;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

// حروف الكود المسموحة: أرقام + حروف بلا I/L/O/U (Crockford — قرار ٣٤)
const CODE_RE = /^[0-9A-HJ-KM-NP-TV-Z]{15}$/;
const THIRTY_DAYS_MS = 30 * 24 * 3600 * 1000;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'METHOD' }, 405);

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // ── ١) JWT مجهول/موثق إلزامي (F4.3: الدخول المجهول عند التفعيل) ──
    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.replace('Bearer ', '');
    const { data: userData } = await admin.auth.getUser(jwt);
    const uid = userData?.user?.id;
    if (!uid) return json({ ok: false, error: 'AUTH_REQUIRED' }, 401);

    // الملف الشخصي (upsert — أول تفعيل يولده)
    await admin.from('profiles').upsert({ id: uid });

    // ── ٢) الطلب والتطبيع ──
    const body = await req.json();
    const code = String(body.code ?? '')
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '');
    const pubkeyB64 = String(body.device_pubkey_b64 ?? '');
    const deviceFp = String(body.device_fp ?? '').slice(0, 128);
    if (!CODE_RE.test(code)) return json({ ok: false, error: 'CODE_FORMAT' }, 422);
    if (!/^[A-Za-z0-9+/]{43}=$/.test(pubkeyB64))
      return json({ ok: false, error: 'PUBKEY_FORMAT' }, 422);
    if (deviceFp.length < 8) return json({ ok: false, error: 'FP_FORMAT' }, 422);

    // ── ٣) الكود من القاعدة (قراءة مسبقة للسقف الصلب والإصدار) ──
    const { data: codeRow, error: codeErr } = await admin
      .from('activation_codes')
      .select('code,status,release_id,hard_deadline')
      .eq('code', code)
      .single();
    if (codeErr || !codeRow)
      return json({ ok: false, error: 'ACT_CODE_NOT_FOUND' }, 404);
    if (codeRow.status === 'revoked')
      return json({ ok: false, error: 'ACT_CODE_REVOKED' }, 410);

    // ── ٤) حمولة التوكن canonical (الترتيب ثابت حرفياً — العقد §٦) ──
    const nowMs = Date.now();
    const hardMs = new Date(codeRow.hard_deadline).getTime();
    const expiresMs = Math.min(nowMs + THIRTY_DAYS_MS, hardMs);
    const deviceHash = EMIT_DEVICE_HASH
      ? await sha256Hex(
          String.fromCharCode(...Uint8Array.from(atob(pubkeyB64), (c) => c.charCodeAt(0))),
        )
      : '';
    const flags = ['full'];
    const canonical = JSON.stringify({
      code_id: code,
      device_key_hash: deviceHash,
      release_id: codeRow.release_id,
      expires_at: expiresMs,
      hard_deadline: hardMs,
      flags: [...flags].sort(),
    });

    // ── ٥) التوقيع Ed25519 بالبذرة من أسرار الدوال حصراً ──
    const seedB64 = Deno.env.get('SIGNING_SEED_B64');
    if (!seedB64) return json({ ok: false, error: 'SIGNING_NOT_CONFIGURED' }, 500);
    const seed = Uint8Array.from(atob(seedB64), (c) => c.charCodeAt(0));
    const keyPair = nacl.sign.keyPair.fromSeed(seed);
    const sig = nacl.sign.detached(encoder.encode(canonical), keyPair.secretKey);
    const token = {
      payload: btoa(String.fromCharCode(...encoder.encode(canonical))),
      sig: btoa(String.fromCharCode(...sig)),
    };

    // ── ٦) الإيداع الذري (فجوة/سقف أجهزة يفحصان داخل المعاملة) ──
    const { data, error } = await admin.rpc('record_activation', {
      p_code: code,
      p_profile: uid,
      p_pubkey_b64: pubkeyB64,
      p_fp: deviceFp,
      p_token: JSON.stringify(token),
      p_release: codeRow.release_id,
      p_expires: new Date(expiresMs).toISOString(),
      p_hard: new Date(hardMs).toISOString(),
      p_server_ms: nowMs,
    });
    if (error) {
      const msg = error.message;
      if (msg.includes('ACT_CODE_NOT_FOUND'))
        return json({ ok: false, error: 'ACT_CODE_NOT_FOUND' }, 404);
      if (msg.includes('ACT_CODE_REVOKED'))
        return json({ ok: false, error: 'ACT_CODE_REVOKED' }, 410);
      if (msg.includes('ACT_DEVICE_LIMIT'))
        return json({ ok: false, error: 'ACT_DEVICE_LIMIT' }, 409);
      return json({ ok: false, error: 'ACT_INTERNAL', detail: msg }, 500);
    }

    // ── ٧) الرد — مطابق لحقول العقد §٢.٣ حرفياً ──
    return json({
      ok: true,
      token,
      server_time_ms: nowMs,
      release_id: codeRow.release_id,
      expires_at: expiresMs,
      hard_deadline: hardMs,
      code_id: code,
      devices_used: data.licenses_count,
      activated_now: data.activated_now,
    });
  } catch (e) {
    return json({ ok: false, error: 'INTERNAL', detail: String(e) }, 500);
  }
});
