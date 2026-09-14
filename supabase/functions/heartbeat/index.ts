// ═════════════════════════════════════════════════════════════════════
// F4.4 — heartbeat: زمن سيرفر موقّع + تجديد صامت للإيجار (docs/11 §٥)
// العقد الكامل: docs/16-SERVER-CONTRACT.md §٣ — اقرأه قبل أي تعديل.
// التجديد: عند آخر ٧ أيام من الإيجار (أو بعد انتهائه دون تجاوز الحد
// الصلب وكود غير مسحوب) — «الطالب الذي يلمس النت مرة شهرياً لا يرى شيئاً».
// ═════════════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';
import nacl from 'npm:tweetnacl@1.0.3';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};
const encoder = new TextEncoder();
const THIRTY_DAYS_MS = 30 * 24 * 3600 * 1000;
const RENEW_WINDOW_MS = 7 * 24 * 3600 * 1000;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'METHOD' }, 405);

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const body = await req.json();
    const pubkeyB64 = String(body.device_pubkey_b64 ?? '');
    const clientNowMs = Number.isFinite(body.client_now_ms)
      ? body.client_now_ms as number : null;

    // ── ١) الجهاز + مرساة الزمن ──
    const { data: device } = await admin
      .from('devices')
      .select('id,pubkey_b64')
      .eq('pubkey_b64', pubkeyB64)
      .single();
    if (!device) return json({ ok: false, error: 'DEVICE_UNKNOWN' }, 404);

    const { data: anchor } = await admin
      .from('time_anchors')
      .select('last_server_ms')
      .eq('device_id', device.id)
      .single();
    const serverTimeMs = Date.now();

    // ── ٢) كشف رجوع الساعة (L4 — سماحية ٥ دقائق، الحكم النهائي للسيرفر) ──
    const clockSuspected = clientNowMs != null &&
      anchor != null &&
      clientNowMs < (anchor.last_server_ms as number) - 5 * 60 * 1000;

    // ── ٣) أحدث ترخيص غير مسحوب ──
    const { data: lic } = await admin
      .from('licenses')
      .select('token,code,release_id,expires_at,revoked')
      .eq('device_id', device.id)
      .eq('revoked', false)
      .order('expires_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    let renewed = false;
    let tokenOut: { payload: string; sig: string } | undefined;

    if (lic) {
      const expiresMs = new Date(lic.expires_at).getTime();
      const needsRenew = expiresMs - serverTimeMs <= RENEW_WINDOW_MS;
      if (needsRenew) {
        const { data: codeRow } = await admin
          .from('activation_codes')
          .select('status,release_id,hard_deadline,review')
          .eq('code', lic.code)
          .single();
        const hardMs = new Date(codeRow?.hard_deadline ?? 0).getTime();
        const canRenew = codeRow?.status !== 'revoked' && serverTimeMs < hardMs;
        if (canRenew) {
          const newExpires = Math.min(serverTimeMs + THIRTY_DAYS_MS, hardMs);
          const seedB64 = Deno.env.get('SIGNING_SEED_B64');
          if (seedB64) {
            const seed = Uint8Array.from(atob(seedB64), (c) => c.charCodeAt(0));
            const kp = nacl.sign.keyPair.fromSeed(seed);
            // canonical حرفياً كالعقد §٦ — الربط مفعّل: sha256(بايتات المفتاح)
            const rawPub = Uint8Array.from(atob(device.pubkey_b64 as string), (c) =>
              c.charCodeAt(0),
            );
            const deviceHash = [
              ...new Uint8Array(await crypto.subtle.digest('SHA-256', rawPub)),
            ]
              .map((b) => b.toString(16).padStart(2, '0'))
              .join('');
            const canonical = JSON.stringify({
              code_id: lic.code,
              device_key_hash: deviceHash,
              release_id: lic.release_id,
              expires_at: newExpires,
              hard_deadline: hardMs,
              flags: (codeRow?.review === true ? ['full', 'teacher'] : ['full']).sort(),
            });
            const sig = nacl.sign.detached(encoder.encode(canonical), kp.secretKey);
            tokenOut = {
              payload: btoa(String.fromCharCode(...encoder.encode(canonical))),
              sig: btoa(String.fromCharCode(...sig)),
            };
            await admin
              .from('licenses')
              .update({ token: JSON.stringify(tokenOut), expires_at: new Date(newExpires).toISOString() })
              .eq('device_id', device.id)
              .eq('code', lic.code);
            renewed = true;
          }
        }
      }
    }

    // ── ٤) تحديث المراساة (بعد كل الحسابات) ──
    await admin
      .from('time_anchors')
      .upsert({ device_id: device.id, last_server_ms: serverTimeMs });

    return json({
      ok: true,
      server_time_ms: serverTimeMs,
      renewed,
      ...(tokenOut ? { token: tokenOut } : {}),
      clock_suspected: clockSuspected,
    });
  } catch (e) {
    return json({ ok: false, error: 'INTERNAL', detail: String(e) }, 500);
  }
});
