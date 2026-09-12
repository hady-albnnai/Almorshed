-- ════════════════════════════════════════════════════════════════════
-- F4.4/F4.5/F4.6 — دوال الخادم الذرية (تُطبَّق بعد 0001_init.sql مباشرة)
-- العقد الكامل موثق: docs/16-SERVER-CONTRACT.md (اقرأه قبل أي تعديل)
-- القاعدة: Edge Functions (TS) تحسب التوقيعات والهاشات (Ed25519 لا يوجد
-- بPostgres) وتستدعي هذه الدوال للكتابة الذرية المتسابقة.
-- ════════════════════════════════════════════════════════════════════

-- ═══ 1) record_activation — التفعيل الذري (license_activate يستدعيها) ═══
-- تُعيد jsonb {device_id, licenses_count, activated_now}
-- أخطاء برسائل متعارفة يترجمها TS إلى HTTP (انظر العقد §2.4):
--   ACT_CODE_NOT_FOUND · ACT_CODE_REVOKED · ACT_DEVICE_LIMIT
create or replace function public.record_activation(
  p_code text, p_profile uuid, p_pubkey_b64 text, p_fp text,
  p_token text, p_release text, p_expires timestamptz,
  p_hard timestamptz, p_server_ms bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code    public.activation_codes%rowtype;
  v_device  uuid;
  v_count   int;
  v_activated boolean := false;
begin
  -- قفل صف الكود ذرياً (يمنع تفعيلين متسابقين — خطر ٣٢ بنيوياً)
  select * into v_code from public.activation_codes
    where code = p_code for update;
  if not found then
    raise exception 'ACT_CODE_NOT_FOUND' using errcode = 'P0001';
  end if;
  if v_code.status = 'revoked' then
    raise exception 'ACT_CODE_REVOKED' using errcode = 'P0001';
  end if;

  -- الجهاز: بالمفتاح العام (نفس المفتاح = نفس الجهاز)
  select id into v_device from public.devices where pubkey_b64 = p_pubkey_b64;
  if v_device is null then
    insert into public.devices (profile_id, pubkey_b64, device_fp)
      values (p_profile, p_pubkey_b64, p_fp)
      returning id into v_device;
  else
    update public.devices set last_seen = now() where id = v_device;
  end if;

  -- قرار ٢٨: جهازان لكل كود — العد على التراخيص غير المسحوبة
  if v_code.status = 'activated' then
    select count(*) into v_count from public.licenses
      where code = p_code and revoked = false
        and device_id <> v_device;
    if v_count >= 2 then
      raise exception 'ACT_DEVICE_LIMIT' using errcode = 'P0001';
    end if;
  else
    update public.activation_codes
      set status = 'activated', activated_at = now(),
          activated_by = p_fp
      where code = p_code;
    v_activated := true;
  end if;

  -- upsert ترخيص (نفس الجهاز يعيد التفعيل = تجديد لنفس الصف)
  insert into public.licenses
    (code, device_id, token, release_id, expires_at)
  values (p_code, v_device, p_token, p_release, p_expires)
  on conflict (code, device_id) do update
    set token = excluded.token,
        release_id = excluded.release_id,
        expires_at = excluded.expires_at,
        revoked = false;

  -- مرساة L4
  insert into public.time_anchors (device_id, last_server_ms)
    values (v_device, p_server_ms)
    on conflict (device_id) do update
      set last_server_ms = excluded.last_server_ms, updated_at = now();

  select count(*) into v_count from public.licenses
    where code = p_code and revoked = false;
  return jsonb_build_object(
    'device_id', v_device,
    'licenses_count', v_count,
    'activated_now', v_activated
  );
end;
$$;

-- ═══ 2) device_state_for_verify — قراءة حالة التحقق (بلا كتابة) ═══
-- تُعيد jsonb {device_id, pubkey_b64, last_seq, last_hash} أو null
create or replace function public.device_state_for_verify(
  p_pubkey_b64 text
) returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'device_id', d.id,
    'pubkey_b64', d.pubkey_b64,
    'last_seq', coalesce((select max(seq) from public.xp_events e
                          where e.device_id = d.id), 0),
    'last_hash', (select hash from public.xp_events e
                  where e.device_id = d.id
                  order by seq desc limit 1)
  )
  from public.devices d where d.pubkey_b64 = p_pubkey_b64;
$$;

-- ═══ 3) verify_commit — إيداع الأحداث المتحقق منها ذرياً ═══
-- TS تحقق التشفير (هاش/توقيع/أنواع/سقوف) ثم تستدعي هذه مرة واحدة.
-- إعادة تحقق الاستمرارية داخل المعاملة (فجوة متسابقة = رفض).
-- أخطاء: VZ_GAP (فجوة) · VZ_DEVICE (جهاز غير معروف)
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

-- ═══ 4) league_rollup_week — إقفال الأسبوع والدوري (F4.6 + تقاعد F4.1) ═══
-- الأسبوع: الاثنين ٠٠:٠٠ → الأحد ٢٤:٠٠ بتوقيت دمشق (docs/12 §٤.۳)
-- دمشق UTC+3 دائماً (أُلغي التوقيت الصيفي 2022) ⇒ إقفال الأسبوع المنتهي
-- يُحسب بتوقيت دمشق ناقص ساعة (ضمانة تغيّر الإقفال عند منتصف الليل).
-- idempotent: إعادة الجولة لنفس الأسبوع تستبدل النتائج ولا تضاعف.
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

  -- ١) المجاميع الأسبوعية من الأحداث داخل نافذة الأسبوع المغلق
  insert into public.weekly_totals (device_id, iso_week, xp, events_n)
  select e.device_id, v_week_id,
         sum((e.payload ->> 'points')::int), count(*)
    from public.xp_events e
   where e.ts >= (extract(epoch from (v_closed_start::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
     and e.ts <  (extract(epoch from ((v_closed_start + 7)::timestamp
              at time zone 'Asia/Damascus')) * 1000)::bigint
   group by e.device_id
  on conflict (device_id, iso_week) do update
    set xp = excluded.xp, events_n = excluded.events_n;

  -- ٢) الترتيب: مجموع XP الأسبوع تنازلياً — مجموعات ٣٠ متتالية (قرار ٤١)
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

-- ═══ 5) الجدولة الأسبوعية — pg_cron (فعل الإضافة من اللوحة أولاً) ═══
-- Database → Extensions → pg_cron: Enable، ثم ألغِ التعليق عن السطرين:
-- دمشق +3 ⇒ الاثنين ٠٠:٠٥ = الأحد ٢١:٠٥ UTC
-- select cron.schedule('league_rollup', '5 21 * * 0',
--   $$select public.league_rollup_week();$$);
-- (إلغاؤه اليدوي: select cron.unschedule('league_rollup');)
