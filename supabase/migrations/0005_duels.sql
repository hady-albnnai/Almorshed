-- ═══════════════════════════════════════════════════════════════════════
-- 0005_duels — المبارزات الحية (M5 / F5.1+F5.2)
-- العقد الكامل: docs/16-SERVER-CONTRACT.md §٦ (duel_finish) و§٧ (قنوات duel).
-- القواعد (docs/11 §١١ + §و-5): النتيجة يقررها السيرفر من البذرة حصراً؛
-- القناة خاصة private:true بسياسات RLS على realtime.messages للمشاركين حصراً.
-- ملاحظة scopeTag: bigint بpostgres موقّع ⇒ التاج 13 بت (لا 14) ليبقى
-- seed = (tag<<50)|roomCode < 2^63 — قرار تقني موثق بالعقد §٦.٠.
-- ═══════════════════════════════════════════════════════════════════════

-- ── ١) content_questions — بنك المبارزة على السيرفر (معرفات حصراً بلا نصوص
--      الكتاب — قرار ٥٥). يملؤه المالك من docs/supabase/content_index.sql
--      (أداة tools/gen_content_index.py — بنك المعتمد حصراً قرار ٢٤).
create table if not exists public.content_questions (
  id             int  primary key,            -- معرف السؤال كما بالحزمة
  unit           text not null,               -- مثل U1
  chapter        text not null,               -- مثل U1C1
  chapter_index  int  not null,               -- فهرس الفصل بترتيب الحزمة (للتوازن)
  correct_index  int  not null,               -- فهرس الإجابة الصحيحة الأصلي
  options_n      int  not null default 4      -- عدد الخيارات
);
alter table public.content_questions enable row level security;
-- بلا سياسات ⇒ لا وصول مباشر لأي دور؛ الدوال بخدمة service_role تقرأه حصراً.

-- ── ٢) duels — المبارزة نفسها؛ البذرة هي العقد بين الطرفين ──
create table if not exists public.duels (
  id               uuid primary key default gen_random_uuid(),
  room_code        text not null,              -- Crockford-10 مثل K7M2P-9QW4X
  seed             bigint not null,            -- (tag<<50)|code — العقد §٦.٠
  scope            jsonb not null,             -- {units[],count,mode,pack}
  status           text not null default 'lobby'
                   check (status in ('lobby','live','done','void')),
  host_device      uuid not null references public.devices(id) on delete cascade,
  guest_device     uuid references public.devices(id) on delete cascade,
  host_name        text not null default 'المضيف',
  guest_name       text,
  host_score       int,
  guest_score      int,
  winner_device    uuid references public.devices(id),
  host_claim_seq   int,                        -- تسلسل حدث duelWin/duelLoss المقبول
  guest_claim_seq  int,
  created_at       timestamptz not null default now(),
  started_at       timestamptz,
  ended_at         timestamptz
);
-- رمز غرفة نشط واحد فقط (الرمز قد يعاد بعد الإطفاء)
create unique index if not exists duels_active_code_idx
  on public.duels (room_code) where status in ('lobby','live');
create index if not exists duels_participant_idx
  on public.duels (host_device, guest_device);

alter table public.duels enable row level security;

-- القراءة: مبارزات اللوبي متاحة لأي موثق (رمز الغرفة هو الصلاحية — 50 بت)،
-- ومبارزات المشارك متاحة له دائماً.
drop policy if exists "duels_select" on public.duels;
create policy "duels_select" on public.duels
  for select to authenticated
  using (
    status = 'lobby'
    or exists (
      select 1 from public.devices dev
      where dev.profile_id = auth.uid()
        and dev.id in (duels.host_device, coalesce(duels.guest_device, duels.host_device))
    )
  );

-- الإنشاء: المضيف جهازاً له، لوبي فارغ.
drop policy if exists "duels_insert_host" on public.duels;
create policy "duels_insert_host" on public.duels
  for insert to authenticated
  with check (
    exists (select 1 from public.devices dev
            where dev.id = duels.host_device and dev.profile_id = auth.uid())
    and status = 'lobby' and guest_device is null and winner_device is null
  );

-- التحديث: للمشاركين — الأعمدة الحاسمة يحرسها الزناد أدناه.
drop policy if exists "duels_update_participants" on public.duels;
create policy "duels_update_participants" on public.duels
  for update to authenticated
  using (
    exists (
      select 1 from public.devices dev
      where dev.profile_id = auth.uid()
        and dev.id in (duels.host_device, coalesce(duels.guest_device, duels.host_device))
    )
  );

-- زناد الحارس: العميل لا يلمس أبداً (status/scores/winner/seed/claims/started)؛
-- الجلسة (guest) يجلس بلوبي غير ممتلئ وجهازه هو فقط. الخدمة service_role تعبر.
create or replace function public.duels_guard_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.role() = 'service_role' or current_setting('role', true) = 'service_role' then
    return new;
  end if;
  if new.status      is distinct from old.status
     or new.host_score   is distinct from old.host_score
     or new.guest_score  is distinct from old.guest_score
     or new.winner_device is distinct from old.winner_device
     or new.host_claim_seq is distinct from old.host_claim_seq
     or new.guest_claim_seq is distinct from old.guest_claim_seq
     or new.ended_at     is distinct from old.ended_at
     or new.seed         is distinct from old.seed
     or new.scope        is distinct from old.scope
     or new.room_code    is distinct from old.room_code
     or new.host_device  is distinct from old.host_device
     or new.host_name    is distinct from old.host_name
  then
    raise exception 'DUEL_IMMUTABLE' using errcode = 'P0001';
  end if;
  -- بدء المضيف: لوبي فيه الضيف ⇒ live مع طابع بدء حصراً (بلا مس آخر عمود)
  if new.status is distinct from old.status then
    if old.status <> 'lobby' or new.status <> 'live'
       or new.started_at is null
       or old.guest_device is null
       or not exists (select 1 from public.devices dev
                      where dev.id = old.host_device
                        and dev.profile_id = auth.uid()) then
      raise exception 'DUEL_START_FORBIDDEN' using errcode = 'P0001';
    end if;
  elsif new.started_at is distinct from old.started_at then
    -- طابع البدء لا يُمسّ منفرداً — بذرة القنوات الزمنية
    raise exception 'DUEL_IMMUTABLE' using errcode = 'P0001';
  end if;
  if new.guest_device is distinct from old.guest_device then
    if old.status <> 'lobby' or old.guest_device is not null then
      raise exception 'DUEL_FULL' using errcode = 'P0001';
    end if;
    if not exists (select 1 from public.devices dev
                   where dev.id = new.guest_device and dev.profile_id = auth.uid()) then
      raise exception 'DUEL_NOT_YOURS' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists duels_guard_trigger on public.duels;
create trigger duels_guard_trigger
  before update on public.duels
  for each row execute function public.duels_guard_update();

-- ── ٣) duel_answers — إجابات موجّهة نحو الحقيقة الخادمية ──
create table if not exists public.duel_answers (
  duel_id    uuid not null references public.duels(id) on delete cascade,
  device_id  uuid not null references public.devices(id) on delete cascade,
  q_index    int  not null check (q_index between 0 and 49),
  chosen     int  not null check (chosen between 0 and 9),
  answered_at timestamptz not null default now(),
  primary key (duel_id, device_id, q_index)
);
alter table public.duel_answers enable row level security;

drop policy if exists "duel_answers_select" on public.duel_answers;
create policy "duel_answers_select" on public.duel_answers
  for select to authenticated
  using (exists (
    select 1 from public.duels d join public.devices dev on dev.profile_id = auth.uid()
    where d.id = duel_answers.duel_id
      and dev.id in (d.host_device, coalesce(d.guest_device, d.host_device))));

drop policy if exists "duel_answers_insert" on public.duel_answers;
create policy "duel_answers_insert" on public.duel_answers
  for insert to authenticated
  with check (
    exists (select 1 from public.devices dev
            where dev.id = duel_answers.device_id and dev.profile_id = auth.uid())
    and exists (
      select 1 from public.duels d
      where d.id = duel_answers.duel_id and d.status = 'live'
        and duel_answers.device_id in (d.host_device, coalesce(d.guest_device, d.host_device))));

-- ── ٤) duel_status — إعلان «أنهيتُ» (المعلومة الحاسمة للإقفال) ──
create table if not exists public.duel_status (
  duel_id   uuid not null references public.duels(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  done_at   timestamptz not null default now(),
  primary key (duel_id, device_id)
);
alter table public.duel_status enable row level security;

drop policy if exists "duel_status_select" on public.duel_status;
create policy "duel_status_select" on public.duel_status
  for select to authenticated
  using (exists (
    select 1 from public.duels d join public.devices dev on dev.profile_id = auth.uid()
    where d.id = duel_status.duel_id
      and dev.id in (d.host_device, coalesce(d.guest_device, d.host_device))));

drop policy if exists "duel_status_insert" on public.duel_status;
create policy "duel_status_insert" on public.duel_status
  for insert to authenticated
  with check (
    exists (select 1 from public.devices dev
            where dev.id = duel_status.device_id and dev.profile_id = auth.uid())
    and exists (
      select 1 from public.duels d
      where d.id = duel_status.duel_id and d.status = 'live'
        and duel_status.device_id in (d.host_device, coalesce(d.guest_device, d.host_device))));

-- ── ٥) مساعد عضوية قناة المبارزة — للسياسات أدناه (العقد §٧) ──
create or replace function public.duel_participant_of_topic() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.duels d
      join public.devices dev
        on dev.id in (d.host_device, coalesce(d.guest_device, d.host_device))
     where dev.profile_id = auth.uid()
       and d.id::text = split_part(split_part(realtime.topic(), 'duel:', 2), ':', 1)
  );
$$;

-- سياسات القناة الخاصة: تُنشأ إن كان Realtime مفعلاً (جدول realtime.messages).
-- على الاستضافة Realtime مفعّل افتراضياً؛ الرسالة تُفحص SELECT (سماع) وINSERT (بث).
do $$
begin
  if to_regclass('realtime.messages') is not null then
    execute $p$
      drop policy if exists "duel_channel_read" on realtime.messages;
create policy "duel_channel_read" on realtime.messages
        for select to authenticated
        using (
          extension in ('broadcast','presence')
          and public.duel_participant_of_topic()
        );
    $p$;
    execute $p$
      drop policy if exists "duel_channel_write" on realtime.messages;
create policy "duel_channel_write" on realtime.messages
        for insert to authenticated
        with check (
          extension in ('broadcast','presence')
          and public.duel_participant_of_topic()
        );
    $p$;
  else
    raise notice 'realtime.messages غير موجود — فعّل Realtime ثم أعد 0005 (قسم السياسات)';
  end if;
end $$;

-- ── ٦) verify_commit — إعادة إصدار بدعوى XP المبارزة (ذرياً مع الإيداع) ──
-- duelWin: الجهاز فائزٌ موثق لمبارزة done خلال ٤٨ ساعة ولم يدّعِها؛
-- duelLoss: الطرف الآخر. غير ذلك VZ_DUEL ⇒ رفض الدفعة كلها (docs/12 §٨-4).
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
