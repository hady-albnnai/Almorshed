# ١٨ — تدقيق الحقن الشامل (F7.4 · 2026-09-14)

> **السؤال:** كل خانة يمكن للطالب — أو أي شخص يملك المفتاح العام `anon` — أن يُدخل
> فيها بيانات: هل هي محصّنة ضد كل أنواع الحقن (SQL · NoSQL/jsonb · أوامر ·
> مسار/URL · XSS · تجاوز الحجم · تسميم النوع)؟
>
> **الطريقة:** تتبّع كل مدخل **من الخانة إلى عمود القاعدة** عبر ثلاث طبقات:
> ① العميل (منسّق/مرشّح) ② الخادم (دالة Edge أو سياسة PostgREST) ③ القاعدة
> (قيد/زناد). الحكم بقراءة الكود الفعلي — لا بالنوايا.
>
> **النتيجة في سطر:** لا يوجد أي مسار حقن SQL (كل الوصول مُعامَل parameterized
> عبر PostgREST/`supabase-js`/`plpgsql` بلا تركيب نصي)، ولا XSS (Flutter يرسم
> `Text` لا HTML). وُجدت **فجوتان في «شكل/حجم» البيانات** أُغلقتا اليوم
> (ترحيل `0007` + تشديد دالتين).

---

## ٠. لماذا حقن SQL مستحيل بنيوياً هنا

| القناة | كيف تصل القيمة إلى SQL | تركيب نصي؟ |
|---|---|---|
| PostgREST (`/rest/v1/...`) | مرشّحات URL تُترجم إلى استعلامات مُعامَلة داخل PostgREST | **لا** |
| `supabase-js` في Edge Functions (`.eq/.in/.insert`) | نفس PostgREST | **لا** |
| `admin.rpc('verify_commit', {...})` | استدعاء دالة بمعاملات jsonb/uuid مُنمّطة | **لا** |
| plpgsql (`0002`, `0005`) | `select ... where code = p_code` — لا `EXECUTE format()` بمدخلات خارجية | **لا** (مراجعة يدوية: `docs/16 §٨-أ`) |
| `office_codes` | `supabase-js` بمفتاح service_role خلف `x-office-key` | **لا** |

⇒ الخطر الحقيقي ليس «SQL injection» بل **البيانات المشوّهة/الضخمة** التي تعبر
PostgREST كـ jsonb/text ثم تُعامَل لاحقاً. لهذا التدقيق يركّز على **الشكل والحجم**.

---

## ١. جرد المدخلات (كل `TextField` + كل ما يُرسل للسيرفر)

### ١.١ خانات نصية يلمسها الطالب

| # | الخانة | الملف | مرشّح العميل | إلى أين تذهب | تحصين الخادم/القاعدة | الحكم |
|---|---|---|---|---|---|---|
| 1 | كود التفعيل | `activation_gate.dart` | `allow [A-Za-z0-9-]` + طول 17 + `formatLicenseCode` (أحرف كبيرة، تطبيع) | `license_activate` body `code` | `CODE_RE ^[0-9A-HJ-KM-NP-TV-Z]{15}$` ⇒ 422 · ثم `record_activation` (`where code = p_code`) · حدّ محاولات (مستخدم+IP) · 0007: `activation_codes_format` | ✅ |
| 2 | رمز غرفة المبارزة الحية | `duel_screen.dart` | `allow [a-zA-Z0-9-]` + طول 11 | `RoomCode.decode` (يرمي `FormatException` على أي محرف غريب) ثم **يُعاد ترميزه** `RoomCode.encode` ⇒ القيمة في URL **قانونية دائماً** من الأبجدية فقط | PostgREST `room_code=eq.` مُعامَل · 0007: `duels_room_code_format` | ✅ |
| 3 | عنوان IP للمبارزة المحلية | `local_duel_screen.dart` | `allow [0-9.]` + طول 15 | `Socket.connect` محلي (لا سيرفر) | `InternetAddress.tryParse` — قيمة غير صالحة ⇒ فشل اتصال فقط | ✅ (بلا سطح سيرفر) |
| 4 | رمز المبارزة المحلية (٦) | `local_duel_screen.dart` | `allow [a-zA-Z0-9]` + طول 6 | مقارنة نصية محلية على LAN | لا يصل لأي قاعدة | ✅ |
| 5 | مفتاح المكتب (لوحة الإدارة) | `admin_screen.dart` | `obscureText`، بلا اقتراحات | ترويسة `x-office-key` فقط — **لا يدخل أي URL أو body** | مقارنة نصية `===` مع السر | ✅ (المالك فقط) |
| 6 | مزلاق المختبر | `spring_lab_screen.dart` | `Slider` رقمي (`double.parse` على قيمة يولّدها الويدجت) | محلي — محاكاة | لا سطح خارجي | ✅ |

### ١.٢ ما يرسله التطبيق آلياً (يمكن تزويره بعميل مُعدَّل)

| # | الحمولة | الطريق | تحصين الخادم | تحصين القاعدة | الحكم |
|---|---|---|---|---|---|
| 7 | `device_pubkey_b64` | كل الدوال | `^[A-Za-z0-9+/]{43}=$` (32 بايت) ⇒ 422 | 0007: `devices_pubkey_b64_format` | ✅ |
| 8 | `device_fp` | `license_activate` | `slice(0,128)` + ≥ 8 | 0007: `devices_fp_len 8..128` | ✅ |
| 9 | `client_now_ms` | `heartbeat` | `Number.isFinite` وإلا `null` — للمقارنة فقط | — | ✅ |
| 10 | أحداث XP (`events[]`) | `verify_xp_events` | ≤ 500 حدثاً · تسلسل بلا فجوات · `prevHash` = آخر هاش · إعادة حساب SHA-256 على **الحمولة كما وردت** · توقيع Ed25519 بمفتاح **الجهاز المسجّل في القاعدة** · نوع من قائمة بيضاء · نقاط ثابتة/سقف يومي · **جديد اليوم:** `EVENT_SHAPE` (كائن، `type ^[a-zA-Z]{2,32}$`، أرقام لـ seq/ts، حمولة ≤ 2KB) + `reason ≤ 200` | 0007: `xp_events_type_known` · `payload_size ≤ 2048` · `hash_hex` · `sig_b64` | ✅ **(شُدِّد)** |
| 11 | إنشاء مبارزة (`room_code, seed, scope, host_device, host_name`) | PostgREST insert `duels` | سياسة `duels_insert_host` (جهازك + لوبي فارغ) · زناد `duels_guard_update` يمنع لمس status/scores/winner/seed/scope/room_code/host_name بعدها · `duel_finish` يعيد التوليد من البذرة ويرفض `SCOPE_MISMATCH` — **جديد اليوم:** `SCOPE_SHAPE` (units `U1..U5` ≤ 5، count 1..50) | 0007: `room_code_format` · `seed ≥ 0` · `scope_shape` (jsonb صغير بشكل معروف ≤ 512 بايت) · `host/guest_name 1..40` | ✅ **(شُدِّد)** |
| 12 | جلوس الضيف (`guest_device, guest_name`) | PostgREST update `duels` | زناد: لوبي غير ممتلئ + جهازك فقط (`DUEL_FULL/DUEL_NOT_YOURS`) | 0007: `guest_name_len` | ✅ |
| 13 | إجابة (`q_index, chosen`) | PostgREST insert `duel_answers` | سياسة: مشارك بمبارزة `live` فقط | `check q_index 0..49` · `chosen 0..9` (0005) | ✅ |
| 14 | «أنهيتُ» | PostgREST insert `duel_status` | سياسة: مشارك فقط | PK (duel, device) ⇒ مرة واحدة | ✅ |
| 15 | `duel_id` | `duel_finish` | `UUID_RE` ⇒ 422 · مشارك موثّق فقط | — | ✅ |
| 16 | قراءة الدوري | PostgREST select | `Uri.encodeComponent(pubkey)` في العميل · RLS `standings_select_licensed` | — | ✅ |
| 17 | `display_name` | (لا واجهة تكتبه اليوم — السياسة تسمح للمالك مستقبلاً) | — | 0007: `profiles_display_name_len 1..40` | ✅ (استباقي) |
| 18 | أداة المكتب (`count, distributor, release_id, hard_deadline, code, status`) | `office_codes` (خلف `x-office-key`) | `count` 1..100 · `distributor ≤ 64` · `release_id ≤ 32` · `code` مطبَّع + `CODE_RE` · `status` من قائمة | 0007: `activation_codes_format` | ✅ (المالك فقط) |

### ١.٣ Realtime (قناة المبارزة الخاصة)
رسائل البث بين اللاعبين **لا تُخزَّن** ولا تُستخدم كحقيقة: الحكم النهائي في
`duel_finish` يُعاد بناؤه من البذرة وإجابات `duel_answers` (مقيّدة أعلاه). سياسات
`realtime.messages` (0005) تحصر السماع/البث بالمشاركين. أي حمولة بث مزوّرة تؤثر
على **عرض** الخصم فقط لا على النتيجة. ✅

---

## ٢. XSS / حقن العرض
التطبيق Flutter: كل نص يُعرض بـ `Text(...)` — لا `WebView`، لا HTML، لا `dart:html`.
النصوص القادمة من الآخرين (اسم الخصم `host_name/guest_name`) تُرسم كسلسلة
حرفية؛ الطول محدود بـ 40 (0007) لمنع كسر التخطيط. أداة الطباعة `tool/office/print.html`
محلية على جهاز المالك وتُدخل الأكواد كنصّ (`textContent`) لا `innerHTML`. ✅

## ٣. حقن الأوامر / المسارات
لا استدعاءات `Process.run`، ولا بناء مسارات ملفات من مدخلات مستخدم في العميل
(`grep -rn "Process\.\|File(" app/lib` — لا شيء يتغذّى من إدخال). ✅

## ٤. تسميم النوع (jsonb)
قبل اليوم: `scope` و`payload` يُقبلان كأي jsonb عبر PostgREST ثم تُقرأ حقولهما
لاحقاً. الخطر: `count` كسلسلة/سالب/ضخم، `units` غير مصفوفة، حمولة بميغابايتات.
**أُغلق** بقيود 0007 على القاعدة + فحص شكل صريح في `duel_finish` (`SCOPE_SHAPE`)
و`verify_xp_events` (`EVENT_SHAPE`). ✅

## ٥. ما لم يتغيّر عمداً
- الهاش يُحسب على **الحمولة كما وردت حرفياً** (لا إعادة بناء) — تغييره يكسر
  توافق العميل/الخادم بايتاً-ببايت (docs/16 §٦).
- العميل يبقى «دفاعاً أول» فقط؛ كل حكم أمني على الخادم/القاعدة.

---

## ٦. ما نُشر وما ينتظر
| القطعة | الحالة |
|---|---|
| `0007_input_hardening.sql` | ⬜ يطبّقه المالك (بعد 0005 — قسم duels يتخطّى نفسه إن لم توجد الجداول ويطبع notice) |
| `verify_xp_events` (EVENT_SHAPE + reason ≤ 200) | ⬜ إعادة نشر |
| `duel_finish` (SCOPE_SHAPE) | ⬜ يُنشر مع المسار ب |
| العميل | لا تغيير مطلوب |

### تحقق بعد التطبيق (SQL Editor)
```sql
select conrelid::regclass as "الجدول", conname as "القيد"
from pg_constraint
where conname in (
  'duels_room_code_format','duels_seed_range','duels_scope_shape',
  'duels_host_name_len','duels_guest_name_len',
  'xp_events_type_known','xp_events_payload_size','xp_events_hash_hex','xp_events_sig_b64',
  'devices_pubkey_b64_format','devices_fp_len',
  'profiles_display_name_len','activation_codes_format')
order by 1, 2;
```
المطلوب: **13 صفاً** (أو 8 إن لم تُطبَّق 0005 بعد — قيود duels الخمسة تُضاف عند إعادة 0007 بعدها).
