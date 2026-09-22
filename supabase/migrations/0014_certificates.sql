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
