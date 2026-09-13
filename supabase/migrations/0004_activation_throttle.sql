-- ════════════════════════════════════════════════════════════════════
-- 0004 — تقييد محاولات التفعيل (مضاد التعداد القسري — NIST 800-63B:
-- throttling حسب المُرسل). 5 محاولات فاشلة/١٥ دقيقة لكل مستخدم.
-- يطبقه license_activate: يفحص قبل الرد ويُسجل كل فشل ACT_CODE_*.
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.activation_attempts (
  id     bigint generated always as identity primary key,
  user_id uuid not null,          -- الملف المجهول للمهاجم (JWT إلزامي)
  code   text not null,          -- الكود المجرَّب (تتبع أنماط الهجوم)
  ts     timestamptz not null default now()
);
create index if not exists activation_attempts_user_ts_idx
  on public.activation_attempts(user_id, ts);

-- مقفولة كلياً عن العملاء — service_role (عبر الدالة) حصراً
alter table public.activation_attempts enable row level security;

-- استعلام الفحص (تستدعيه الدالة):
--   select count(*) from public.activation_attempts
--    where user_id = <uid> and ts > now() - interval '15 minutes';
-- الحذف الدوري (تستدعيه الدالة بعد كل إدراج — توفير مساحة الخطة المجانية):
--   delete from public.activation_attempts where ts < now() - interval '24 hours';
