-- ════════════════════════════════════════════════════════════════════
-- تشخيص حيّ قبل تطبيق 0009 — الصق الكل في SQL Editor ثم أرسل النتائج.
-- (لا يعدّل شيئاً — قراءة فقط.)
-- السبب: فشل أول محاولة لـ0009 بـ 42P01 relation "public.duels" does not
-- exist ⇒ تبيّن أن 0005_duels.sql غير مطبَّقة إطلاقاً (docs/16 بند ١١ ⬜).
-- ════════════════════════════════════════════════════════════════════

-- ١) هل انطبق شي من 0009 قبل الفشل؟ (المتوقّع قبل التطبيق: صفر صفوف)
select proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and proname in ('is_arena_type','duel_opponent_of','duel_points_today_with');

-- ٢) جداول السكيم العامة الموجودة فعلاً
select table_name
  from information_schema.tables
 where table_schema = 'public'
 order by table_name;

-- ٣) الدوال الموجودة فعلاً (الاسم + المعاملات)
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
 order by p.proname;

-- ٤) فهارس xp_events
select indexname
  from pg_indexes
 where schemaname = 'public' and tablename = 'xp_events'
 order by indexname;

-- ٥) نسخة league_rollup_week: هل فيها فلتر التحديات؟
select prosrc like '%is_arena_type%' as has_arena_filter,
       prosrc like '%duels%'         as touches_duels,
       length(prosrc)                as src_len
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'league_rollup_week';

-- ٦) نسخة verify_commit: هل فيها دعوى المبارزة؟
select prosrc like '%winner_claim_seq%' as has_duel_claim,
       length(prosrc)                   as src_len
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'verify_commit';

-- ٧) كم صف مخزون؟ (حتى نعرف إن كان في شيء يُلمس)
select (select count(*) from public.xp_events)        as xp_rows,
       (select count(*) from public.weekly_totals)    as weekly_rows,
       (select count(*) from public.league_standings) as standings_rows;

-- ٨) أنواع الأحداث الموجودة فعلاً بالقاعدة
select type,
       count(*)                          as n,
       sum((payload ->> 'points')::int)  as pts
  from public.xp_events
 group by type
 order by type;

-- ٩) هل pg_cron مجدول فعلاً؟ (بند ٩ في docs/16)
select jobname, schedule from cron.job order by jobname;

-- ════════════════════════════════════════════════════════════════════
-- تحقق بعد تطبيق 0009 (المتوقّع):
--   ١ ⇒ is_arena_type (صف واحد) · ٤ ⇒ xp_events_challenge_idx +
--        xp_events_challenge_q_idx · ٥ ⇒ has_arena_filter = true
-- ════════════════════════════════════════════════════════════════════
