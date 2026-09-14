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
