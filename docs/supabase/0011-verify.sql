-- ════════════════════════════════════════════════════════════════════
-- تحقّق من هجرة 0011 (قرار ٦٥ — الترتيب التراكمي للموسم)
-- للقراءة فقط (select) — ما بتعدّل شي. شغّله بعد تشغيل 0011.
--
-- المتوقّع: كل القيم true و season = '2026-2027'
-- ════════════════════════════════════════════════════════════════════

select
  -- ١) الدالة موجودة (يجب 1)
  (select count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='current_season')            as fn_season,

  -- ٢) الموسم الحالي (يجب '2026-2027')
  (select public.current_season())                                       as season,

  -- ٣) عمود season على weekly_totals (يجب 1)
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='weekly_totals'
      and column_name='season')                                          as col_season,

  -- ٤) league_rollup_week صارت تراكمية: فيها sum(xp) وما فيها القسم على ٣٠
  (select count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='league_rollup_week'
      and p.prosrc like '%sum(xp)%'
      and p.prosrc not like '%/ 30%')                                    as rollup_cumulative,

  -- ٥) الفهرس الجديد (يجب 1)
  (select count(*) from pg_indexes
    where schemaname='public' and tablename='weekly_totals'
      and indexname='weekly_totals_season_idx')                          as idx_season,

  -- ٦) الاعتمادية: 0009 لازم تكون مطبّقة (is_arena_type موجودة) (يجب 1)
  (select count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='is_arena_type')              as fn_arena_type,

  -- ٧) الـcron شغّال على نفس الاسم (يجب 'league_rollup')
  (select coalesce(jobname,'-') from cron.job
    where jobname='league_rollup')                                       as cron_job;
