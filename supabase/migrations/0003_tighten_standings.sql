-- ════════════════════════════════════════════════════════════════════
-- 0003 — تشديد سياسة الدوري بعد تفعيل Anonymous (المجهول = authenticated)
-- قبل: standings_select_auth باستخدام(true) لكل authenticated — والمجهول
-- الآن authenticated ⇒ كان سيقرأ الترتيب دون تفعيل. بعد: أجهزة بترخيص
-- غير مسحوب حصراً (نفس قصد docs/12: «المفعّلون» حرفياً).
-- ════════════════════════════════════════════════════════════════════
drop policy if exists "standings_select_auth" on public.league_standings;
create policy "standings_select_licensed" on public.league_standings
  for select to authenticated using (exists (
    select 1 from public.devices d
    join public.licenses l on l.device_id = d.id and l.revoked = false
    where d.profile_id = auth.uid()
  ));
