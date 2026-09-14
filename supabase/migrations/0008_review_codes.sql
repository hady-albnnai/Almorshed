-- 0008 — أكواد المراجعة (قرار ٥٥ — 2026-09-15)
-- كود تفعيل موسوم review=true ⇒ التوكن الموقّع يحمل العلم 'teacher'
-- ⇒ على ذلك الجهاز تفتح «٥ نقرات» وضع المراجعة بدل لوحة الإدارة.
-- لا يغيّر شيئاً للأكواد القائمة (الافتراضي false).
alter table public.activation_codes
  add column if not exists review boolean not null default false;

-- تحقق (اقرأ فقط):
-- select column_name, column_default from information_schema.columns
--  where table_name='activation_codes' and column_name='review';
