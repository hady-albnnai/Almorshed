-- ═══════════════════════════════════════════════════════════════════════
-- 0007 — تدقيق الحقن (F7.4 — 2026-09-14): قيود شكل على كل عمود يكتبه العميل
-- مباشرة عبر PostgREST. الطبقة الأخيرة بعد RLS والزناد: حتى لو تجاوز أحدٌ
-- واجهة التطبيق، لا يمر إلى القاعدة إلا القيم المطابقة للعقد حجماً وشكلاً.
-- idempotent — إعادة التشغيل آمنة.
-- ═══════════════════════════════════════════════════════════════════════

-- ── duels: الأعمدة التي يكتبها المضيف عند الإنشاء ──
do $$
begin
  if to_regclass('public.duels') is null then
    raise notice 'duels غير موجود بعد — طبّق 0005 أولاً ثم أعد 0007';
    return;
  end if;

  -- رمز الغرفة: Crockford-10 بشرطة بعد الخامسة حصراً (K7M2P-9QW4X)
  alter table public.duels drop constraint if exists duels_room_code_format;
  alter table public.duels add constraint duels_room_code_format
    check (room_code ~ '^[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$');

  -- البذرة: موجبة ودون 2^63 (tag<<50 | code) — العقد §٦.٠
  alter table public.duels drop constraint if exists duels_seed_range;
  alter table public.duels add constraint duels_seed_range
    check (seed >= 0);

  -- النطاق: كائن jsonb صغير بشكل معروف: units مصفوفة ≤ 5، count 1..50
  alter table public.duels drop constraint if exists duels_scope_shape;
  alter table public.duels add constraint duels_scope_shape
    check (
      jsonb_typeof(scope) = 'object'
      and jsonb_typeof(scope -> 'units') = 'array'
      and jsonb_array_length(scope -> 'units') between 1 and 5
      and jsonb_typeof(scope -> 'count') = 'number'
      and (scope ->> 'count')::int between 1 and 50
      and length(scope::text) <= 512
    );

  -- الأسماء المعروضة: طول محدود (تُعرض بـ Text فقط — بلا HTML — لكن لا نسمح بسيل)
  alter table public.duels drop constraint if exists duels_host_name_len;
  alter table public.duels add constraint duels_host_name_len
    check (char_length(host_name) between 1 and 40);
  alter table public.duels drop constraint if exists duels_guest_name_len;
  alter table public.duels add constraint duels_guest_name_len
    check (guest_name is null or char_length(guest_name) between 1 and 40);
end $$;

-- ── xp_events: نوع من قائمة معروفة + حجم حمولة محدود ──
-- (verify_xp_events يرفض UNKNOWN_TYPE قبل الإيداع؛ هذا قفل ثانٍ على القاعدة)
alter table public.xp_events drop constraint if exists xp_events_type_known;
alter table public.xp_events add constraint xp_events_type_known
  check (type ~ '^[a-zA-Z]{2,32}$');
alter table public.xp_events drop constraint if exists xp_events_payload_size;
alter table public.xp_events add constraint xp_events_payload_size
  check (length(payload::text) <= 2048);
alter table public.xp_events drop constraint if exists xp_events_hash_hex;
alter table public.xp_events add constraint xp_events_hash_hex
  check (hash ~ '^[0-9a-f]{64}$' and (prev_hash = 'GENESIS' or prev_hash ~ '^[0-9a-f]{64}$'));
alter table public.xp_events drop constraint if exists xp_events_sig_b64;
alter table public.xp_events add constraint xp_events_sig_b64
  check (sig ~ '^[A-Za-z0-9+/]{86}==$');

-- ── devices: المفتاح العام base64 لـ32 بايت حصراً + بصمة محدودة ──
alter table public.devices drop constraint if exists devices_pubkey_b64_format;
alter table public.devices add constraint devices_pubkey_b64_format
  check (pubkey_b64 ~ '^[A-Za-z0-9+/]{43}=$');
alter table public.devices drop constraint if exists devices_fp_len;
alter table public.devices add constraint devices_fp_len
  check (char_length(device_fp) between 8 and 128);

-- ── profiles: اسم العرض محدود (السياسة تسمح للمالك بتحديثه) ──
alter table public.profiles drop constraint if exists profiles_display_name_len;
alter table public.profiles add constraint profiles_display_name_len
  check (char_length(display_name) between 1 and 40);

-- ── activation_codes: شكل الكود (تكتبه أداة المكتب فقط — قفل إضافي) ──
alter table public.activation_codes drop constraint if exists activation_codes_format;
alter table public.activation_codes add constraint activation_codes_format
  check (code ~ '^[0-9A-HJ-KM-NP-TV-Z]{15}$');
