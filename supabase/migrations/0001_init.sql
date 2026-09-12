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
