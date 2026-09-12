# 🗄️ Supabase — M4 (قرار ٣٣ · قرار ٥٠: الخطة المجانية)

## خطوات المالك (مرة واحدة — ٥ دقائق)

1. أنشئ مشروعاً على supabase.com (حسابك أنت) — Name: `fizya-clash` — Region: **Europe (Frankfurt)** — الخطة المجانية.
2. من SQL Editor: الصق محتوى `supabase/migrations/0001_init.sql` كاملاً ثم **Run** — يجب أن ينجح بلا أخطاء.
3. من Authentication → Providers: فعّل **Anonymous** (الدخول المجهول — F4.3).
4. من Settings → API: انسخ **Project URL** و**anon public key** والصقهما للمطوّر في المحادثة (عامّان آمنان — الحماية عبر RLS).
5. أسرار الدوال (service_role وبذرة Ed25519) **لا تُشارك أبداً** — تُضبط لاحقاً وقت F4.4 من Edge Functions → Secrets بنفسك.

## ping مجدول إلزامي (§١٥-د — تفادي خمول ٧ أيام)

الملف `.github/workflows` ملكك حصراً — أنشئ `.github/workflows/supabase-ping.yml` بهذا المحتوى بعد معرفة الـURL:

```yaml
name: supabase-ping
on:
  schedule:
    - cron: '0 6 * * 1' # كل اثنين 06:00 UTC
  workflow_dispatch:
permissions:
  contents: read
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: نبضة الخمول — Ping Supabase
        run: curl -s -o /dev/null -w '%{http_code}' "PROJECT_URL/rest/v1/" -H "apikey: ANON_KEY"
```

(استبدل `PROJECT_URL` و`ANON_KEY` — ثم فعّل الـworkflow من تبويب Actions إن كان معطلاً افتراضياً.)

## ⚠️ الدوال مكتوبة وموثقة — العقد الحاكم: docs/16-SERVER-CONTRACT.md
الوثيقة المركزية لكل ما يعمل على الخادم (عقود الطلبات/الردود، القواعد القانونية بالمتجهات الذهبية، جداول الأخطاء، النشر، خريطة العميل) — **أي وكيل يقرؤها بلا سيرفر**، وأي تعديل خادم يبدأ بتعديلها بنفس الكومِت.

## بنية المجلد

```
supabase/
├── migrations/
│   └── 0001_init.sql      # المخطط + RLS — يُطبَّق كاملاً مرة واحدة
└── functions/             # (F4.4/F4.5/F4.6 — الجولة التالية بعد إنشاء المشروع)
    ├── license_activate/  # إصدار التوكن الموقّع ≤30ي + استهلاك الكود ذرياً
    ├── heartbeat/         # زمن سيرفر موقّع + تجديد صامت
    ├── verify_xp_events/  # تحقق السلسلة والتوقيع + إيداع الدوري
    └── league_rollup/     # إقفال أسبوعي + مجموعات ~٣٠ + تقاعد الأحداث
```
**تحديث 2026-09-12**: الثلاثة الأولى مكتوبة كاملة (`functions/*/index.ts`) والدوري
دالة SQL داخل `0002_server_functions.sql` بجدولة pg_cron جاهزة — التفاصيل في العقد §٢-§٥.

## عقد `verify_xp_events` (متّفق عليه مع العميل — sync_engine.dart)

```
POST /functions/v1/verify_xp_events
{ device_pubkey_b64, last_synced_seq, events: [{seq,type,ts,payload,prevHash,hash,sig}] }
→ 200 { accepted: true,  synced_up_to: N, server_time_ms: T }
→ 422 { accepted: false, reason: "...",   synced_up_to: آخر مقبول }
```

الرفض الكامل لأي خلل (فجوة/هاش/توقيع) — docs/12 §٨-4: رفض ١٠٠٪.
