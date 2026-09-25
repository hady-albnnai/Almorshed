-- ═══════════════════════════════════════════════════════════════════════
-- apply_all_idempotent.sql — تطبيق مخطّط السحابة كاملاً يدوياً (SQL Editor)
--
-- الغرض: إصلاح «دوري الكلاش غير موجود · المبارزة عن بعد تفشل (public.duels
-- مفقود) · ترتيب فيزيا كلاش لا يعمل» — سببها أن هجرات المنافسة (0005 المبارزات
-- و 0011 ترتيب الموسم …) لم تُطبَّق على السحابة، و `supabase db push` يرفضها
-- بسبب عدم توافق سجلّ الهجرات (لا بسبب خطأ SQL).
--
-- الحل: هذا الملف يلصق كل الهجرات 0001→0016 بالترتيب. كلها **آمنة لإعادة
-- التشغيل** (create table if not exists · create or replace function ·
-- drop policy if exists · add column if not exists · لا drop table ولا
-- truncate ولا حذف على مستوى المخطّط). فإعادة تشغيل المُطبَّق سابقاً لا تضرّ،
-- والمفقود (المبارزات/الترتيب) يُنشأ.
--
-- كيفية التشغيل:
--   1) افتح لوحة Supabase ← SQL Editor ← New query.
--   2) الصق كامل محتوى هذا الملف.
--   3) Run. إن ظهر إشعار «realtime.messages غير موجود» فعّل Realtime على
--      الجدول ثم أعد تشغيل قسم 0005 وحده (سياسات القناة الخاصة).
--   4) لتفعيل ترتيب الموسم دورياً: أنشئ Cron يستدعي public.league_rollup_week().
--
-- تحذير: لا يحتوي هذا الملف أي أسرار. لا تلصق مفاتيح الخدمة هنا.
-- ═══════════════════════════════════════════════════════════════════════



-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0001_init.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- F4.2 — فيزيا كلاش: المخطط الأول (قرار ٣٣: Supabase · قرار ٥٠: الخطة المجانية)
-- docs/11 §٥/§٦/§١٢ · docs/12 §٤ — يُطبَّق من SQL Editor كاملاً مرة واحدة.
-- القاعدة الحاكمة: العميل لا يكتب أي شيء مباشرة — كل الكتابة عبر
-- Edge Functions (service_role يتجاوز RLS) — والقراءة لصاحبها حصراً.
-- ════════════════════════════════════════════════════════════════════

-- ── الملفات الشخصية (F4.3: دخول مجهول عند التفعيل) ──
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'طالب فيزيا',
  created_at  timestamptz not null default now()
);

-- ── الأجهزة (docs/11 §٦: ربط الكود بمفتاح الجهاز — توكن منقول يفشل) ──
create table if not exists public.devices (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  pubkey_b64  text not null unique,          -- مفتاح Ed25519 العام للجهاز
  device_fp   text not null,                 -- بصمة استقرار (AndroidId+بناء)
  created_at  timestamptz not null default now(),
  last_seen   timestamptz not null default now()
);
create index if not exists devices_profile_idx on public.devices(profile_id);

-- ── أكواد التفعيل (docs/11 §١٢.٢ POS: تُصدَر عند الطلب حصراً) ──
create table if not exists public.activation_codes (
  code          text primary key,            -- ١٥ محرفاً Crockford ٥-٥-٥
  status        text not null default 'issued'
                check (status in ('issued','activated','revoked')),
  distributor   text not null default 'مكتب لورانيم',
  release_id    text not null default '2027-v1',
  hard_deadline timestamptz not null default '2027-05-01T00:00:00Z',
  created_at    timestamptz not null default now(),
  activated_at  timestamptz,
  activated_by  text                         -- device_fp الأول
);

-- ── سجل التراخيص (F4.4: من أداة المكتب + إلغاء/تجديد — قرار ٢٨: جهازان) ──
create table if not exists public.licenses (
  id          uuid primary key default gen_random_uuid(),
  code        text not null references public.activation_codes(code),
  device_id   uuid not null references public.devices(id) on delete cascade,
  token       text not null,                 -- التوكن الموقّع (سجل للإبطال)
  release_id  text not null,
  expires_at  timestamptz not null,          -- ≤ ٣٠ يوماً (docs/11 §٥)
  revoked     boolean not null default false,
  issued_at   timestamptz not null default now(),
  unique (code, device_id)                 -- جهازان لكل كود حدّاً أقصى
);
create index if not exists licenses_code_idx on public.licenses(code);

-- ── أحداث XP (docs/12 §٤.۲ — سياسة التقاعد F4.1: أسبوع حالي حصراً؛
--    ما قبله يعيش مجموعاً في weekly_totals بعد تدقيق السلسلة) ──
create table if not exists public.xp_events (
  device_id  uuid not null references public.devices(id) on delete cascade,
  seq        int  not null check (seq >= 1),
  type       text not null,
  ts         bigint not null,
  payload    jsonb not null,
  prev_hash  text not null,
  hash       text not null,
  sig        text not null,                  -- Ed25519(deviceKey, hash bytes)
  primary key (device_id, seq)
);
create index if not exists xp_events_device_hash_idx
  on public.xp_events(device_id, hash);

-- ── مجموعات أسبوعية (بقايَا السلسلة بعد التقاعد — < 100MB دائماً) ──
create table if not exists public.weekly_totals (
  device_id uuid not null references public.devices(id) on delete cascade,
  iso_week  int  not null,                   -- مثل 202637
  xp        int  not null default 0,
  events_n  int  not null default 0,
  primary key (device_id, iso_week)
);

-- ── مجموعات الدوري الأسبوعية (قرار ٤١: ~٣٠ طالباً بمستوى متقارب) ──
create table if not exists public.league_standings (
  iso_week  int  not null,
  group_no  int  not null,
  rank_no   int  not null,
  device_id uuid not null references public.devices(id) on delete cascade,
  xp        int  not null default 0,
  primary key (iso_week, group_no, rank_no)
);

-- ── مراسي L4: آخر زمن سيرفر لكل جهاز (كشف رجوع الساعة) ──
create table if not exists public.time_anchors (
  device_id    uuid primary key references public.devices(id) on delete cascade,
  last_server_ms bigint not null,
  updated_at   timestamptz not null default now()
);

-- ═══════════ RLS — القفل الافتراضي ثم الفتحات المحدودة ═══════════
alter table public.profiles         enable row level security;
alter table public.devices          enable row level security;
alter table public.activation_codes enable row level security;
alter table public.licenses         enable row level security;
alter table public.xp_events        enable row level security;
alter table public.weekly_totals    enable row level security;
alter table public.league_standings enable row level security;
alter table public.time_anchors     enable row level security;

-- الملف الشخصي: صاحبه يقرأ ويحدّث اسمه فقط
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id);
-- الإدراج عبر service_role عند التفعيل (F4.3)

-- الأجهزة: صاحبها يقرأ أجهزته (يرى «٢ / ٢» في حسابي)
create policy "devices_select_own" on public.devices
  for select using (auth.uid() = profile_id);
-- الإدراج/التحديث عبر service_role حصراً (license_activate/heartbeat)

-- الأكواد: لا قراءة للعميل إطلاقاً (أسرار توزيع) — service_role فقط
-- licenses: صاحب الجهاز يقرأ ترخيصه
create policy "licenses_select_own" on public.licenses
  for select using (exists (
    select 1 from public.devices d
    where d.id = licenses.device_id and d.profile_id = auth.uid()
  ));

-- أحداث XP ومجاميعها: قراءة صاحبها — الكتابة عبر verify_xp_events حصراً
create policy "xp_events_select_own" on public.xp_events
  for select using (exists (
    select 1 from public.devices d
    where d.id = xp_events.device_id and d.profile_id = auth.uid()
  ));
create policy "weekly_select_own" on public.weekly_totals
  for select using (exists (
    select 1 from public.devices d
    where d.id = weekly_totals.device_id and d.profile_id = auth.uid()
  ));

-- الدوري: المفعّلون حصراً (جهاز بترخيص غير مسحوب) — المجهول مرفوض
-- (المجهول يحمل دور authenticated — قراءة عامة له كانت ستفتح الترتيب
--  لغير المفعّلين؛ المشددة أدناه بعد تفعيل Anonymous 2026-09-12)
create policy "standings_select_licensed" on public.league_standings
  for select to authenticated using (exists (
    select 1 from public.devices d
    join public.licenses l on l.device_id = d.id and l.revoked = false
    where d.profile_id = auth.uid()
  ));

-- المراسي: service_role فقط (لا سياسة للعميل أصلاً)

-- ════════════════════════════════════════════════════════════════════
-- ملاحظات التطبيق:
-- ١) auth: الدخول المجهول مفعل من Authentication → Providers → Anonymous
--    (F4.3 — يُربط بالبروفايل عند التفعيل).
-- ٢) سياسة التقاعد (F4.1) تُنفَّذ داخل league_rollup الأسبوعية:
--    إقفال الأسبوع ⇒ upsert weekly_totals ⇒ delete أحداث الأسبوع المغلق
--    ⇒ < 100MB دائماً (الخطة المجانية قرار ٥٠).
-- ٣) ping مجدول إلزامي (تفادي خمول ٧ أيام §١٥-د): Workflow أسبوعي يضيفه
--    المالك (ملف .github/workflows ملكه) — نصه جاهز في docs/supabase/.
-- ════════════════════════════════════════════════════════════════════


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0002_server_functions.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- F4.4/F4.5/F4.6 — دوال الخادم الذرية (تُطبَّق بعد 0001_init.sql مباشرة)
-- العقد الكامل موثق: docs/16-SERVER-CONTRACT.md (اقرأه قبل أي تعديل)
-- القاعدة: Edge Functions (TS) تحسب التوقيعات والهاشات (Ed25519 لا يوجد
-- بPostgres) وتستدعي هذه الدوال للكتابة الذرية المتسابقة.
-- ════════════════════════════════════════════════════════════════════

-- ═══ 1) record_activation — التفعيل الذري (license_activate يستدعيها) ═══
-- تُعيد jsonb {device_id, licenses_count, activated_now}
-- أخطاء برسائل متعارفة يترجمها TS إلى HTTP (انظر العقد §2.4):
--   ACT_CODE_NOT_FOUND · ACT_CODE_REVOKED · ACT_DEVICE_LIMIT
create or replace function public.record_activation(
  p_code text, p_profile uuid, p_pubkey_b64 text, p_fp text,
  p_token text, p_release text, p_expires timestamptz,
  p_hard timestamptz, p_server_ms bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code    public.activation_codes%rowtype;
  v_device  uuid;
  v_count   int;
  v_activated boolean := false;
begin
  -- قفل صف الكود ذرياً (يمنع تفعيلين متسابقين — خطر ٣٢ بنيوياً)
  select * into v_code from public.activation_codes
    where code = p_code for update;
  if not found then
    raise exception 'ACT_CODE_NOT_FOUND' using errcode = 'P0001';
  end if;
  if v_code.status = 'revoked' then
    raise exception 'ACT_CODE_REVOKED' using errcode = 'P0001';
  end if;

  -- الجهاز: بالمفتاح العام (نفس المفتاح = نفس الجهاز)
  select id into v_device from public.devices where pubkey_b64 = p_pubkey_b64;
  if v_device is null then
    insert into public.devices (profile_id, pubkey_b64, device_fp)
      values (p_profile, p_pubkey_b64, p_fp)
      returning id into v_device;
  else
    update public.devices set last_seen = now() where id = v_device;
  end if;

  -- قرار ٢٨: جهازان لكل كود — العد على التراخيص غير المسحوبة
  if v_code.status = 'activated' then
    select count(*) into v_count from public.licenses
      where code = p_code and revoked = false
        and device_id <> v_device;
    if v_count >= 2 then
      raise exception 'ACT_DEVICE_LIMIT' using errcode = 'P0001';
    end if;
  else
    update public.activation_codes
      set status = 'activated', activated_at = now(),
          activated_by = p_fp
      where code = p_code;
    v_activated := true;
  end if;

  -- upsert ترخيص (نفس الجهاز يعيد التفعيل = تجديد لنفس الصف)
  insert into public.licenses
    (code, device_id, token, release_id, expires_at)
  values (p_code, v_device, p_token, p_release, p_expires)
  on conflict (code, device_id) do update
    set token = excluded.token,
        release_id = excluded.release_id,
        expires_at = excluded.expires_at,
        revoked = false;

  -- مرساة L4
  insert into public.time_anchors (device_id, last_server_ms)
    values (v_device, p_server_ms)
    on conflict (device_id) do update
      set last_server_ms = excluded.last_server_ms, updated_at = now();

  select count(*) into v_count from public.licenses
    where code = p_code and revoked = false;
  return jsonb_build_object(
    'device_id', v_device,
    'licenses_count', v_count,
    'activated_now', v_activated
  );
end;
$$;

-- ═══ 2) device_state_for_verify — قراءة حالة التحقق (بلا كتابة) ═══
-- تُعيد jsonb {device_id, pubkey_b64, last_seq, last_hash} أو null
create or replace function public.device_state_for_verify(
  p_pubkey_b64 text
) returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'device_id', d.id,
    'pubkey_b64', d.pubkey_b64,
    'last_seq', coalesce((select max(seq) from public.xp_events e
                          where e.device_id = d.id), 0),
    'last_hash', (select hash from public.xp_events e
                  where e.device_id = d.id
                  order by seq desc limit 1)
  )
  from public.devices d where d.pubkey_b64 = p_pubkey_b64;
$$;

-- ═══ 3) verify_commit — إيداع الأحداث المتحقق منها ذرياً ═══
-- TS تحقق التشفير (هاش/توقيع/أنواع/سقوف) ثم تستدعي هذه مرة واحدة.
-- إعادة تحقق الاستمرارية داخل المعاملة (فجوة متسابقة = رفض).
-- أخطاء: VZ_GAP (فجوة) · VZ_DEVICE (جهاز غير معروف)
create or replace function public.verify_commit(
  p_device uuid, p_events jsonb,
  p_expect_last_seq int, p_expect_last_hash text,
  p_server_ms bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_seq  int;
  v_last_hash text;
  v_ev        jsonb;
  i           int;
begin
  -- إعادة الفحص داخل المعاملة (لا ثقة بالقراءة السابقة)
  select coalesce(max(seq), 0), coalesce(
    (select hash from public.xp_events e2
     where e2.device_id = p_device order by seq desc limit 1), 'GENESIS')
    into v_last_seq, v_last_hash
    from public.xp_events e where e.device_id = p_device;

  if v_last_seq <> p_expect_last_seq or v_last_hash is distinct from p_expect_last_hash then
    raise exception 'VZ_GAP' using errcode = 'P0001';
  end if;

  for i in 0 .. jsonb_array_length(p_events) - 1 loop
    v_ev := p_events -> i;
    if (v_ev ->> 'prevHash') is distinct from v_last_hash then
      raise exception 'VZ_GAP' using errcode = 'P0001';
    end if;
    insert into public.xp_events
      (device_id, seq, type, ts, payload, prev_hash, hash, sig)
    values (
      p_device,
      (v_ev ->> 'seq')::int,
      v_ev ->> 'type',
      (v_ev ->> 'ts')::bigint,
      v_ev -> 'payload',
      v_ev ->> 'prevHash',
      v_ev ->> 'hash',
      v_ev ->> 'sig'
    );
    v_last_seq  := (v_ev ->> 'seq')::int;
    v_last_hash := v_ev ->> 'hash';
  end loop;

  insert into public.time_anchors (device_id, last_server_ms)
    values (p_device, p_server_ms)
    on conflict (device_id) do update
      set last_server_ms = excluded.last_server_ms, updated_at = now();

  return jsonb_build_object('synced_up_to', v_last_seq);
end;
$$;

-- ═══ 4) league_rollup_week — إقفال الأسبوع والدوري (F4.6 + تقاعد F4.1) ═══
-- الأسبوع: الاثنين ٠٠:٠٠ → الأحد ٢٤:٠٠ بتوقيت دمشق (docs/12 §٤.۳)
-- دمشق UTC+3 دائماً (أُلغي التوقيت الصيفي 2022) ⇒ إقفال الأسبوع المنتهي
-- يُحسب بتوقيت دمشق ناقص ساعة (ضمانة تغيّر الإقفال عند منتصف الليل).
-- idempotent: إعادة الجولة لنفس الأسبوع تستبدل النتائج ولا تضاعف.
create or replace function public.league_rollup_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_closed_start date;   -- بداية الأسبوع المغلق (اثنين)
  v_week_id      int;    -- IYYYIW مثل 202637
  v_devices      int;
begin
  -- الأسبوع المغلق = الأسبوع الذي انتهى قبل ساعة (بتوقيت دمشق)
  v_closed_start := date_trunc('week',
      (now() at time zone 'Asia/Damascus') - interval '1 hour')::date;
  v_week_id := to_char(v_closed_start, 'IYYYIW')::int;

  -- ١) المجاميع الأسبوعية من الأحداث داخل نافذة الأسبوع المغلق
  insert into public.weekly_totals (device_id, iso_week, xp, events_n)
  select e.device_id, v_week_id,
         sum((e.payload ->> 'points')::int), count(*)
    from public.xp_events e
   where e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
   group by e.device_id
  on conflict (device_id, iso_week) do update
    set xp = excluded.xp, events_n = excluded.events_n;

  -- ٢) الترتيب: مجموع XP الأسبوع تنازلياً — مجموعات ٣٠ متتالية (قرار ٤١)
  delete from public.league_standings where iso_week = v_week_id;
  insert into public.league_standings
    (iso_week, group_no, rank_no, device_id, xp)
  select v_week_id,
         ((row_number() over (order by t.xp desc, t.device_id) - 1) / 30) + 1,
         row_number() over (order by t.xp desc, t.device_id),
         t.device_id, t.xp
    from (
      select device_id, sum(xp) as xp
        from public.weekly_totals where iso_week = v_week_id
       group by device_id
    ) t;

  -- ٣) تقاعد أحداث الأسبوع المغلق (F4.1 — القاعدة < 100MB دائماً)
  delete from public.xp_events e
   where e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint;

  select count(*) into v_devices from public.league_standings
    where iso_week = v_week_id;
  return jsonb_build_object('week', v_week_id, 'devices', v_devices);
end;
$$;

-- ═══ 5) الجدولة الأسبوعية — pg_cron (فعل الإضافة من اللوحة أولاً) ═══
-- Database → Extensions → pg_cron: Enable، ثم ألغِ التعليق عن السطرين:
-- دمشق +3 ⇒ الاثنين ٠٠:٠٥ = الأحد ٢١:٠٥ UTC
-- select cron.schedule('league_rollup', '5 21 * * 0',
--   $$select public.league_rollup_week();$$);
-- (إلغاؤه اليدوي: select cron.unschedule('league_rollup');)

-- ═══ 6) التحصين الحرج: دوال Definer لـ service_role حصراً ═══
-- بدون هذا: أي عميل anon/authenticated يستطيع استدعاء الدوال مباشرة
-- عبر PostgREST RPC (EXECUTE للـPUBLIC افتراضياً!) فيتجاوز التحقق
-- التشفيري كلياً (verify_commit بلا فحص توقيع) أو يستهلك أكواداً
-- أو يشيّخ أحداثاً مصطنعة (league_rollup خارج أسبوعها). يُمنع.
revoke execute on function
  public.record_activation(text,uuid,text,text,text,text,timestamptz,timestamptz,bigint)
  from public, anon, authenticated;
grant execute on function
  public.record_activation(text,uuid,text,text,text,text,timestamptz,timestamptz,bigint)
  to service_role;

revoke execute on function
  public.device_state_for_verify(text)
  from public, anon, authenticated;
grant execute on function
  public.device_state_for_verify(text)
  to service_role;

revoke execute on function
  public.verify_commit(uuid,jsonb,int,text,bigint)
  from public, anon, authenticated;
grant execute on function
  public.verify_commit(uuid,jsonb,int,text,bigint)
  to service_role;

revoke execute on function
  public.league_rollup_week()
  from public, anon, authenticated;
grant execute on function
  public.league_rollup_week()
  to service_role;


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0003_tighten_standings.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- 0003 — تشديد سياسة الدوري بعد تفعيل Anonymous (المجهول = authenticated)
-- قبل: standings_select_auth باستخدام(true) لكل authenticated — والمجهول
-- الآن authenticated ⇒ كان سيقرأ الترتيب دون تفعيل. بعد: أجهزة بترخيص
-- غير مسحوب حصراً (نفس قصد docs/12: «المفعّلون» حرفياً).
-- ════════════════════════════════════════════════════════════════════
drop policy if exists "standings_select_auth" on public.league_standings;
create policy "standings_select_licensed" on public.league_standings
  for select to authenticated using (exists (
    select 1 from public.devices d
    join public.licenses l on l.device_id = d.id and l.revoked = false
    where d.profile_id = auth.uid()
  ));


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0004_activation_throttle.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- 0004 — تقييد محاولات التفعيل (مضاد التعداد القسري — NIST 800-63B:
-- throttling حسب المُرسل). 5 محاولات فاشلة/١٥ دقيقة لكل مستخدم.
-- يطبقه license_activate: يفحص قبل الرد ويُسجل كل فشل ACT_CODE_*.
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.activation_attempts (
  id     bigint generated always as identity primary key,
  user_id uuid not null,          -- الملف المجهول للمهاجم (JWT إلزامي)
  code   text not null,          -- الكود المجرَّب (تتبع أنماط الهجوم)
  ip     text not null default '', -- من x-forwarded-for — طبقة ثانية
  ts     timestamptz not null default now()
);
create index if not exists activation_attempts_user_ts_idx
  on public.activation_attempts(user_id, ts);
create index if not exists activation_attempts_ip_ts_idx
  on public.activation_attempts(ip, ts);

-- مقفولة كلياً عن العملاء — service_role (عبر الدالة) حصراً
alter table public.activation_attempts enable row level security;

-- استعلام الفحص (تستدعيه الدالة):
--   select count(*) from public.activation_attempts
--    where user_id = <uid> and ts > now() - interval '15 minutes';
--   + طبقة IP: عدّ بالعنوان نفسه ≥30/١٥د ⇒ رفض (يبطل تجاوز القفل
--   بإنشاء حسابات مجهولة جديدة — المهاجم يبقى بعنوان شبكته)
-- الحذف الدوري (تستدعيه الدالة بعد كل إدراج — توفير مساحة الخطة المجانية):
--   delete from public.activation_attempts where ts < now() - interval '24 hours';


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0005_duels.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ═══════════════════════════════════════════════════════════════════════
-- 0005_duels — المبارزات الحية (M5 / F5.1+F5.2)
-- العقد الكامل: docs/16-SERVER-CONTRACT.md §٦ (duel_finish) و§٧ (قنوات duel).
-- القواعد (docs/11 §١١ + §و-5): النتيجة يقررها السيرفر من البذرة حصراً؛
-- القناة خاصة private:true بسياسات RLS على realtime.messages للمشاركين حصراً.
-- ملاحظة scopeTag: bigint بpostgres موقّع ⇒ التاج 13 بت (لا 14) ليبقى
-- seed = (tag<<50)|roomCode < 2^63 — قرار تقني موثق بالعقد §٦.٠.
-- ═══════════════════════════════════════════════════════════════════════

-- ── ١) content_questions — بنك المبارزة على السيرفر (معرفات حصراً بلا نصوص
--      الكتاب — قرار ٥٥). يملؤه المالك من docs/supabase/content_index.sql
--      (أداة tools/gen_content_index.py — بنك المعتمد حصراً قرار ٢٤).
create table if not exists public.content_questions (
  id             int  primary key,            -- معرف السؤال كما بالحزمة
  unit           text not null,               -- مثل U1
  chapter        text not null,               -- مثل U1C1
  chapter_index  int  not null,               -- فهرس الفصل بترتيب الحزمة (للتوازن)
  correct_index  int  not null,               -- فهرس الإجابة الصحيحة الأصلي
  options_n      int  not null default 4      -- عدد الخيارات
);
alter table public.content_questions enable row level security;
-- بلا سياسات ⇒ لا وصول مباشر لأي دور؛ الدوال بخدمة service_role تقرأه حصراً.

-- ── ٢) duels — المبارزة نفسها؛ البذرة هي العقد بين الطرفين ──
create table if not exists public.duels (
  id               uuid primary key default gen_random_uuid(),
  room_code        text not null,              -- Crockford-10 مثل K7M2P-9QW4X
  seed             bigint not null,            -- (tag<<50)|code — العقد §٦.٠
  scope            jsonb not null,             -- {units[],count,mode,pack}
  status           text not null default 'lobby'
                   check (status in ('lobby','live','done','void')),
  host_device      uuid not null references public.devices(id) on delete cascade,
  guest_device     uuid references public.devices(id) on delete cascade,
  host_name        text not null default 'المضيف',
  guest_name       text,
  host_score       int,
  guest_score      int,
  winner_device    uuid references public.devices(id),
  host_claim_seq   int,                        -- تسلسل حدث duelWin/duelLoss المقبول
  guest_claim_seq  int,
  created_at       timestamptz not null default now(),
  started_at       timestamptz,
  ended_at         timestamptz
);
-- رمز غرفة نشط واحد فقط (الرمز قد يعاد بعد الإطفاء)
create unique index if not exists duels_active_code_idx
  on public.duels (room_code) where status in ('lobby','live');
create index if not exists duels_participant_idx
  on public.duels (host_device, guest_device);

alter table public.duels enable row level security;

-- القراءة: مبارزات اللوبي متاحة لأي موثق (رمز الغرفة هو الصلاحية — 50 بت)،
-- ومبارزات المشارك متاحة له دائماً.
drop policy if exists "duels_select" on public.duels;
create policy "duels_select" on public.duels
  for select to authenticated
  using (
    status = 'lobby'
    or exists (
      select 1 from public.devices dev
      where dev.profile_id = auth.uid()
        and dev.id in (duels.host_device, coalesce(duels.guest_device, duels.host_device))
    )
  );

-- الإنشاء: المضيف جهازاً له، لوبي فارغ.
drop policy if exists "duels_insert_host" on public.duels;
create policy "duels_insert_host" on public.duels
  for insert to authenticated
  with check (
    exists (select 1 from public.devices dev
            where dev.id = duels.host_device and dev.profile_id = auth.uid())
    and status = 'lobby' and guest_device is null and winner_device is null
  );

-- التحديث: للمشاركين — الأعمدة الحاسمة يحرسها الزناد أدناه.
drop policy if exists "duels_update_participants" on public.duels;
create policy "duels_update_participants" on public.duels
  for update to authenticated
  using (
    exists (
      select 1 from public.devices dev
      where dev.profile_id = auth.uid()
        and dev.id in (duels.host_device, coalesce(duels.guest_device, duels.host_device))
    )
  );

-- زناد الحارس: العميل لا يلمس أبداً (status/scores/winner/seed/claims/started)؛
-- الجلسة (guest) يجلس بلوبي غير ممتلئ وجهازه هو فقط. الخدمة service_role تعبر.
create or replace function public.duels_guard_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.role() = 'service_role' or current_setting('role', true) = 'service_role' then
    return new;
  end if;
  if new.status      is distinct from old.status
     or new.host_score   is distinct from old.host_score
     or new.guest_score  is distinct from old.guest_score
     or new.winner_device is distinct from old.winner_device
     or new.host_claim_seq is distinct from old.host_claim_seq
     or new.guest_claim_seq is distinct from old.guest_claim_seq
     or new.ended_at     is distinct from old.ended_at
     or new.seed         is distinct from old.seed
     or new.scope        is distinct from old.scope
     or new.room_code    is distinct from old.room_code
     or new.host_device  is distinct from old.host_device
     or new.host_name    is distinct from old.host_name
  then
    raise exception 'DUEL_IMMUTABLE' using errcode = 'P0001';
  end if;
  -- بدء المضيف: لوبي فيه الضيف ⇒ live مع طابع بدء حصراً (بلا مس آخر عمود)
  if new.status is distinct from old.status then
    if old.status <> 'lobby' or new.status <> 'live'
       or new.started_at is null
       or old.guest_device is null
       or not exists (select 1 from public.devices dev
                      where dev.id = old.host_device
                        and dev.profile_id = auth.uid()) then
      raise exception 'DUEL_START_FORBIDDEN' using errcode = 'P0001';
    end if;
  elsif new.started_at is distinct from old.started_at then
    -- طابع البدء لا يُمسّ منفرداً — بذرة القنوات الزمنية
    raise exception 'DUEL_IMMUTABLE' using errcode = 'P0001';
  end if;
  if new.guest_device is distinct from old.guest_device then
    if old.status <> 'lobby' or old.guest_device is not null then
      raise exception 'DUEL_FULL' using errcode = 'P0001';
    end if;
    if not exists (select 1 from public.devices dev
                   where dev.id = new.guest_device and dev.profile_id = auth.uid()) then
      raise exception 'DUEL_NOT_YOURS' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists duels_guard_trigger on public.duels;
create trigger duels_guard_trigger
  before update on public.duels
  for each row execute function public.duels_guard_update();

-- ── ٣) duel_answers — إجابات موجّهة نحو الحقيقة الخادمية ──
create table if not exists public.duel_answers (
  duel_id    uuid not null references public.duels(id) on delete cascade,
  device_id  uuid not null references public.devices(id) on delete cascade,
  q_index    int  not null check (q_index between 0 and 49),
  chosen     int  not null check (chosen between 0 and 9),
  answered_at timestamptz not null default now(),
  primary key (duel_id, device_id, q_index)
);
alter table public.duel_answers enable row level security;

drop policy if exists "duel_answers_select" on public.duel_answers;
create policy "duel_answers_select" on public.duel_answers
  for select to authenticated
  using (exists (
    select 1 from public.duels d join public.devices dev on dev.profile_id = auth.uid()
    where d.id = duel_answers.duel_id
      and dev.id in (d.host_device, coalesce(d.guest_device, d.host_device))));

drop policy if exists "duel_answers_insert" on public.duel_answers;
create policy "duel_answers_insert" on public.duel_answers
  for insert to authenticated
  with check (
    exists (select 1 from public.devices dev
            where dev.id = duel_answers.device_id and dev.profile_id = auth.uid())
    and exists (
      select 1 from public.duels d
      where d.id = duel_answers.duel_id and d.status = 'live'
        and duel_answers.device_id in (d.host_device, coalesce(d.guest_device, d.host_device))));

-- ── ٤) duel_status — إعلان «أنهيتُ» (المعلومة الحاسمة للإقفال) ──
create table if not exists public.duel_status (
  duel_id   uuid not null references public.duels(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  done_at   timestamptz not null default now(),
  primary key (duel_id, device_id)
);
alter table public.duel_status enable row level security;

drop policy if exists "duel_status_select" on public.duel_status;
create policy "duel_status_select" on public.duel_status
  for select to authenticated
  using (exists (
    select 1 from public.duels d join public.devices dev on dev.profile_id = auth.uid()
    where d.id = duel_status.duel_id
      and dev.id in (d.host_device, coalesce(d.guest_device, d.host_device))));

drop policy if exists "duel_status_insert" on public.duel_status;
create policy "duel_status_insert" on public.duel_status
  for insert to authenticated
  with check (
    exists (select 1 from public.devices dev
            where dev.id = duel_status.device_id and dev.profile_id = auth.uid())
    and exists (
      select 1 from public.duels d
      where d.id = duel_status.duel_id and d.status = 'live'
        and duel_status.device_id in (d.host_device, coalesce(d.guest_device, d.host_device))));

-- ── ٥) مساعد عضوية قناة المبارزة — للسياسات أدناه (العقد §٧) ──
create or replace function public.duel_participant_of_topic() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.duels d
      join public.devices dev
        on dev.id in (d.host_device, coalesce(d.guest_device, d.host_device))
     where dev.profile_id = auth.uid()
       and d.id::text = split_part(split_part(realtime.topic(), 'duel:', 2), ':', 1)
  );
$$;

-- سياسات القناة الخاصة: تُنشأ إن كان Realtime مفعلاً (جدول realtime.messages).
-- على الاستضافة Realtime مفعّل افتراضياً؛ الرسالة تُفحص SELECT (سماع) وINSERT (بث).
do $$
begin
  if to_regclass('realtime.messages') is not null then
    execute $p$
      drop policy if exists "duel_channel_read" on realtime.messages;
create policy "duel_channel_read" on realtime.messages
        for select to authenticated
        using (
          extension in ('broadcast','presence')
          and public.duel_participant_of_topic()
        );
    $p$;
    execute $p$
      drop policy if exists "duel_channel_write" on realtime.messages;
create policy "duel_channel_write" on realtime.messages
        for insert to authenticated
        with check (
          extension in ('broadcast','presence')
          and public.duel_participant_of_topic()
        );
    $p$;
  else
    raise notice 'realtime.messages غير موجود — فعّل Realtime ثم أعد 0005 (قسم السياسات)';
  end if;
end $$;

-- ── ٦) verify_commit — إعادة إصدار بدعوى XP المبارزة (ذرياً مع الإيداع) ──
-- duelWin: الجهاز فائزٌ موثق لمبارزة done خلال ٤٨ ساعة ولم يدّعِها؛
-- duelLoss: الطرف الآخر. غير ذلك VZ_DUEL ⇒ رفض الدفعة كلها (docs/12 §٨-4).
create or replace function public.verify_commit(
  p_device uuid, p_events jsonb,
  p_expect_last_seq int, p_expect_last_hash text,
  p_server_ms bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_seq  int;
  v_last_hash text;
  v_ev        jsonb;
  i           int;
begin
  -- إعادة الفحص داخل المعاملة (لا ثقة بالقراءة السابقة)
  select coalesce(max(seq), 0), coalesce(
    (select hash from public.xp_events e2
     where e2.device_id = p_device order by seq desc limit 1), 'GENESIS')
    into v_last_seq, v_last_hash
    from public.xp_events e where e.device_id = p_device;

  if v_last_seq <> p_expect_last_seq or v_last_hash is distinct from p_expect_last_hash then
    raise exception 'VZ_GAP' using errcode = 'P0001';
  end if;

  for i in 0 .. jsonb_array_length(p_events) - 1 loop
    v_ev := p_events -> i;
    if (v_ev ->> 'prevHash') is distinct from v_last_hash then
      raise exception 'VZ_GAP' using errcode = 'P0001';
    end if;
    insert into public.xp_events
      (device_id, seq, type, ts, payload, prev_hash, hash, sig)
    values (
      p_device,
      (v_ev ->> 'seq')::int,
      v_ev ->> 'type',
      (v_ev ->> 'ts')::bigint,
      v_ev -> 'payload',
      v_ev ->> 'prevHash',
      v_ev ->> 'hash',
      v_ev ->> 'sig'
    );

    -- دعوى XP المبارزة — داخل المعاملة نفسها (لا نافذة تسرب)
    if (v_ev ->> 'type') = 'duelWin' then
      update public.duels d
         set winner_claim_seq = (v_ev ->> 'seq')::int
       where d.id = (v_ev -> 'payload' ->> 'duelId')::uuid
         and d.status = 'done'
         and d.winner_device = p_device
         and d.winner_claim_seq is null
         and d.ended_at > now() - interval '48 hours';
      if not found then
        raise exception 'VZ_DUEL' using errcode = 'P0001';
      end if;
    elsif (v_ev ->> 'type') = 'duelLoss' then
      update public.duels d
         set guest_claim_seq = case when d.guest_device = p_device
                                    then (v_ev ->> 'seq')::int
                                    else d.guest_claim_seq end,
             host_claim_seq = case when d.host_device = p_device
                                   then (v_ev ->> 'seq')::int
                                   else d.host_claim_seq end
       where d.id = (v_ev -> 'payload' ->> 'duelId')::uuid
         and d.status = 'done'
         and d.winner_device is not null
         and d.winner_device <> p_device
         and p_device in (d.host_device, coalesce(d.guest_device, d.host_device))
         and case when d.guest_device = p_device then d.guest_claim_seq else d.host_claim_seq end is null
         and d.ended_at > now() - interval '48 hours';
      if not found then
        raise exception 'VZ_DUEL' using errcode = 'P0001';
      end if;
    end if;

    v_last_seq  := (v_ev ->> 'seq')::int;
    v_last_hash := v_ev ->> 'hash';
  end loop;

  insert into public.time_anchors (device_id, last_server_ms)
    values (p_device, p_server_ms)
    on conflict (device_id) do update
      set last_server_ms = excluded.last_server_ms, updated_at = now();

  return jsonb_build_object('synced_up_to', v_last_seq);
end;
$$;


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0006_office_audit.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ═══════════════════════════════════════════════════════════════════
-- 0006_office_audit — سجل إجراءات أداة المكتب (F6.1 — قرار ٣٤ POS).
-- كل توليد/إلغاء كود يُسجَّل هنا: أثر تدقيق للـplaybook (قرار ٣٢ —
-- الموزّع مرمّز بالكود والعلامة المائية تُتَّبع من هذا السجل).
-- RLS سلبية: بلا سياسات إطلاقاً ⇒ لا يقرأه إلا service_role/المالك —
-- وهذا مقصود (قرار F7.4: RLS سالبة للجداول الإدارية).
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.office_audit (
  id          bigint generated always as identity primary key,
  ts          timestamptz not null default now(),
  action      text not null check (action in ('generate', 'revoke')),
  codes       text[] not null default '{}',
  distributor text not null default 'مكتب لورانيم',
  note        text
);

alter table public.office_audit enable row level security;


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0007_input_hardening.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ═══════════════════════════════════════════════════════════════════════
-- 0007 — تدقيق الحقن (F7.4 — 2026-09-14): قيود شكل على كل عمود يكتبه العميل
-- مباشرة عبر PostgREST. الطبقة الأخيرة بعد RLS والزناد: حتى لو تجاوز أحدٌ
-- واجهة التطبيق، لا يمر إلى القاعدة إلا القيم المطابقة للعقد حجماً وشكلاً.
-- idempotent — إعادة التشغيل آمنة.
-- ═══════════════════════════════════════════════════════════════════════

-- ── duels: الأعمدة التي يكتبها المضيف عند الإنشاء ──
do $$
begin
  if to_regclass('public.duels') is null then
    raise notice 'duels غير موجود بعد — طبّق 0005 أولاً ثم أعد 0007';
    return;
  end if;

  -- رمز الغرفة: Crockford-10 بشرطة بعد الخامسة حصراً (K7M2P-9QW4X)
  alter table public.duels drop constraint if exists duels_room_code_format;
  alter table public.duels add constraint duels_room_code_format
    check (room_code ~ '^[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$');

  -- البذرة: موجبة ودون 2^63 (tag<<50 | code) — العقد §٦.٠
  alter table public.duels drop constraint if exists duels_seed_range;
  alter table public.duels add constraint duels_seed_range
    check (seed >= 0);

  -- النطاق: كائن jsonb صغير بشكل معروف: units مصفوفة ≤ 5، count 1..50
  alter table public.duels drop constraint if exists duels_scope_shape;
  alter table public.duels add constraint duels_scope_shape
    check (
      jsonb_typeof(scope) = 'object'
      and jsonb_typeof(scope -> 'units') = 'array'
      and jsonb_array_length(scope -> 'units') between 1 and 5
      and jsonb_typeof(scope -> 'count') = 'number'
      and (scope ->> 'count')::int between 1 and 50
      and length(scope::text) <= 512
    );

  -- الأسماء المعروضة: طول محدود (تُعرض بـ Text فقط — بلا HTML — لكن لا نسمح بسيل)
  alter table public.duels drop constraint if exists duels_host_name_len;
  alter table public.duels add constraint duels_host_name_len
    check (char_length(host_name) between 1 and 40);
  alter table public.duels drop constraint if exists duels_guest_name_len;
  alter table public.duels add constraint duels_guest_name_len
    check (guest_name is null or char_length(guest_name) between 1 and 40);
end $$;

-- ── xp_events: نوع من قائمة معروفة + حجم حمولة محدود ──
-- (verify_xp_events يرفض UNKNOWN_TYPE قبل الإيداع؛ هذا قفل ثانٍ على القاعدة)
alter table public.xp_events drop constraint if exists xp_events_type_known;
alter table public.xp_events add constraint xp_events_type_known
  check (type ~ '^[a-zA-Z]{2,32}$');
alter table public.xp_events drop constraint if exists xp_events_payload_size;
alter table public.xp_events add constraint xp_events_payload_size
  check (length(payload::text) <= 2048);
alter table public.xp_events drop constraint if exists xp_events_hash_hex;
alter table public.xp_events add constraint xp_events_hash_hex
  check (hash ~ '^[0-9a-f]{64}$' and (prev_hash = 'GENESIS' or prev_hash ~ '^[0-9a-f]{64}$'));
alter table public.xp_events drop constraint if exists xp_events_sig_b64;
alter table public.xp_events add constraint xp_events_sig_b64
  check (sig ~ '^[A-Za-z0-9+/]{86}==$');

-- ── devices: المفتاح العام base64 لـ32 بايت حصراً + بصمة محدودة ──
alter table public.devices drop constraint if exists devices_pubkey_b64_format;
alter table public.devices add constraint devices_pubkey_b64_format
  check (pubkey_b64 ~ '^[A-Za-z0-9+/]{43}=$');
alter table public.devices drop constraint if exists devices_fp_len;
alter table public.devices add constraint devices_fp_len
  check (char_length(device_fp) between 8 and 128);

-- ── profiles: اسم العرض محدود (السياسة تسمح للمالك بتحديثه) ──
alter table public.profiles drop constraint if exists profiles_display_name_len;
alter table public.profiles add constraint profiles_display_name_len
  check (char_length(display_name) between 1 and 40);

-- ── activation_codes: شكل الكود (تكتبه أداة المكتب فقط — قفل إضافي) ──
alter table public.activation_codes drop constraint if exists activation_codes_format;
alter table public.activation_codes add constraint activation_codes_format
  check (code ~ '^[0-9A-HJ-KM-NP-TV-Z]{15}$');


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0008_review_codes.sql
-- └───────────────────────────────────────────────────────────────────┘

-- 0008 — أكواد المراجعة (قرار ٥٥ — 2026-09-15)
-- كود تفعيل موسوم review=true ⇒ التوكن الموقّع يحمل العلم 'teacher'
-- ⇒ على ذلك الجهاز تفتح «٥ نقرات» وضع المراجعة بدل لوحة الإدارة.
-- لا يغيّر شيئاً للأكواد القائمة (الافتراضي false).
alter table public.activation_codes
  add column if not exists review boolean not null default false;

-- تحقق (اقرأ فقط):
-- select column_name, column_default from information_schema.columns
--  where table_name='activation_codes' and column_name='review';


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0009_arena_points.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- 0009 — اقتصاد النقاط (قرار ٦٠): «الفاصل هو التحديات»
--
-- المشكلة قبل هذه الهجرة: league_rollup_week كان يجمع **كل** أحداث XP،
-- فكانت نقاط التدريب والبطاقات تدخل الترتيب الأسبوعي — وهذا ينقض القرار:
-- «التدريب = نقاط تعلّم شخصية بلا جوائز؛ التحديات هي مصدر النقاط
-- التنافسية الوحيد».
--
-- بعدها: الترتيب يقرأ أنواع arena حصراً — challengeQ (النقاط التناقصية)
-- و duelWin/duelLoss (الفوز وحده يُكافأ: ٤٥ / الخسارة ٠).
-- بقية الأحداث تُودَع وتُتقاعد زمنياً كالسابق بلا تغيير.
--
-- ⚠️ ٢٠٢٦-٠٩-١٥: هذا الجزء **بلا أي اعتماد على public.duels** — لأن
-- 0005_duels.sql غير مطبَّقة على السيرفر أصلاً (docs/16 بند ١١: ⬜ بانتظار
-- المالك). قاعدة «الخصم مرة/يوم» + verify_commit الموسّعة نُقلت إلى
-- 0010_duel_points.sql — تُطبَّق بعد 0005 حصراً.
-- ════════════════════════════════════════════════════════════════════

-- ── ١) تصنيف الأنواع: تنافسي (arena) أم تعلّم شخصي؟ ──
-- المرجع المطابق: app/lib/core/xp/xp_ledger.dart (حقل arena) — أي إضافة
-- نوع جديد هناك تُضاف هنا، وإلا سقط من الترتيب بصمت.
create or replace function public.is_arena_type(p_type text)
returns boolean
language sql
immutable
parallel safe
set search_path = public
as $$
  select p_type in ('challengeQ', 'challengeAbandon', 'duelWin', 'duelLoss');
$$;

comment on function public.is_arena_type(text) is
  'قرار ٦٠: أنواع النقاط التنافسية — التحديات والمبارزات وحدها تدخل لوحة الأسبوع.';

-- ── ٢) إعادة إصدار league_rollup_week مع الفلتر ──
-- (التوقيع لم يتغيّر ⇒ create or replace يحفظ السياسات والصلاحيات.)
create or replace function public.league_rollup_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_closed_start date;   -- بداية الأسبوع المغلق (اثنين)
  v_week_id      int;    -- IYYYIW مثل 202637
  v_devices      int;
begin
  -- الأسبوع المغلق = الأسبوع الذي انتهى قبل ساعة (بتوقيت دمشق)
  v_closed_start := date_trunc('week',
      (now() at time zone 'Asia/Damascus') - interval '1 hour')::date;
  v_week_id := to_char(v_closed_start, 'IYYYIW')::int;

  -- ١) المجاميع الأسبوعية — **نقاط التحديات حصراً** (قرار ٦٠)
  insert into public.weekly_totals (device_id, iso_week, xp, events_n)
  select e.device_id, v_week_id,
         sum((e.payload ->> 'points')::int), count(*)
    from public.xp_events e
   where public.is_arena_type(e.type)
     and e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
   group by e.device_id
  on conflict (device_id, iso_week) do update
    set xp = excluded.xp, events_n = excluded.events_n;

  -- ٢) الترتيب: مجموع نقاط التحديات تنازلياً — مجموعات ٣٠ متتالية (قرار ٤١)
  --    ترتيب **نسبي** ويُصفَّر كل اثنين: كل أسبوع صفحة جديدة بـ iso_week.
  delete from public.league_standings where iso_week = v_week_id;
  insert into public.league_standings
    (iso_week, group_no, rank_no, device_id, xp)
  select v_week_id,
         ((row_number() over (order by t.xp desc, t.device_id) - 1) / 30) + 1,
         row_number() over (order by t.xp desc, t.device_id),
         t.device_id, t.xp
    from (
      select device_id, sum(xp) as xp
        from public.weekly_totals where iso_week = v_week_id
       group by device_id
    ) t;

  -- ٣) تقاعد أحداث الأسبوع المغلق (F4.1 — القاعدة < 100MB دائماً)
  --    كل الأحداث (تعلّم وتحديات) — التقاعد زمني فقط، لا علاقة له بالترتيب.
  delete from public.xp_events e
   where e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint;

  select count(*) into v_devices from public.league_standings
    where iso_week = v_week_id;
  return jsonb_build_object('week', v_week_id, 'devices', v_devices);
end;
$$;

-- ── ٣) فهارس فحوص التحدي الجديدة في verify_xp_events ──
-- الفحص يُنفَّذ مرة لكل حدث مزامَن: (challengeId) للإقفال بالمغادرة،
-- و(challengeId, qIndex) لمنح النقاط مرة واحدة لكل سؤال.
create index if not exists xp_events_challenge_idx
  on public.xp_events ((payload ->> 'challengeId'))
  where type in ('challengeQ', 'challengeAbandon');

create index if not exists xp_events_challenge_q_idx
  on public.xp_events ((payload ->> 'challengeId'), (payload ->> 'qIndex'))
  where type = 'challengeQ';

-- ── ٤) تحصين: الدالة التنفيذية لـ service_role حصراً (كبقية دوال 0002) ──
revoke execute on function public.is_arena_type(text) from public;


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0010_duel_points.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- 0010 — «الخصم نفسه مرة/يوم للنقاط» (قرار ٦٠) — حكم خادمي ذري
--
-- ⚠️ **لا تُطبَّق قبل 0005_duels.sql** — تعتمد على public.duels.
-- (اكتُشف ٢٠٢٦-٠٩-١٥ أن 0005 غير مطبَّقة: docs/16 بند ١١ ⬜.)
--
-- لماذا هنا لا في الدالة الطرفية؟ لأن الخصم **لا يُعرف إلا من صف المبارزة**
-- (host_device/guest_device) — فأي ادعاء من الجهاز باسم خصمه لا قيمة له.
-- الفحص داخل verify_commit ⇒ ذريّ مع الإيداع: لا نافذة تسرب بين الفحص والكتابة.
-- ════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regclass('public.duels') is null then
    raise exception
      'STOP: طبّق supabase/migrations/0005_duels.sql أولاً — public.duels غير موجود';
  end if;
end $$;

-- ── ٥) «الخصم نفسه مرة/يوم للنقاط» (قرار ٦٠) — حكم خادمي ذري ──
-- لماذا هنا لا في الدالة الطرفية؟ لأن الخصم **لا يُعرف إلا من صف المبارزة**
-- (host_device/guest_device) — فأي ادعاء من الجهاز باسم خصمه لا قيمة له.
-- الفحص داخل verify_commit ⇒ ذريّ مع الإيداع: لا نافذة تسرب بين الفحص والكتابة.

-- خصم هذا الجهاز في مبارزة معيّنة (من صف المبارزة حصراً).
create or replace function public.duel_opponent_of(p_duel uuid, p_device uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select case
           when d.host_device = p_device
             then coalesce(d.guest_device, d.host_device)
           else d.host_device
         end
    from public.duels d
   where d.id = p_duel;
$$;

-- كم مرة أخذ هذا الجهاز نقاط مبارزة في هذا اليوم مع **الخصم نفسه**؟
create or replace function public.duel_points_today_with(
  p_device uuid, p_duel uuid, p_date_key text
) returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
    from public.xp_events e
   where e.device_id = p_device
     and e.type in ('duelWin', 'duelLoss')
     and (e.payload ->> 'dateKey') = p_date_key
     and exists (
       select 1
         from public.duels d2
        where d2.id = (e.payload ->> 'duelId')::uuid
          and public.duel_opponent_of(d2.id, p_device)
            = public.duel_opponent_of(p_duel, p_device)
     );
$$;

create or replace function public.verify_commit(
  p_device uuid, p_events jsonb,
  p_expect_last_seq int, p_expect_last_hash text,
  p_server_ms bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_seq  int;
  v_last_hash text;
  v_ev        jsonb;
  i           int;
  v_dk        text;   -- مفتاح اليوم (لقاعدة «الخصم مرة/يوم»)
  v_opp_n     int;    -- عدد مرات أخذ النقاط مع الخصم نفسه اليوم
begin
  -- إعادة الفحص داخل المعاملة (لا ثقة بالقراءة السابقة)
  select coalesce(max(seq), 0), coalesce(
    (select hash from public.xp_events e2
     where e2.device_id = p_device order by seq desc limit 1), 'GENESIS')
    into v_last_seq, v_last_hash
    from public.xp_events e where e.device_id = p_device;

  if v_last_seq <> p_expect_last_seq or v_last_hash is distinct from p_expect_last_hash then
    raise exception 'VZ_GAP' using errcode = 'P0001';
  end if;

  for i in 0 .. jsonb_array_length(p_events) - 1 loop
    v_ev := p_events -> i;
    if (v_ev ->> 'prevHash') is distinct from v_last_hash then
      raise exception 'VZ_GAP' using errcode = 'P0001';
    end if;
    insert into public.xp_events
      (device_id, seq, type, ts, payload, prev_hash, hash, sig)
    values (
      p_device,
      (v_ev ->> 'seq')::int,
      v_ev ->> 'type',
      (v_ev ->> 'ts')::bigint,
      v_ev -> 'payload',
      v_ev ->> 'prevHash',
      v_ev ->> 'hash',
      v_ev ->> 'sig'
    );

    -- ═══ قرار ٦٠: «الخصم نفسه مرة/يوم للنقاط» ═══
    -- الخصم يُستنتج من صف المبارزة نفسه لا من حمولة الجهاز (لا ثقة بالعميل).
    -- الخرق ⇒ رفض الدفعة كلها (docs/12 §٨-4: أي خلل = رفض ١٠٠٪).
    if (v_ev ->> 'type') in ('duelWin', 'duelLoss') then
      v_dk := v_ev -> 'payload' ->> 'dateKey';
      if v_dk is null or v_dk !~ '^\d{4}-\d{2}-\d{2}$' then
        raise exception 'VZ_DUEL_DATEKEY' using errcode = 'P0001';
      end if;
      v_opp_n := public.duel_points_today_with(
        p_device, (v_ev -> 'payload' ->> 'duelId')::uuid, v_dk);
      if v_opp_n > 0 then
        raise exception 'VZ_DUEL_OPP_DAY' using errcode = 'P0001';
      end if;
    end if;

    -- دعوى XP المبارزة — داخل المعاملة نفسها (لا نافذة تسرب)
    if (v_ev ->> 'type') = 'duelWin' then
      update public.duels d
         set winner_claim_seq = (v_ev ->> 'seq')::int
       where d.id = (v_ev -> 'payload' ->> 'duelId')::uuid
         and d.status = 'done'
         and d.winner_device = p_device
         and d.winner_claim_seq is null
         and d.ended_at > now() - interval '48 hours';
      if not found then
        raise exception 'VZ_DUEL' using errcode = 'P0001';
      end if;
    elsif (v_ev ->> 'type') = 'duelLoss' then
      update public.duels d
         set guest_claim_seq = case when d.guest_device = p_device
                                    then (v_ev ->> 'seq')::int
                                    else d.guest_claim_seq end,
             host_claim_seq = case when d.host_device = p_device
                                   then (v_ev ->> 'seq')::int
                                   else d.host_claim_seq end
       where d.id = (v_ev -> 'payload' ->> 'duelId')::uuid
         and d.status = 'done'
         and d.winner_device is not null
         and d.winner_device <> p_device
         and p_device in (d.host_device, coalesce(d.guest_device, d.host_device))
         and case when d.guest_device = p_device then d.guest_claim_seq else d.host_claim_seq end is null
         and d.ended_at > now() - interval '48 hours';
      if not found then
        raise exception 'VZ_DUEL' using errcode = 'P0001';
      end if;
    end if;

    v_last_seq  := (v_ev ->> 'seq')::int;
    v_last_hash := v_ev ->> 'hash';
  end loop;

  insert into public.time_anchors (device_id, last_server_ms)
    values (p_device, p_server_ms)
    on conflict (device_id) do update
      set last_server_ms = excluded.last_server_ms, updated_at = now();

  return jsonb_build_object('synced_up_to', v_last_seq);
end;
$$;


-- ── ٦) تحصين: الدوال التنفيذية لـ service_role حصراً (كبقية دوال 0002) ──
revoke execute on function public.duel_opponent_of(uuid, uuid) from public;
revoke execute on function public.duel_points_today_with(uuid, uuid, text) from public;


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0011_season_standings.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- 0011 — ترتيب الموسم التراكمي (قرار ٦٥)
--
-- نصّ المالك (٢٠٢٦-٠٩-١٥): «النقاط تراكمية لكل السنة الدراسية ويلي
-- بيفوز بأول مركزين بيربح الجوائز فقط» + «ما في جوائز أسبوعية — خلينا
-- نرجع نصمم نظام الجوائز بالتفصيل».
--
-- ⇒ هذا ينسخ ثلاثة أشياء كانت مثبَّتة قبل اليوم:
--   ١) «يُصفَّر كل اثنين» (قرار ٦٠)  ⇒ الترتيب **تراكمي طوال الموسم**.
--   ٢) «مجموعات ~٣٠ طالباً»         ⇒ **لوحة واحدة بلا مجموعات**.
--      ⚠️ هذا الرقم كان بلا قرار أصلاً: docs/12 §٤.٣ كان يُحيل إلى «قرار ٤١»
--      وهو في الحقيقة عن منهجية البحث والشبكات (Nearby/ألعاب المسابقات)،
--      لا عن الدوري. أُصلحت الإحالة في docs/12 بهذه الهجرة.
--   ٣) جوائز أسبوعية                ⇒ **لا جوائز أسبوعية**؛ نظام الجوائز
--      يُصمَّم لاحقاً بقرار مستقل.
--
-- التصميم: `weekly_totals` يبقى أرشيفاً أسبوعياً **لا يُحذف** — فهو مادة
-- التراكم. والترتيب يُحسب من مجموع كل أسابيع الموسم ⇒ تقاعد الأحداث
-- الأسبوعي (F4.1) مستمر بلا فقدان أي نقطة.
-- ════════════════════════════════════════════════════════════════════

-- ── ١) الموسم الدراسي: ١ أيلول ← ٣١ آب (مثل '2026-2027') ──
create or replace function public.current_season(p_at timestamptz default now())
returns text
language sql
stable
set search_path = public
as $$
  select v_y::text || '-' || (v_y + 1)::text
    from (select (extract(year from v_d)::int
                  - case when extract(month from v_d)::int >= 9
                         then 0 else 1 end) as v_y
            from (select (p_at at time zone 'Asia/Damascus')::date as v_d) t1) t2;
$$;

comment on function public.current_season(timestamptz) is
  'قرار ٦٥: الموسم الدراسي يبدأ ١ أيلول — كل نقاطه تراكمية في لوحة واحدة.';

-- ── ٢) عمود الموسم على الأرشيف الأسبوعي ──
alter table public.weekly_totals add column if not exists season text;
update public.weekly_totals
   set season = public.current_season()
 where season is null;
alter table public.weekly_totals
  alter column season set default public.current_season();

create index if not exists weekly_totals_season_idx
  on public.weekly_totals (season);

-- ── ٣) إعادة إصدار league_rollup_week: ترتيب تراكمي بلا مجموعات ──
-- (التوقيع لم يتغيّر ⇒ create or replace يحفظ السياسات والصلاحيات.)
create or replace function public.league_rollup_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_closed_start date;   -- بداية الأسبوع المغلق (اثنين)
  v_week_id      int;    -- IYYYIW مثل 202638
  v_season       text;   -- '2026-2027'
  v_devices      int;
begin
  -- الأسبوع المغلق = الأسبوع الذي انتهى قبل ساعة (بتوقيت دمشق)
  v_closed_start := date_trunc('week',
      (now() at time zone 'Asia/Damascus') - interval '1 hour')::date;
  v_week_id := to_char(v_closed_start, 'IYYYIW')::int;
  v_season  := public.current_season(
      v_closed_start::timestamp at time zone 'Asia/Damascus');

  -- ١) الأرشيف الأسبوعي — **يبقى ولا يُحذف** (هو مادة التراكم — قرار ٦٥)
  insert into public.weekly_totals (device_id, iso_week, season, xp, events_n)
  select e.device_id, v_week_id, v_season,
         sum((e.payload ->> 'points')::int), count(*)
    from public.xp_events e
   where public.is_arena_type(e.type)
     and e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
   group by e.device_id
  on conflict (device_id, iso_week) do update
    set xp = excluded.xp, events_n = excluded.events_n,
        season = excluded.season;

  -- ٢) الترتيب **التراكمي للموسم كله** (قرار ٦٥) — لوحة واحدة بلا مجموعات.
  --    group_no ثابت = ١ (لا مجموعات)؛ وحُذف القسم على ٣٠ نهائياً.
  delete from public.league_standings where iso_week = v_week_id;
  insert into public.league_standings
    (iso_week, group_no, rank_no, device_id, xp)
  select v_week_id, 1,
         row_number() over (order by t.xp desc, t.device_id),
         t.device_id, t.xp
    from (
      select device_id, sum(xp) as xp
        from public.weekly_totals
       where coalesce(season, public.current_season()) = v_season
       group by device_id
    ) t;

  -- ٣) تقاعد أحداث الأسبوع المغلق (F4.1 — القاعدة < 100MB دائماً)
  --    آمن تماماً: النقاط محفوظة في weekly_totals قبل الحذف.
  delete from public.xp_events e
   where e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint;

  select count(*) into v_devices from public.league_standings
    where iso_week = v_week_id;
  return jsonb_build_object(
    'week', v_week_id, 'season', v_season, 'devices', v_devices);
end;
$$;

-- ── ٤) تحصين: service_role حصراً (كبقية دوال 0002) ──
revoke execute on function public.current_season(timestamptz) from public;


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0012_device_x25519.sql
-- └───────────────────────────────────────────────────────────────────┘

-- F2.2-T2 (قرار ٣٠/٦٧ — docs/16 §١٠): مفتاح X25519 العام لكل جهاز
-- يُرفع عند التفعيل ويُستعمل لتغليف K_c (kc_wrap_v1). null للأجهزة القديمة
-- حتى أول heartbeat يحمل device_x25519_pub_b64.
alter table public.devices
  add column if not exists x25519_pub_b64 text
  check (x25519_pub_b64 is null or length(x25519_pub_b64) = 44);


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0013_activation_customer.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ═══════════════════════════════════════════════════════════════════
-- 0013 — نقطة البيع (F6.1-POS · قرار ٣٤): اسم الزبون على كود التفعيل.
-- عند البيع وجهاً لوجه يكتب المكتب اسم الطالب (وهاتفه اختياراً) ليعرف
-- لاحقاً «كود مَن هذا؟» عند الإلغاء أو الدعم. نص حر ≤ ٨٠ محرفاً — لا
-- يُرسل للعميل أبداً (activation_codes بلا سياسات قراءة — RLS سالبة).
-- ═══════════════════════════════════════════════════════════════════
alter table public.activation_codes
  add column if not exists customer text
  check (customer is null or char_length(customer) <= 80);

comment on column public.activation_codes.customer is
  'F6.1-POS: اسم/هاتف الزبون كما كتبه المكتب عند البيع — للمكتب حصراً.';


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0014_certificates.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ═══════════════════════════════════════════════════════════════════════
-- 0014 — F6.3: مواسم وشهادات الموسم الموقعة (docs/14 §٥ + سطر F6.3).
-- الشهادة تُصدر نهاية موسم مُغلق حصراً عبر دالة cert_issue وحدها (service
-- role)، والقراءة عامة عبر المعرف — uuid غير منخمص (§٥: «قراءة عامة للشهادة
-- عبر معرفها»). لا سياسة إدراج/تعديل للعميل إطلاقاً.
-- الغرس نموذجي (التاريخ بيد المالك — لا نخمّن موعد الامتحان):
--   insert into public.seasons(name, ends_on)
--   values ('2026-2027', date '2027-04-01')
--   on conflict (name) do nothing;
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.seasons (
  name    text primary key,      -- ناتج current_season(): '2026-2027'
  ends_on date                   -- إغلاق = مضي ends_on (null = الموسم مفتوح)
);

create table if not exists public.certificates (
  id          uuid primary key,
  season      text not null references public.seasons(name),
  device_id   uuid not null references public.devices(id) on delete cascade,
  tier        text not null check (tier in ('gold_two', 'silver_one')),
  years       int  not null check (years between 1 and 2),
  xp          bigint not null default 0,
  payload     jsonb not null,    -- الحمولة كما وُقّعت عليها بالضبط
  signature   text not null,     -- base64 — Ed25519 detached
  issued_at   timestamptz not null default now(),
  unique (season, device_id)     -- idempotency: شهادة واحدة لكل جهاز/موسم
);

create index if not exists certificates_device_idx
  on public.certificates(device_id);

alter table public.seasons      enable row level security;
alter table public.certificates enable row level security;

-- قراءة عامة (المعرف uuid غير منخمص) — الكتابة service role وحده (cert_issue).
create policy certificates_public_read
  on public.certificates for select using (true);
create policy seasons_public_read
  on public.seasons for select using (true);

comment on table public.certificates is
  'F6.3: شهادة «بطل دوري فيزيا كلاش» — حمولة canonical موقّعة Ed25519، إصدار cert_issue حصراً (موسم مُغلق)، قراءة عامة عبر المعرف.';
comment on table public.seasons is
  'F6.3: نهاية الموسم (قرار ٣٦ — موسم ينتهي قبل الامتحان بشهر؛ ends_on بيد المالك).';


-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0015_certificates_rls.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ═══════════════════════════════════════════════════════════════════════
-- 0015 — F6.3-أمن (2026-09-22): تضييق قراءة الشهادات والموسم + تحصين cron.
--
-- خلفية: مدقّق Supabase (auth_allow_anonymous_sign_ins) يُطلق تحذيراً لأي
-- سياسة تسمح للدور anon. التطبيق يستخدم الدخول المجهول كوسيلة الدخول الوحيدة،
-- فسياسات *_select_own على devices/licenses/profiles/xp_events/weekly_totals/
-- league_standings **مقصودة وسليمة** (كلٌّ يقرأ بياناته عبر auth.uid()) —
-- لا تُلمس، فحصرها يعطّل التطبيق. هذا الترحيل يعالج الحالات الحقيقية فقط:
--
--   ١) certificates: كانت using(true) ⇒ تعداد كامل (device_id·xp·payload·
--      signature لكل طالب). ⇐ سياسة ملكية.
--   ٢) seasons: كانت using(true). العميل لا يقرؤها مباشرة (كل الوصول عبر
--      cert_issue بservice role) ⇒ نحصرها بالمفعّلين بلا كسر شيء، فيسكت
--      التحذير ويُقفل التعداد المجهول.
--   ٣) cron.job / cron.job_run_details: جداول pg_cron الداخلية. لا يجوز أن
--      يصلها anon/authenticated ⇒ نلغي أي صلاحية لهما على schema cron.
-- ═══════════════════════════════════════════════════════════════════════

-- ── ١) الشهادات: قراءة صاحبها حصراً (بدل using(true) في 0014) ──
drop policy if exists certificates_public_read on public.certificates;

create policy certificates_select_own
  on public.certificates for select using (exists (
    select 1 from public.devices d
    where d.id = certificates.device_id and d.profile_id = auth.uid()
  ));

comment on policy certificates_select_own on public.certificates is
  'F6.3-أمن: كل جهاز يقرأ شهادته عبر ملفه الشخصي — لا تعداد عام (بدل using(true) في 0014).';

-- ── ٢) الموسم: المفعّلون حصراً (العميل لا يقرؤه مباشرة — الوصول عبر الدوال) ──
-- لا بيانات شخصية فيه (اسم + ends_on)، لكن حصره يُقفل التعداد المجهول
-- ويُسكِت تحذير المدقّق دون أثر وظيفي.
drop policy if exists seasons_public_read on public.seasons;

create policy seasons_select_licensed
  on public.seasons for select to authenticated using (exists (
    select 1 from public.devices d
    join public.licenses l on l.device_id = d.id and l.revoked = false
    where d.profile_id = auth.uid()
  ));

comment on policy seasons_select_licensed on public.seasons is
  'F6.3-أمن: قراءة الموسم للمفعّلين — العميل يصله عبر cert_issue (service role) لا مباشرة.';

-- ── ٣) تحصين cron: لا وصول لـanon/authenticated إلى جداول pg_cron الداخلية ──
-- (سياسات افتراضية من الإضافة؛ نلغي التعريض احتياطاً. الحارس: schema cron
--  يجب ألّا يكون ضمن exposed schemas بإعدادات API — يُراجَع باللوحة أيضاً.)
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'cron') then
    begin
      execute 'revoke all on all tables in schema cron from anon, authenticated';
      execute 'revoke usage on schema cron from anon, authenticated';
    exception when insufficient_privilege or others then
      -- schema cron مملوك لـsupabase_admin أحياناً: لا نُفشل الترحيل — يُراجَع
      -- التعريض باللوحة (Settings → API → Exposed schemas: أزِل cron).
      raise notice 'cron hardening skipped (privilege): review Exposed schemas in dashboard';
    end;
  end if;
end $$;



-- ┌───────────────────────────────────────────────────────────────────┐
-- │  0016_office_audit_season.sql
-- └───────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════
-- 0016 — توسيع سجل تدقيق المكتب ليشمل ضبط نهاية الموسم (F6.6)
--
-- الخلفية: `office_audit.action` كان مقيّداً بـ('generate','revoke') فقط
-- (0006). دالة office_codes أضافت إجراء 'season_set' (تعديل ends_on للموسم
-- من داخل التطبيق — قرار ٣٦: الإغلاق بيد المالك). هذا الإجراء حسّاس (إغلاق
-- الموسم يفتح إصدار الشهادات) فيجب أن يُدوَّن ⇒ نوسّع قيد CHECK ليقبله.
--
-- إعادة التشغيل آمنة: نُسقط القيد إن وُجد ثم نعيد إنشاءه بالقائمة الموسّعة.
-- ════════════════════════════════════════════════════════════════════

alter table public.office_audit
  drop constraint if exists office_audit_action_check;

alter table public.office_audit
  add constraint office_audit_action_check
  check (action in ('generate', 'revoke', 'season_set'));

comment on constraint office_audit_action_check on public.office_audit is
  'F6.6: أُضيف season_set (تدقيق ضبط نهاية الموسم) إلى القائمة المسموحة.';
