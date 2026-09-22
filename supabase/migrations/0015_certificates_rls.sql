-- ═══════════════════════════════════════════════════════════════════════
-- 0015 — F6.3-أمن (2026-09-22): تضييق قراءة الشهادات والموسم + تحصين cron.
--
-- خلفية: مدقّق Supabase (auth_allow_anonymous_sign_ins) يُطلق تحذيراً لأي
-- سياسة تسمح للدور anon. التطبيق يستخدم الدخول المجهول كوسيلة الدخول الوحيدة،
-- فسياسات *_select_own على devices/licenses/profiles/xp_events/weekly_totals/
-- league_standings **مقصودة وسليمة** (كلٌّ يقرأ بياناته عبر auth.uid()) —
-- لا تُلمس، فحصرها يعطّل التطبيق. هذا الترحيل يعالج الحالات الحقيقية فقط:
--
--   ١) certificates: كانت using(true) ⇒ تعداد كامل (device_id·xp·payload·
--      signature لكل طالب). ⇐ سياسة ملكية.
--   ٢) seasons: كانت using(true). العميل لا يقرؤها مباشرة (كل الوصول عبر
--      cert_issue بservice role) ⇒ نحصرها بالمفعّلين بلا كسر شيء، فيسكت
--      التحذير ويُقفل التعداد المجهول.
--   ٣) cron.job / cron.job_run_details: جداول pg_cron الداخلية. لا يجوز أن
--      يصلها anon/authenticated ⇒ نلغي أي صلاحية لهما على schema cron.
-- ═══════════════════════════════════════════════════════════════════════

-- ── ١) الشهادات: قراءة صاحبها حصراً (بدل using(true) في 0014) ──
drop policy if exists certificates_public_read on public.certificates;

create policy certificates_select_own
  on public.certificates for select using (exists (
    select 1 from public.devices d
    where d.id = certificates.device_id and d.profile_id = auth.uid()
  ));

comment on policy certificates_select_own on public.certificates is
  'F6.3-أمن: كل جهاز يقرأ شهادته عبر ملفه الشخصي — لا تعداد عام (بدل using(true) في 0014).';

-- ── ٢) الموسم: المفعّلون حصراً (العميل لا يقرؤه مباشرة — الوصول عبر الدوال) ──
-- لا بيانات شخصية فيه (اسم + ends_on)، لكن حصره يُقفل التعداد المجهول
-- ويُسكِت تحذير المدقّق دون أثر وظيفي.
drop policy if exists seasons_public_read on public.seasons;

create policy seasons_select_licensed
  on public.seasons for select to authenticated using (exists (
    select 1 from public.devices d
    join public.licenses l on l.device_id = d.id and l.revoked = false
    where d.profile_id = auth.uid()
  ));

comment on policy seasons_select_licensed on public.seasons is
  'F6.3-أمن: قراءة الموسم للمفعّلين — العميل يصله عبر cert_issue (service role) لا مباشرة.';

-- ── ٣) تحصين cron: لا وصول لـanon/authenticated إلى جداول pg_cron الداخلية ──
-- (سياسات افتراضية من الإضافة؛ نلغي التعريض احتياطاً. الحارس: schema cron
--  يجب ألّا يكون ضمن exposed schemas بإعدادات API — يُراجَع باللوحة أيضاً.)
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'cron') then
    begin
      execute 'revoke all on all tables in schema cron from anon, authenticated';
      execute 'revoke usage on schema cron from anon, authenticated';
    exception when insufficient_privilege or others then
      -- schema cron مملوك لـsupabase_admin أحياناً: لا نُفشل الترحيل — يُراجَع
      -- التعريض باللوحة (Settings → API → Exposed schemas: أزِل cron).
      raise notice 'cron hardening skipped (privilege): review Exposed schemas in dashboard';
    end;
  end if;
end $$;

