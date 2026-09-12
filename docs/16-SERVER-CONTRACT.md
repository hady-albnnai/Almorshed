# ١٦ — عقد الخادم الكامل (Supabase M4) — يقرؤه أي وكيل بلا سيرفر

> **هذه الوثيقة هي المصدر الواحد للحقيقة عن كل ما يعمل على خادم فيزيا كلاش.**
> أي وكيل/مطوّر يحتاج فهم أو تعديل أي دالة خادمية يقرأ هنا حصراً — لا حاجة
> للدخول إلى لوحة Supabase إطلاقاً. أي تغيير على الخادم **يبدأ بتعديل هذه
> الوثيقة في الكومِت نفسه** (قاعدة حاكمة).

---

## ٠. البنية العامة

| المكوّن | التقنية | الملف |
|---|---|---|
| الترحيلات (الجداول + RLS) | SQL | `supabase/migrations/0001_init.sql` |
| دوال القاعدة الذرية + الدوري | SQL/PLpgSQL | `supabase/migrations/0002_server_functions.sql` |
| تفعيل الكود | Deno/TS (Edge Function) | `supabase/functions/license_activate/index.ts` |
| النبض والزمن الموقّع | Deno/TS | `supabase/functions/heartbeat/index.ts` |
| تحقق أحداث XP | Deno/TS | `supabase/functions/verify_xp_events/index.ts` |
| الدوري الأسبوعي | SQL + pg_cron | داخل 0002 (دالة `league_rollup_week`) |

**قرارات حاكمة**: ٣٣ (Supabase) · ٥٠ (الخطة المجانية) · ٢٦/٢٧ (تفعيل أونلاين مرة + إيجار موقّع) · ٢٨ (جهازان) · ٣٤ (POS المكتب) · ٤١ (مجموعات ~٣٠).

**قاعدة التوزيع الصلاحيات**: العميل (APK) يقرأ بـRLS حصراً ولا يكتب شيئاً
مباشرة — كل الكتابة عبر هذه الدوال بصلاحية `service_role` التي لا تخرج من
بيئة الدوال أبداً (docs/11 §١٢.١).

---

## ١. الأسرار ومتغيرات البيئة

| الاسم | من يضبطه | أين يعيش | ملاحظة |
|---|---|---|---|
| `SUPABASE_URL` · `SUPABASE_SERVICE_ROLE_KEY` | المنصة تلقائياً | بيئة كل Edge Function | لا تُضبط يدوياً |
| `SIGNING_SEED_B64` | **المالك حصراً** | Edge Functions → Secrets | بذرة Ed25519 ‏32بايت base64 — توليدها: `dart run tool/generate_license_key.dart` من مجلد app (السطر الأول = البذرة الخاصة) |
| `SUPABASE_URL` · `SUPABASE_ANON_KEY` (بالعميل) | المالك يرسلهما للمطوّر | `app/lib/core/**` لاحقاً | عامّان آمنان بالتصميم — الحماية عبر RLS |

⚠️ البذرة الخاصة = قدرة توقيع كل تراخيص المشروع. ضياعها/تسريبها = تدوير
المفتاح وإعادة إصدار كل التراخيص. لا تُلصق في أي محادثة أو ملف أبداً.

---

## ٢. `license_activate` — تفعيل الكود (F4.4)

### ٢.١ الغرض
استهلاك الكود مرة واحدة (خطر ٣٢ بنيوياً — قفل صف ذري)، ربط الجهاز
بالمفتاح العام، وإصدار «الإيجار الموقّع» ≤٣٠ يوماً بسقف صلب يوم الامتحان
(قرار ٢٦/٢٧، docs/11 §٥).

### ٢.٢ الاستدعاء
```
POST {SUPABASE_URL}/functions/v1/license_activate
Authorization: Bearer <JWT مجهول من supabase.auth.signInAnonymously()>
Content-Type: application/json

{ "code": "K7M2P-9QW4X-4TR8N",
  "device_pubkey_b64": "<32بايت base64 — مفتاح الجهاز العام>",
  "device_fp": "<بصمة استقرار ≥8 محارف>" }
```

### ٢.٣ الرد الناجح 200
```json
{ "ok": true,
  "token": { "payload": "<b64 canonical>", "sig": "<b64 64بايت>" },
  "server_time_ms": 1792592000000,
  "release_id": "2027-v1",
  "expires_at": 1792592000000,
  "hard_deadline": 1835904000000,
  "code_id": "K7M2P9QW4X4TR8N",
  "devices_used": 1,
  "activated_now": true }
```
العميل يحفظ `token` في `license_v1` (license_store) ويتحقق محلياً بـ
`checkLicense` — فحص ناجح ⇒ `LicenseMode.licensed`.

### ٢.٤ الأخطاء
| HTTP | error | متى |
|---|---|---|
| 401 | `AUTH_REQUIRED` | بلا/فاسد JWT |
| 404 | `ACT_CODE_NOT_FOUND` | الكود غير موجود |
| 410 | `ACT_CODE_REVOKED` | الكود مسحوب من اللوحة |
| 409 | `ACT_DEVICE_LIMIT` | كود مفعّل + جهازان آخران (قرار ٢٨) |
| 422 | `CODE_FORMAT` | ليس ١٥ محرفاً [0-9A-HJ-KM-NP-TV-Z] (بلا I/L/O/U — Crockford) |
| 422 | `PUBKEY_FORMAT` / `FP_FORMAT` | مفتاح/بصمة غير سليمة |
| 500 | `SIGNING_NOT_CONFIGURED` | بذرة التوقيع غير مضبوطة (المالك) |

### ٢.٥ الخوارزمية (بترتيب التنفيذ الفعلي)
1. JWT → `auth.uid()` (upsert profile — F4.3).
2. تطبيع الكود: أحرف كبيرة، حذف غير [A-Z0-9]، فحص الطول والحروف.
3. قراءة صف الكود (غير موجود/مسحوب ⇒ خطأ مبكر).
4. `expires_at = min(now + 30ي, hard_deadline)` — من عمود الكود.
5. حمولة canonical (الترتيب ثابت حرفياً — انظر §٦): 
   `{code_id, device_key_hash:"", release_id, expires_at, hard_deadline, flags:["full"]}`
   — **`device_key_hash` يُبعث فارغاً اليوم** لأن فحص العميل الحالي
   (`license_core.checkLicense`) يرفض أي قيمة غير فارغة (wrongDevice).
   حين يُشحن فحص Keystore بالعميل يُحوَّل ثابت `EMIT_DEVICE_HASH=true`
   بالدالة ويُحدَّث العقد (§٩ سجل التغييرات).
6. توقيع Ed25519 (tweetnacl `sign.detached`) ببذرة `SIGNING_SEED_B64`.
7. استدعاء `record_activation` (SQL ذري: قفل صف الكود → جهاز upsert →
   حدّ جهازَين → ترخيص upsert → مرساة زمن) — أي سبب رفض يعود رسالة `ACT_*`.
8. الرد §٢.٣.

### ٢.٦ أثر القاعدة
`devices` upsert · `licenses` upsert (code,device_id فريد) ·
`activation_codes`: status→activated + activated_at/by (أول مرة) ·
`time_anchors` upsert. **مرة واحدة**: التفعيل الثاني لجهاز ثالث مستحيل
ذرياً (قفل الصف + العدّ داخل المعاملة).

---

## ٣. `heartbeat` — النبض والزمن الموقّع (F4.4)

### ٣.١ الغرض
مرساة زمن سيرفر لكل جهاز (L4 — docs/11 §٨: رجوع ساعة الجهاز للعرض حصراً)،
وتجديد صامت للإيجار عند آخر ٧ أيام — «يلمس النت مرة شهرياً فلا يرى شيئاً».

### ٣.٢ الاستدعاء والرد
```
POST /functions/v1/heartbeat
{ "device_pubkey_b64": "...", "client_now_ms": 1792591000000 }
```
```json
{ "ok": true, "server_time_ms": 1792592000000,
  "renewed": true,
  "token": { "payload": "...", "sig": "..." },   // فقط عند renewed
  "clock_suspected": false }
```

### ٣.٣ القواعد
- جهاز غير معروف ⇒ 404 `DEVICE_UNKNOWN`.
- `clock_suspected = client_now_ms < آخر مرساة − ٥ دقائق` (علم لطيف فقط —
  الحكم النهائي للسيرفر؛ لا قفل محلياً أبداً — قرار ٣١).
- التجديد بشرطه الثلاثي: متبقٍ ≤٧ أيام **و** الكود غير مسحوب **و** الآن <
  hard_deadline — وإلا لا توكن جديد (وبعد التجاوز الصلب: لا إصدار أبداً).
- التجديد يعيد التوقيع بنفس القواعد القانونية §٦ ويحدّث `licenses.token/expires_at`.

---

## ٤. `verify_xp_events` — تحقق وإيداع أحداث XP (F4.5)

### ٤.١ الغرض
بوابة الدوري الوحيدة: التحقق التشفيري والمنطقي من أحداث دفتر الطالب ثم
إيداعها (السيرفر المرجعي — docs/12 §٤.۲/§٨-4: **رفض ١٠٠٪ لأي خلل**).

### ٤.٢ الاستدعاء
```
POST /functions/v1/verify_xp_events
Authorization: Bearer <JWT>
{ "device_pubkey_b64": "...",
  "last_synced_seq": 12,          // إعلامي — السيرفر يقرأ حقيقته من القاعدة
  "events": [ { "seq":13, "type":"batchDone", "ts":1790000000000,
                "payload": {"points":15,"dateKey":"2026-09-12"},
                "prevHash":"<hex>", "hash":"<hex>", "sig":"<b64>" } ] }
```
سقف الدفعة: **500 حدثاً** (تجاوزه = 413 `BATCH_TOO_LARGE`).

### ٤.٣ الرد
```json
// قبول 200
{ "accepted": true, "synced_up_to": 20, "server_time_ms": 1792592000000 }
// رفض 422 (العميل لا يتقدم ولا يمسح — سلاسله سليمة محلياً)
{ "accepted": false, "reason": "HASH_MISMATCH", "synced_up_to": 12 }
```

### ٤.٤ خطوات التحقق لكل حدث (بالترتيب — أول فشل يوقف الكل)
1. **تسلسل**: `seq == آخر مقبول + 1` (يبدأ من `max(seq)` بالقاعدة — لا ثقة
   بـ`last_synced_seq` الوارد).
2. **الرابط**: `prevHash == hash الحدث السابق` (أو `"GENESIS"` للجذر).
3. **الهاش**: `SHA-256(prevHash + canonicalCore) == hash` (hex صغير) حيث
   `canonicalCore = JSON.stringify({seq,type,ts,payload,prevHash})` —
   الحقول بهذا الترتيب حصراً و`payload` تمرَّ كما وردت **بلا أي إعادة بناء**
   (قاعدة حاكمة — انظر §٦).
4. **التوقيع**: Ed25519 verify(مفتاح الجهاز **من القاعدة**، bytes(hash)، sig b64).
5. **النوع والنقاط** (جدول §٤.٥) + **السقف اليومي** ضد القاعدة *و*الدفعة.

### ٤.٥ جدول الأنواع (docs/12 §٤.١ — العشر كلها)
| type | نقاط | سقف | تحقق إضافي |
|---|---|---|---|
| batchDone | 15 | مرة/يوم | dateKey شكل YYYY-MM-DD |
| mistakesFive | 10 | مرة/يوم | — |
| lessonNew | 10 | مرة/يوم | — |
| streakDay | 10 | مرة/يوم | — |
| queueDone | 15 | مرة/يوم | — |
| labChallenge | 10 | مرة/يوم | — |
| cardReview | 1 | بلا | — |
| duelWin | 45 | بلا | — |
| duelLoss | 15 | بلا | — |
| manual | 1..1000 | بلا | `payload.reason` نص غير فارغ إلزامي |

السقف اليومي مزدوج: `DUP_CAP` (داخل الدفعة) و`DUP_CAP_DB` (مخزّن سابقاً
بحسب type + `payload->>dateKey` لنفس الجهاز).

### ٤.٦ الأخطاء (كلها 422 إلا ما ذُكر)
`PUBKEY_FORMAT` · `DEVICE_UNKNOWN` (404) · `BATCH_TOO_LARGE` (413) ·
`SEQ_GAP` · `CHAIN_BREAK` · `HASH_MISMATCH` · `BAD_SIGNATURE` ·
`POINTS_MISMATCH:<type>` · `DUP_CAP:<type>` · `DUP_CAP_DB:<type>` ·
`MANUAL_POINTS_RANGE` · `MANUAL_REASON` · `UNKNOWN_TYPE` · `VZ_GAP` (سباق
استمرارية داخل المعاملة) · `COMMIT_INTERNAL`/`INTERNAL` (500).

### ٤.٧ أثر القاعدة عند القبول
`verify_commit` ذرياً: إعادة فحص (last_seq, last_hash) داخل المعاملة ⇒
insert دفعة الأحداث ⇒ مرساة زمن upsert. الرفض لا يكتب حرفاً واحداً.

---

## ٥. `league_rollup_week` — الدوري الأسبوعي والتقاعد (F4.6 + F4.1)

### ٥.١ الغرض
إقفال الأسبوع المنتهي: تجميع XP، ترتيب بمجموعات ~٣٠ (قرار ٤١)، حفظ
`weekly_totals`، **تقاعد أحداث الأسبوع المغلق** (القاعدة < 100MB دائماً —
قرار ٥٠).

### ٥.٢ التعريف الزمني (docs/12 §٤.۳ حرفياً)
- الأسبوع: الاثنين 00:00 → الأحد 24:00 **بتوقيت دمشق** (UTC+3 دائماً —
  أُلغي الصيفي 2022 ⇒ ثابت).
- معرف الأسبوع: `IYYYIW` مثل `202637` (ISO — أسبوعه يبدأ اثنين، مطابق).
- الإقفال: `date_trunc('week', (now() دمشق) − 1 ساعة)` — ضمانة عبور منتصف الليل.

### ٥.٣ الخوارزمية (داخل الدالة — 0002 §4)
1. مجاميع الأحداث داخل نافذة الأسبوع المغلق ⇒ upsert `weekly_totals`.
2. حذف صفوف `league_standings` لذلك الأسبوع (idempotent) وإدراج الترتيب:
   `xp DESC, device_id ASC` — `group_no = ceil(rank/30)`, `rank_no = rank`.
3. حذف أحداث الأسبوع المغلق من `xp_events` (التقاعد — بعد أمان المجاميع).

### ٥.٤ التشغيل
- **مجدول**: pg_cron كل اثنين 00:05 دمشق (= الأحد 21:05 UTC) —
  `select cron.schedule('league_rollup','5 21 * * 0',$$select public.league_rollup_week();$$);`
  (يتيح تفعيل إضافة pg_cron من اللوحة أولاً — الأسطر جاهزة معلقة بذيل 0002).
- **يدوي**: SQL Editor: `select public.league_rollup_week();`
- الرد: `{ "week": 202637, "devices": 41 }`.

### ٥.٥ القراءة من العميل
شاشة الدوري (بنفسجي docs/13 — تُبنى لاحقاً) تقرأ
`league_standings` بسياسة `standings_select_auth` (أرقام وترتيب حصراً —
بلا هويات).

---

## ٦. القواعد القانونية المشتركة — ⚠️ أخطر فصل: لا يُعدَّل إلا بترقية متزامنة

**التوافق بايتاً-ببايتاً** بين Dart (العميل) وTS (الخادم) وpython (التحقق):

1. JSON **مضغوط** دائماً: بلا فراغات (`JSON.stringify` الافتراضي =
   `jsonEncode` الدارتي = `json.dumps(separators=(',',':'))` بالبايثون).
2. **ترتيب المفاتيح = ترتيب الإدراج** (كلاهما يحافظ عليه — لا إعادة ترتيب
   أبجدية أبداً).
3. قواعد الأرقام: أعداد صحيحة عادية — النقاط/الأزمنة بالميلي ثانية.
4. قاعدة **الحمولة المارّة**: عند التحقق يُسلسَل `payload` كما ورد حرفياً —
   يُحظر إعادة بنائه حقل-حقل (خطر اختلاف ترتيب/تهريب = هاش لا يطابق).
5. اليونيكود: بلا `\u` تهريب للنصوص العادية (كلاهما يبعث العربية حرفاً) —
   فحصها بمتجه ذهبي أدناه.
6. الهاشات hex **صغيرة الحروف**؛ التوقيعات base64 قياسي.
7. `flags` تُرتَّب أبجدياً قبل السلسلة (توكن فقط).
8. أبزرار القيم «مثل GENESIS» ثابتة حرفياً بين الطرفين.

### المتجهات الذهبية (محسوبة فعلاً 2026-09-12 — sha256)
**حدث عادي:**
```
core = {"seq":1,"type":"batchDone","ts":1790000000000,
        "payload":{"points":15,"dateKey":"2026-09-12"},"prevHash":"GENESIS"}
input  = "GENESIS" + core
HASH   = 695480d9ba350a60ec10ab41a86d98c91461855dc941a473fce7fa253d13eb1a
```
**حدث يربط بسابقه:**
```
core  = {"seq":2,"type":"lessonNew","ts":1790000000001,
         "payload":{"points":10,"dateKey":"2026-09-12"},
         "prevHash":"<HASH السابق>"}
input = HASH + core
HASH2 = 9de299e053c9d1e99fa64659feaa8f60d93abb424bf3205bb602cb2a3ac71863
```
**عربي (سبب يدوي — يجب أن يطابق بعدم التهريب):**
```
input = "GENESIS" + {"seq":3,"type":"manual","ts":1790000000002,
        "payload":{"points":30,"dateKey":"2026-09-12","reason":"جائزة الأستاذ"},
        "prevHash":"GENESIS"}
HASH3 = 626f48c83bcf65c17865318f07f68e108fa4db2419947625805c5ab1fe02568d
```
**توكن canonical:**
```
{"code_id":"K7M2P","device_key_hash":"","release_id":"2027-v1",
 "expires_at":1792592000000,"hard_deadline":1835904000000,"flags":["full"]}
TOKEN_HASH = a1056c6b9074696f04203e50d4968843274be7f022d97bb8b005c6680a5555ad
```
**بروتوكول اختبار أي وكيل للتوافق**: احسب HASH أعلاه بلغتك (Dart/TS/python)
على السلسلة النصية نفسها — تطابق الستة عشرين محرفاً الأخيرين كافٍ للتثبت
السريع، والمطابقة الكاملة إلزامية قبل أي نشر.

---

## ٧. النشر والاختبار (أوامر حقيقية)

```bash
# ربط المشروع (مرة — بك جلسة المالك):
supabase link --project-ref <PROJECT_REF>

# نشر الدوال الثلاث (بعد كل تعديل):
supabase functions deploy license_activate
supabase functions deploy heartbeat
supabase functions deploy verify_xp_events

# ضبط سر التوقيع (مرة — القيمة من أداة المالك، لا تمر بمحادثة):
supabase secrets set SIGNING_SEED_B64=<البذرة من tool/generate_license_key.dart>
```

**اختبار دخان بعد النشر** (بلا توقيع — يفحص المسار فقط):
```bash
curl -s -X POST "$URL/functions/v1/verify_xp_events" \
  -H "Authorization: Bearer $ANON_JWT" -H "Content-Type: application/json" \
  -d '{"device_pubkey_b64":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
       "last_synced_seq":0,"events":[]}'
# المتوقع 200: {"accepted":true,"synced_up_to":0,"server_time_ms":...}
```

---

## ٨. خريطة العميل ↔ الخادم

| ملف عميل (Dart) | يستهلك | الحالة |
|---|---|---|
| `core/license/license_core.dart` | حمولة التوكن canonical (§٦) + `checkLicense` على ردّ التفعيل/النبض | جاهز ✓ — `device_key_hash` فارغ اليوم |
| `core/license/license_store.dart` | تخزين التوكن `license_v1` | جاهز ✓ |
| `core/sync/sync_engine.dart` + `sync_store.dart` | عقد §٤.٢/§٤.٣ حرفياً (XpSyncApi) | جاهز ✓ محتبَر بزيف — الربط الحقيقي بعد URL/anon |
| `core/xp/xp_ledger.dart` + `xp_event.dart` | مصدر الأحداث المرفوعة (toJson = §٤.٢) | جاهز ✓ |
| `core/xp/xp_signer.dart` | `device_pubkey_b64` المرسل + توقيع الأحداث | جاهز ✓ (خزنة مؤقتة — Keystore مع F4.4-عميل) |
| شاشة الدوري (بنفسجي) | `league_standings` قراءة RLS | تُبنى (F4.6-واجهة) |
| `features/activation/activation_gate.dart` | استدعاء §٢ بعد URL/anon بالعميل | اليوم «قيد التجهيز» محلياً — يُوصَل بمنشئ Supabase |

---

## ٩. سجل التغييرات (قاعدة: أي تعديل خادم = سطر هنا بنفس الكومِت)

| التاريخ | التغيير | أثر على العميل |
|---|---|---|
| 2026-09-12 | الإنشاء الأول: 0002 + الدوال الثلاث + هذا العقد | لا شيء — العميل لم يتصل بعد |
| 2026-09-12 | قاعدة `device_key_hash` فارغة حتى Keystore (ثابت EMIT_DEVICE_HASH) | فحص العميل الحالي يرفض غير الفارغ — توثيق متبادل |
