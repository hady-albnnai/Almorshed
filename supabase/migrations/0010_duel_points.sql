-- ════════════════════════════════════════════════════════════════════
-- 0010 — «الخصم نفسه مرة/يوم للنقاط» (قرار ٦٠) — حكم خادمي ذري
--
-- ⚠️ **لا تُطبَّق قبل 0005_duels.sql** — تعتمد على public.duels.
-- (اكتُشف ٢٠٢٦-٠٩-١٥ أن 0005 غير مطبَّقة: docs/16 بند ١١ ⬜.)
--
-- لماذا هنا لا في الدالة الطرفية؟ لأن الخصم **لا يُعرف إلا من صف المبارزة**
-- (host_device/guest_device) — فأي ادعاء من الجهاز باسم خصمه لا قيمة له.
-- الفحص داخل verify_commit ⇒ ذريّ مع الإيداع: لا نافذة تسرب بين الفحص والكتابة.
-- ════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regclass('public.duels') is null then
    raise exception
      'STOP: طبّق supabase/migrations/0005_duels.sql أولاً — public.duels غير موجود';
  end if;
end $$;

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
