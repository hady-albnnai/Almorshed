# ١٧ — دفتر النشر خطوة-خطوة (M5→M6)

> لمن؟ **المالك حصراً** (بيده جلسة Supabase والأسرار). يقرأ مع `docs/16` §٧ و§٧-ب.
> الترتيب: **المسار أ** (أداة المكتب — جاهزة اليوم بلا معوّق) ثم **المسار ب**
> (المبارزة الحية — أنابيبها تُرفع الآن واللعب ينتظر بنك الأسئلة) ثم
> **المسار ج** (بنك الأسئلة — محجوب على اعتماد الأستاذ).

---

## المسار أ — أداة المكتب (F6.1) — تُشغَّل اليوم كاملة

> لا تعتمد على شيء محجوب: `activation_codes` موجود منذ 0001، و`license_activate`
> منشور حي، و`record_activation` مطبَّق — فور نشر هذا المسار يصبح «البيع في
> المكتب» حياً: توليد كود ← الطالب يفعّله ← الترخيص يعمل.

### أ-١) سر المكتب
```bash
supabase secrets set OFFICE_KEY='<ولّد سراً طويلاً عشوائياً — لا يمر بأي محادثة>'
```

### أ-٢) ترحيل سجل التدقيق
```bash
supabase db push
# أو من اللوحة: SQL Editor ← الصق محتوى supabase/migrations/0006_office_audit.sql ← Run
```

### أ-٣) نشر الدالة
```bash
supabase functions deploy office_codes --no-verify-jwt
```
> `--no-verify-jwt` إلزامي: المكتب ليس «مستخدم تطبيق» — الحماية بترويسة `x-office-key`.

### أ-٤) دخان — توليد
```bash
curl -sS -X POST "$SUPABASE_URL/functions/v1/office_codes" \
  -H "Content-Type: application/json" -H "x-office-key: $OFFICE_KEY" \
  -d '{"action":"generate","count":2}'
# ✅ المتوقع: {"ok":true,"count":2,"codes":["XXXXX-XXXXX-XXXXX","YYYYY-YYYYY-YYYYY"]}
```

### أ-٥) دخان — جرد وإلغاء
```bash
curl -sS -X POST "$SUPABASE_URL/functions/v1/office_codes" \
  -H "Content-Type: application/json" -H "x-office-key: $OFFICE_KEY" \
  -d '{"action":"list","status":"issued"}'
# ✅ المتوقع: الأكواد المولّدة أعلاه بحالة issued وdevices_used=0

curl -sS -X POST "$SUPABASE_URL/functions/v1/office_codes" \
  -H "Content-Type: application/json" -H "x-office-key: $OFFICE_KEY" \
  -d '{"action":"revoke","code":"XXXXX-XXXXX-XXXXX"}'
# ✅ المتوقع: {"ok":true,"code":"XXXXX-XXXXX-XXXXX"}
```

### أ-٦) تحقق القاعدة
```sql
select * from public.office_audit order by id desc limit 10;
-- ✅ صفّان على الأقل: generate + revoke
```

---

## المسار ب — المبارزة الحية (F5.1/F5.2/F5.3 على السيرفر)

> ⚠️ هذا يرفع **الأنابيب** (جداول + حكم خادمي + قناة خاصة). اللعب الفعلي عبر
> الإنترنت يحتاج بنك أسئلة (المسار ج) — بدونه تعود `duel_finish` برفض بنك فارغ.

### ب-١) فعّل Realtime أولاً
لوحة Supabase ← **Realtime** ← تأكد أنه مفعّل (عادةً افتراضياً).
بلا حاجة لإضافة جداول للنشر: البث/الحضور يسيران فوق القناة الخاصة مباشرة.

### ب-٢) طبّق الترحيل 0005
```bash
supabase db push
# أو SQL Editor ← الصق كامل supabase/migrations/0005_duels.sql ← Run
```
> الترحيل **idempotent** (2026-09-14): إعادة تشغيله آمنة — `create … if not exists`
> و`drop policy/trigger if exists` قبل كل إنشاء. لو كان Realtime مطفأً وقت أول
> تشغيل، فعّله ثم **أعد تشغيل 0005** لتنشأ سياسات القناة.

### ب-٣) تحقق من قطع 0005
```sql
-- ١) الجداول الأربعة الجديدة
select relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname='public' and relname in
  ('duels','duel_answers','duel_status','content_questions');
-- ✅ ٤ صفوف

-- ٢) الزناد الحارس
select tgname from pg_trigger where tgrelid = 'public.duels'::regclass;
-- ✅ duels_guard_trigger

-- ٣) سياسات الجداول (RLS)
select tablename, polname from pg_policies
where tablename in ('duels','duel_answers','duel_status') order by tablename;
-- ✅ ٧ سياسات

-- ٤) سياسات القناة الخاصة (إن كان Realtime مفعلاً)
select polname from pg_policies where schemaname='realtime' and tablename='messages';
-- ✅ duel_channel_read + duel_channel_write

-- ٥) verify_commit الموسّعة (دعوى duelWin/duelLoss)
select proname from pg_proc where proname='verify_commit';
-- ✅ موجودة (النسخة الجديدة من 0005 استبدلت القديمة)
```

### ب-٤) نشر دالة الحكم
```bash
supabase functions deploy duel_finish
```
> بـCLI يلحق `_shared/duel_session.ts` آلياً. لو تنشر من اللوحة (ملف واحد)،
> الصق محتوى `_shared/duel_session.ts` داخل `duel_finish/index.ts` أعلى الدالة.

### ب-٥) دخان (بعد المسار ج فقط)
```bash
# إنشاء مبارزة من العميل وربط جهازين ثم إنهاؤها — يتحقق الحكم الخادمي.
# ⚠️ يحتاج بنك أسئلة غير فارغ ⇒ لا يُجرى قبل المسار ج.
```

### ب-٦) لا تنسَ — انحدار XP
`0005` أعاد إصدار `verify_commit`. أعد اختبار دخان XP السابق للتأكد من عدم
انحدار الإيداع العادي (§٧ في docs/16):
```bash
curl -s -X POST "$URL/functions/v1/verify_xp_events" \
  -H "Authorization: Bearer $ANON_JWT" -H "Content-Type: application/json" \
  -d '{"device_pubkey_b64":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
       "last_synced_seq":0,"events":[]}'
# ✅ 200: {"accepted":true,"synced_up_to":0,"server_time_ms":...}
```

---

## المسار ج — بنك أسئلة المبارزات (محجوب)

> **البوابة: اعتماد الأستاذ** للأسئلة (قرار ٢٤ — اليوم صفر صف معتمد).

بعد الاعتماد:
```bash
python3 tools/gen_content_index.py      # يولّد docs/supabase/content_index.sql
supabase db push                        # (أو SQL Editor: الصق الناتج)
```
ثم شغّل دخان ب-٥ — اللعب الحي يكتمل.

---

## ترتيب مُقترح إن أردت الاختزال

1. **اليوم**: المسار أ كاملاً (٣ أوامر + دخان) — البيع في المكتب يصبح حياً.
2. **متى أحببت**: المسار ب (ب-١→ب-٤) — يرفع أنابيب المبارزة؛ لا ضرورة لعجلة.
3. **بعد الأستاذ**: المسار ج ثم دخان ب-٥.
