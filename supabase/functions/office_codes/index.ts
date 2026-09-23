// ═══════════════════════════════════════════════════════════════════════
// office_codes — أداة المكتب (F6.1 — POS قرار ٣٤): توليد كود لحظي +
// إلغاء + جرد. الخدمة الوحيدة المخوّلة لكتابة جدول activation_codes
// (بعد رفع RLS سالبة — العملاء لا يستطيعون إدراج أكواد أبداً).
// الحماية: ترويسة x-office-key تطابق سر OFFICE_KEY (يضعه المالك) —
// بلا JWT (المكتب ليس «مستخدم تطبيق»). الداخل: SERVICE_ROLE.
// الكود: ١٥ محرفاً Crockford بلا I/L/O/U (مطابق CODE_RE بالعقد §٢ —
// والقرار ٣٤ كتب «١٠ محارف» سهواً قديماً؛ البنية والعميل ثابتان على
// ١٥ = ٥-٥-٥ كما في formatLicenseCode).
// ═══════════════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-office-key',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

// Crockford 32 — مطابق RoomCode.alphabet (العميل) وCODE_RE (الخادم).
const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const CODE_RE = /^[0-9A-HJ-KM-NP-TV-Z]{15}$/;
const DEFAULT_RELEASE = '2027-v1';
const DEFAULT_HARD = '2027-05-01T00:00:00Z';
const MAX_COUNT = 100;

const normalizeCode = (raw: string) =>
  String(raw ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');

/// مولّد كود عشوائي واحد (crypto.getRandomValues — قرار ٣٤: عند الطلب فقط).
function generateOne(): string {
  const bytes = new Uint8Array(15);
  crypto.getRandomValues(bytes);
  let out = '';
  for (let i = 0; i < 15; i++) out += CROCKFORD[bytes[i] & 31];
  return out;
}

const group5 = (code: string) => code.match(/.{1,5}/g)?.join('-') ?? code;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'METHOD' }, 405);

  try {
    // ── ١) مفتاح المكتب إلزامي (سر، يضعه المالك) ──
    const OFFICE_KEY = Deno.env.get('OFFICE_KEY');
    if (!OFFICE_KEY) return json({ ok: false, error: 'NOT_CONFIGURED' }, 500);
    const supplied = req.headers.get('x-office-key') ?? '';
    if (supplied !== OFFICE_KEY) return json({ ok: false, error: 'FORBIDDEN' }, 403);

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    const body = await req.json();
    const action = String(body.action ?? '');

    // ── ٢) generate ──
    if (action === 'generate') {
      const count = Math.max(1, Math.min(MAX_COUNT, Number(body.count ?? 1) | 0));
      const distributor = String(body.distributor ?? 'مكتب لورانيم').slice(0, 64);
      const release_id = String(body.release_id ?? DEFAULT_RELEASE).slice(0, 32);
      const hard_deadline = String(body.hard_deadline ?? DEFAULT_HARD);
      // 0008: كود مراجعة للأستاذ — التوكن يحمل 'teacher' (قرار ٥٥)
      const review = body.review === true;
      // 0013 (POS): اسم الزبون — اختياري، نص حر ≤ ٨٠ محرفاً
      const customerRaw = String(body.customer ?? '').trim().slice(0, 80);
      const customer = customerRaw.length > 0 ? customerRaw : null;

      const issued: string[] = [];
      for (let attempt = 0; attempt < count * 8 && issued.length < count; attempt++) {
        const code = generateOne();
        const { error } = await admin
          .from('activation_codes')
          .insert({
            code,
            status: 'issued',
            distributor,
            release_id,
            hard_deadline,
            review,
            customer,
          });
        if (!error) issued.push(code);
        // عند تعارض نادر نعيد المحاولة — وإلا نكمل
      }
      if (issued.length < count) {
        return json(
          { ok: false, error: 'GEN_PARTIAL', issued: issued.length, of: count },
          500,
        );
      }
      await admin.from('office_audit').insert({
        action: 'generate',
        codes: issued,
        distributor,
        note: `release=${release_id}${review ? ' review' : ''}${customer ? ` customer=${customer}` : ''}`,
      });
      return json({ ok: true, count: issued.length, codes: issued.map(group5), review, customer });
    }

    // ── ٣) revoke ── (إلغاء كود أو اشتراك: الرخص كلها تُسحب أيضاً —
    // heartbeat يرفض تجديد أي كود revoked وRLS تحجب الرخص المسحوبة — قرار ٢٧)
    if (action === 'revoke') {
      const code = normalizeCode(body.code);
      if (!CODE_RE.test(code)) return json({ ok: false, error: 'CODE_FORMAT' }, 422);
      const { data: rows, error } = await admin
        .from('activation_codes')
        .update({ status: 'revoked' })
        .eq('code', code)
        .select('code');
      if (error) return json({ ok: false, error: 'INTERNAL', detail: String(error) }, 500);
      if (!rows || rows.length === 0)
        return json({ ok: false, error: 'CODE_NOT_FOUND' }, 404);
      await admin.from('licenses').update({ revoked: true }).eq('code', code);
      await admin.from('office_audit').insert({
        action: 'revoke',
        codes: [code],
        distributor: 'مكتب لورانيم',
      });
      return json({ ok: true, code: group5(code) });
    }

    // ── ٤) list — جرد الأكواد مع عدد الأجهزة المستخدَمة (قرار ٢٨) ──
    if (action === 'list') {
      const status = String(body.status ?? '');
      let q = admin
        .from('activation_codes')
        .select('code,status,distributor,release_id,hard_deadline,created_at,activated_at,activated_by,review')
        .order('created_at', { ascending: false })
        .limit(200);
      if (status && ['issued', 'activated', 'revoked'].includes(status)) {
        q = q.eq('status', status);
      }
      const { data: codes, error } = await q;
      if (error) return json({ ok: false, error: 'INTERNAL', detail: String(error) }, 500);
      const list = (codes ?? []).map((c) => c.code);
      const used = new Map<string, number>();
      if (list.length > 0) {
        const { data: lic } = await admin
          .from('licenses')
          .select('code')
          .in('code', list)
          .eq('revoked', false);
        for (const row of lic ?? []) {
          used.set(row.code, (used.get(row.code) ?? 0) + 1);
        }
      }
      return json({
        ok: true,
        codes: (codes ?? []).map((c) => ({
          code: group5(c.code),
          status: c.status,
          distributor: c.distributor,
          review: c.review === true,
          release_id: c.release_id,
          hard_deadline: c.hard_deadline,
          created_at: c.created_at,
          activated_at: c.activated_at,
          activated_by: c.activated_by,
          devices_used: used.get(c.code) ?? 0,
        })),
      });
    }

    // ── ٥) stats — عداد المشتركين + لائحة (لوحة الإدارة المخفية بالتطبيق) ──
    if (action === 'stats') {
      const [iss, act, rev, lic] = await Promise.all([
        admin
          .from('activation_codes')
          .select('code', { count: 'exact', head: true })
          .eq('status', 'issued'),
        admin
          .from('activation_codes')
          .select('code', { count: 'exact', head: true })
          .eq('status', 'activated'),
        admin
          .from('activation_codes')
          .select('code', { count: 'exact', head: true })
          .eq('status', 'revoked'),
        admin
          .from('licenses')
          .select('id', { count: 'exact', head: true })
          .eq('revoked', false),
      ]);
      const { data: codes, error } = await admin
        .from('activation_codes')
        .select('code,status,distributor,release_id,created_at,activated_at,customer,review')
        .order('created_at', { ascending: false })
        .limit(500);
      if (error) return json({ ok: false, error: 'INTERNAL', detail: String(error) }, 500);
      const list = (codes ?? []).map((c) => c.code);
      const used = new Map<string, number>();
      if (list.length > 0) {
        const { data: licRows } = await admin
          .from('licenses')
          .select('code')
          .in('code', list)
          .eq('revoked', false);
        for (const row of licRows ?? []) {
          used.set(row.code, (used.get(row.code) ?? 0) + 1);
        }
      }
      return json({
        ok: true,
        stats: {
          issued: iss.count ?? 0,
          activated: act.count ?? 0,
          revoked: rev.count ?? 0,
          activeLicenses: lic.count ?? 0,
        },
        subscribers: (codes ?? []).map((c) => ({
          code: group5(c.code),
          status: c.status,
          distributor: c.distributor,
          release_id: c.release_id,
          created_at: c.created_at,
          activated_at: c.activated_at,
          devices_used: used.get(c.code) ?? 0,
          customer: c.customer ?? null,
          review: c.review === true,
        })),
      });
    }

    // ── ٦) note — تحديث اسم الزبون على كود قائم (POS: بيع سابق بلا اسم) ──
    if (action === 'note') {
      const code = normalizeCode(body.code);
      if (!CODE_RE.test(code)) return json({ ok: false, error: 'CODE_FORMAT' }, 422);
      const customerRaw = String(body.customer ?? '').trim().slice(0, 80);
      const { data: rows, error } = await admin
        .from('activation_codes')
        .update({ customer: customerRaw.length > 0 ? customerRaw : null })
        .eq('code', code)
        .select('code');
      if (error) return json({ ok: false, error: 'INTERNAL', detail: String(error) }, 500);
      if (!rows || rows.length === 0)
        return json({ ok: false, error: 'CODE_NOT_FOUND' }, 404);
      return json({ ok: true, code: group5(code) });
    }

    // ── ٧) season_get — حالة موسم (الافتراضي: الموسم الحالي) ──
    // F6.6: المكتب يقرأ ما إذا كان الموسم مفتوحاً (ends_on=null) أو مغلقاً.
    if (action === 'season_get') {
      const season = String(body.season ?? '').trim();
      // لا نحسب current_season() هنا (منطق زمني بدمشق) — العميل يمرّره؛ فارغ ⇒ خطأ.
      if (!season) return json({ ok: false, error: 'SEASON_REQUIRED' }, 422);
      const { data: row, error } = await admin
        .from('seasons')
        .select('name, ends_on')
        .eq('name', season)
        .maybeSingle();
      if (error) return json({ ok: false, error: 'INTERNAL', detail: String(error) }, 500);
      return json({
        ok: true,
        season,
        exists: !!row,
        ends_on: (row?.ends_on as string | null) ?? null,
        // مغلق = ends_on موجود وقد مضى (بتاريخ اليوم UTC — البوابة نفسها في cert_issue).
        closed: !!row?.ends_on &&
          new Date(row!.ends_on as string).getTime() <= Date.now(),
      });
    }

    // ── ٨) season_set — ضبط/مسح تاريخ نهاية الموسم (بيد المالك، قرار ٣٦) ──
    // ends_on='YYYY-MM-DD' يضبط الإغلاق · ends_on=null يعيد فتح الموسم.
    if (action === 'season_set') {
      const season = String(body.season ?? '').trim();
      if (!season) return json({ ok: false, error: 'SEASON_REQUIRED' }, 422);
      const raw = body.ends_on;
      let endsOn: string | null = null;
      if (raw !== null && raw !== undefined && String(raw).trim() !== '') {
        const s = String(raw).trim();
        // ISO date صارم YYYY-MM-DD — لا وقت، لا صيغ غامضة.
        if (!/^\d{4}-\d{2}-\d{2}$/.test(s) || Number.isNaN(Date.parse(s)))
          return json({ ok: false, error: 'DATE_FORMAT' }, 422);
        endsOn = s;
      }
      const { data: row, error } = await admin
        .from('seasons')
        .upsert({ name: season, ends_on: endsOn }, { onConflict: 'name' })
        .select('name, ends_on')
        .single();
      if (error) return json({ ok: false, error: 'INTERNAL', detail: String(error) }, 500);
      await admin.from('office_audit').insert({
        action: 'season_set',
        note: `season=${season} ends_on=${endsOn ?? 'null(open)'}`,
      });
      return json({
        ok: true,
        season,
        exists: true,
        ends_on: (row?.ends_on as string | null) ?? null,
        closed: !!row?.ends_on &&
          new Date(row!.ends_on as string).getTime() <= Date.now(),
      });
    }

    return json({ ok: false, error: 'BAD_ACTION' }, 422);
  } catch (e) {
    return json({ ok: false, error: 'INTERNAL', detail: String(e) }, 500);
  }
});
