# أداة المكتب — إصدار وإلغاء أكواد التفعيل (F6.1 · POS قرار ٣٤)

أداة المكتب = دالة حافة `office_codes` + هذا الدليل. الطالب يدفع في المكتب ⇒
تُولّد كوداً لحظياً ⇒ يُدخله على جهازه فيتم التفعيل وجهاً لوجه (قرار ٣٤ —
لا دفعات مسبقة، ونافذة سرقة الكود = دقائق داخل المكتب).

## النشر (مرة واحدة — بيد المالك)

```bash
# 1) مفتاح المكتب السري — لا يُكتب في أي ملف داخل المستودع
supabase secrets set OFFICE_KEY='<سر طويل عشوائي>'

# 2) ترحيل سجل التدقيق
supabase db push

# 3) نشر الدالة
supabase functions deploy office_codes --no-verify-jwt
```

> `--no-verify-jwt` إلزامي: المكتب ليس «مستخدم تطبيق» — الحماية بترويسة
> `x-office-key` وليس بجلسة Supabase.

## الاستخدام (curl من جهاز المكتب)

توليد ٣ أكواد:

```bash
curl -sS -X POST "$SUPABASE_URL/functions/v1/office_codes" \
  -H "Content-Type: application/json" \
  -H "x-office-key: $OFFICE_KEY" \
  -d '{"action":"generate","count":3}'
# → {"ok":true,"count":3,"codes":["K7M2P-9QW4X-ABCDE", ...]}
```

إلغاء كود:

```bash
curl -sS -X POST "$SUPABASE_URL/functions/v1/office_codes" \
  -H "Content-Type: application/json" \
  -H "x-office-key: $OFFICE_KEY" \
  -d '{"action":"revoke","code":"K7M2P-9QW4X-ABCDE"}'
```

جرد (مع عدد الأجهزة المستخدمة لكل كود — قرار ٢٨):

```bash
curl -sS -X POST "$SUPABASE_URL/functions/v1/office_codes" \
  -H "Content-Type: application/json" \
  -H "x-office-key: $OFFICE_KEY" \
  -d '{"action":"list","status":"issued"}'
```

## الطباعة

افتح `print.html` في المتصفح، الصق الأكواد (سطراً لكل كود)، واطبع —
ورقة A4 بعلامة موزّع (قرار ٣٢: العلامة المائية بالكود تُتَّبع من
`office_audit`).

## ملاحظات عقد

- **الكود ١٥ محرفاً Crockford بلا I/L/O/U** (٥-٥-٥) — مطابق `CODE_RE`
  بالعقد §٢ و`formatLicenseCode` بالعميل. (القرار ٣٤ كتب «١٠ محارف» سهواً
  قديماً — البنية والعميل ثابتان على ١٥.)
- كل توليد/إلغاء يُسجَّل في `office_audit` (RLS سلبية — يقرؤه المالك فقط).
- الإلغاء يجعل أي محاولة تفعيل لاحقة تردّ `ACT_CODE_REVOKED` (410).
- حد الجهازين لكل كود يفرضه `record_activation` (قرار ٢٨) لا هذه الأداة.
