// ═══════════════════════════════════════════════════════════════════════
// cert_issue — F6.3: إصدار شهادة الموسم الموقّعة «بطل دوري فيزيا كلاش».
// العقد: docs/14 سطر F6.3 · docs/13 §٦ (العنوان/الشعار) · 0014_certificates.
// المصادقة: جهاز معروف بمفتاحه العام (نفس عقد heartbeat) — لا مستخدم JWT.
// البوابة: الموسم مُغلق (ends_on مضى) · مشاركة ≥ ١ موسم · idempotent
//          unique(season, device) ⇒ إعادة النداء تعيد الشهادة نفسها.
// الطبقتان: years ≥ 2 ⇒ gold_two «🥇 سنتان» · years = 1 ⇒ silver_one «🥈 سنة»
//          (عدد المواسم في weekly_totals — كما في سطر F6.3 حرفياً).
// التوقيع: Ed25519 detached على حمولة canonical بنفس ترتيب حقول
//          Certificate.canonicalJson (Dart) — لا signature داخل الحمولة.
// الأسرار (أسماء فقط — docs/22 §١-5): CERT_SK_B64 = بذرة ٣٢ بايت base64.
// ⚠️ NOTICE_40: نصّ قرار ٤٠ حرفيًّا — بانتظار المالك؛ فارغ ⇒ لا تنويه
//    (يُزامَن مع kFlexibilityNotice40 بالتطبيق في نفس التعديل).
// ═══════════════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';
import nacl from 'npm:tweetnacl@1.0.3';

const NOTICE_40 = ''; // ⚠️ نصّ قرار ٤٠ حرفي — بانتظار المالك (لا تخمّن)

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

const b64FromBytes = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes));

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'METHOD' }, 405);

  try {
    // ── ٠) مفتاح التوقيع إلزامي (بذرة Ed25519 — سرّ المالك) ──
    const SK_B64 = Deno.env.get('CERT_SK_B64');
    if (!SK_B64) return json({ ok: false, error: 'NOT_CONFIGURED' }, 500);
    let seed: Uint8Array;
    try {
      const raw = Uint8Array.from(atob(SK_B64), (c) => c.charCodeAt(0));
      if (raw.length !== 32) throw new Error('seed');
      seed = raw;
    } catch (_) {
      return json({ ok: false, error: 'BAD_KEY' }, 500);
    }
    const keyPair = nacl.sign.keyPair.fromSeed(seed);

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const body = await req.json();
    const pubkeyB64 = String(body.device_pubkey_b64 ?? '');
    const season = String(body.season ?? '');
    if (!pubkeyB64 || !season) {
      return json({ ok: false, error: 'BAD_REQUEST' }, 400);
    }

    // ── ١) الموسم مُغلق؟ (F6.3: نهاية الموسم حصراً) ──
    const { data: seasonRow } = await admin
      .from('seasons')
      .select('name, ends_on')
      .eq('name', season)
      .maybeSingle();
    if (!seasonRow) return json({ ok: false, error: 'SEASON_UNKNOWN' }, 404);
    const endsOn = seasonRow.ends_on as string | null;
    const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
    if (!endsOn || endsOn > today) {
      return json({ ok: false, error: 'SEASON_OPEN' }, 409);
    }

    // ── ٢) الجهاز معروف؟ (نفس عقد heartbeat) ──
    const { data: device } = await admin
      .from('devices')
      .select('id')
      .eq('pubkey_b64', pubkeyB64)
      .maybeSingle();
    if (!device) return json({ ok: false, error: 'DEVICE_UNKNOWN' }, 404);

    // ── ٣) idempotency: شهادة سابقة تُعاد كما هي ──
    const { data: existing } = await admin
      .from('certificates')
      .select('id, payload, signature, issued_at')
      .eq('season', season)
      .eq('device_id', device.id)
      .maybeSingle();
    if (existing) {
      return json({
        ok: true,
        certificate: {
          ...(existing.payload as Record<string, unknown>),
          signature: existing.signature,
        },
        renewed: false,
      });
    }

    // ── ٤) سنوات المشاركة (عدد المواسم في weekly_totals) + XP الموسم ──
    const { data: seasonsSeen } = await admin
      .from('weekly_totals')
      .select('season')
      .eq('device_id', device.id);
    const distinct = new Set(
      (seasonsSeen ?? [])
        .map((r) => (r.season as string | null) ?? '')
        .filter((s) => s.length > 0),
    );
    if (distinct.size === 0) {
      return json({ ok: false, error: 'NOT_PARTICIPATED' }, 409);
    }
    const years = Math.min(2, distinct.size);
    const tier = years >= 2 ? 'gold_two' : 'silver_one';

    const { data: weekRows } = await admin
      .from('weekly_totals')
      .select('xp')
      .eq('device_id', device.id)
      .eq('season', season);
    const xp = (weekRows ?? []).reduce(
      (sum, r) => sum + Number(r.xp ?? 0),
      0,
    );

    // ── ٥) الحمولة الـcanonical — الترتيب مطابق لـDart حرفياً ──
    const payloadObj = {
      id: crypto.randomUUID(),
      season,
      tier,
      years,
      xp,
      device_pubkey_b64: pubkeyB64,
      issued_at_ms: Date.now(),
      notice: NOTICE_40,
    };
    const canonical = JSON.stringify(payloadObj);
    const sig = nacl.sign.detached(
      new TextEncoder().encode(canonical),
      keyPair.secretKey,
    );
    const signature = b64FromBytes(sig);

    // ── ٦) إيداع idempotent (سباق آمن عبر unique) ──
    const { error: insErr } = await admin.from('certificates').insert({
      id: payloadObj.id,
      season,
      device_id: device.id,
      tier,
      years,
      xp,
      payload: payloadObj,
      signature,
    });
    if (insErr) {
      // سباق مع نداء آخر: نعيد الشهادة الفائزة
      const { data: raced } = await admin
        .from('certificates')
        .select('payload, signature')
        .eq('season', season)
        .eq('device_id', device.id)
        .maybeSingle();
      if (raced) {
        return json({
          ok: true,
          certificate: {
            ...(raced.payload as Record<string, unknown>),
            signature: raced.signature,
          },
          renewed: false,
        });
      }
      return json({ ok: false, error: 'INSERT_FAILED' }, 500);
    }

    return json({
      ok: true,
      certificate: { ...payloadObj, signature },
      renewed: false,
    });
  } catch (_) {
    return json({ ok: false, error: 'INTERNAL' }, 500);
  }
});
