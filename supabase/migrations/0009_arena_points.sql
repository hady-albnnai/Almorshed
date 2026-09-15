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

-- فحص «الخصم نفسه مرة/يوم للنقاط» (قرار ٦٠) — داخل verify_commit:
-- يبحث أحداث المبارزة لهذا الجهاز في هذا اليوم، ثم يرجع لصفوف duels
-- لمعرفة الخصم ⇒ فهرسان: (الجهاز · النوع · اليوم) و(معرّف المبارزة).
create index if not exists xp_events_duel_claim_idx
  on public.xp_events (device_id, type, ((payload ->> 'dateKey')))
  where type in ('duelWin', 'duelLoss');

create index if not exists xp_events_duel_id_idx
  on public.xp_events (((payload ->> 'duelId')::uuid))
  where type in ('duelWin', 'duelLoss');

-- ── ٤) تحصين: الدالة التنفيذية لـ service_role حصراً (كبقية دوال 0002) ──
revoke execute on function public.is_arena_type(text) from public;

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
