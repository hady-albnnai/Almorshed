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
