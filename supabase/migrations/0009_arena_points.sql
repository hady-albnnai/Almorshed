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
