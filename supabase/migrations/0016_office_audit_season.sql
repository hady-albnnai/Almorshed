-- ════════════════════════════════════════════════════════════════════
-- 0016 — توسيع سجل تدقيق المكتب ليشمل ضبط نهاية الموسم (F6.6)
--
-- الخلفية: `office_audit.action` كان مقيّداً بـ('generate','revoke') فقط
-- (0006). دالة office_codes أضافت إجراء 'season_set' (تعديل ends_on للموسم
-- من داخل التطبيق — قرار ٣٦: الإغلاق بيد المالك). هذا الإجراء حسّاس (إغلاق
-- الموسم يفتح إصدار الشهادات) فيجب أن يُدوَّن ⇒ نوسّع قيد CHECK ليقبله.
--
-- إعادة التشغيل آمنة: نُسقط القيد إن وُجد ثم نعيد إنشاءه بالقائمة الموسّعة.
-- ════════════════════════════════════════════════════════════════════

alter table public.office_audit
  drop constraint if exists office_audit_action_check;

alter table public.office_audit
  add constraint office_audit_action_check
  check (action in ('generate', 'revoke', 'season_set'));

comment on constraint office_audit_action_check on public.office_audit is
  'F6.6: أُضيف season_set (تدقيق ضبط نهاية الموسم) إلى القائمة المسموحة.';
