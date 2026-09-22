-- ═══════════════════════════════════════════════════════════════════════
-- 0015 — F6.3-أمن (2026-09-22): تضييق قراءة الشهادات إلى صاحبها.
--
-- المشكلة في 0014: `certificates_public_read ... using (true)` جعل الجدول
-- كلّه مقروءاً لأي حامل مفتاح anon العام (تعداد كامل: device_id · xp · payload
-- · signature لكل طالب). التبرير «المعرف uuid غير منخمَّن» لا يصحّ لأن
-- `using(true)` لا يقيّد بالمعرف إطلاقاً — إنه قراءة غير مقيّدة.
--
-- الإصلاح: نفس نمط الملكية المعتمد في 0001 (`weekly_select_own`،
-- `xp_events_select_own`): الجهاز يقرأ شهادته عبر ملفه الشخصي. الكتابة تبقى
-- عبر cert_issue (service role) حصراً — لا سياسة إدراج/تعديل للعميل.
--
-- الموسم يبقى عامّ القراءة (بيانات غير حساسة: الاسم + ends_on فقط) لأن
-- التطبيق يحتاجه قبل ربط الجهاز؛ ولا معلومات شخصية فيه.
-- ═══════════════════════════════════════════════════════════════════════

drop policy if exists certificates_public_read on public.certificates;

create policy certificates_select_own
  on public.certificates for select using (exists (
    select 1 from public.devices d
    where d.id = certificates.device_id and d.profile_id = auth.uid()
  ));

comment on policy certificates_select_own on public.certificates is
  'F6.3-أمن: كل جهاز يقرأ شهادته عبر ملفه الشخصي — لا تعداد عام (بدل using(true) في 0014).';
