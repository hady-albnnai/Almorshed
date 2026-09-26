# ملف التسليم — المرشد في الفيزياء / فيزيا كلاش
> آخر تحديث: 2026-09-26 · الرأس المدفوع: `dev/self-content` = **`8d6a189`**
> هذا الملف هو مصدر الحقيقة لاستئناف العمل. اقرأه كاملاً قبل أي خطوة.

---

## 0) طريقة العمل الملزِمة للجلسة القادمة (لا تتجاوزها)
1. **كل العمل على الفرع `dev/self-content` فقط. ممنوع لمس `main` أو الدمج فيه إلا بأمر المالك الصريح «ادمج».**
2. **وثّق كل خطوة**: بعد كل دفعة عمل حدِّث هذا الملف (`docs/HANDOFF.md`) وأودِعه مع التغييرات، وسجِّل ما نُفِّذ في قسم «سجلّ الإجراءات».
3. **دفعات كبيرة ثم تبليغ** (بروتوكول «خطوة واحدة/دور» معلَّق للمهام الكبيرة). لا تعُد للمالك إلا حين تريد **فحصاً يتطلّب جهازه** (Flutter/Supabase) — لأنه لا يوجد Dart/Flutter SDK في بيئة العمل.
4. **الأخطاء تُعرض بالإنكليزية قصيرة** (استعمل `findstr`/`Select-String` على ويندوز).
5. **لا أسرار في أي ملف أو في `.git`.** شغّل مسح أسرار قبل كل إيداع (`grep -rlE "ghp_|-----BEGIN"`). التوكن يُوضع مؤقتاً في `remote set-url` ثم يُنظَّف (تحقّق `grep -c ghp_ .git/config` = 0).
6. **لا تنزيل Flutter SDK ولا Supabase CLI** — المالك يشغّلهما.
7. **التحقّق المستقلّ إلزاميّ**: أي تغيير في التوليد يُتبع بـ`python3 tools/verify_problems.py` + `python3 -m pytest tools/tests/ -q` (يجب 35/35) + `python3 tools/engine_ref.py`.
8. **لغة المالك**: `jl`/`تم`=أنجز · `ا`/`أ`=موافقة · `fhs`=فحص · `باسد`=passed · `تأتمت`=تلقائي · `بلش`=ابدأ · `فات`=دخل/نجح.

### أمر البناء الصحيح للمالك (بعد الدفع فقط)
```cmd
cd /d C:\Users\ASUS\Almorshed && git checkout dev/self-content && git pull && cd app && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter build apk --release --flavor student -t lib\main.dart
```
البناء **يتطلّب نكهة صراحةً** (نكهتان student/office): الطالب `--flavor student -t lib\main.dart` ⇒ `app-student-release.apk` · المكتب `--flavor office -t lib\office_main.dart`.

---

## 1) المشروع
تطبيق أندرويد تعليميّ (Flutter + Drift + Supabase) لطلاب البكالوريا العلمية — الفيزياء، منهاج دمشق 2026-2027. يعمل **أوف-لاين بالكامل بعد التفعيل**. مراجعة المادة: الأستاذ فداء البني (اسمه يظهر في شاشة التفعيل). المطوّر: loraneem-tech. المستودع: `github.com/hady-albnnai/Almorshed`.

---

## 2) أين وصلنا الآن (الحالة الراهنة)
اكتملت **دفعتان كبيرتان** ودُفعتا:

**دفعة 1 — أقصى بنك مسائل ثابت (`bc45357`):**
- المسائل المولّدة: **2775 → 7380** (تعداد شامل لكل توليفات القيم النظيفة، حتميّ). إجمالي بنود `items.json` = **12443** (7380 مسألة أجزاء + بقية MCQ). الحجم 44MB.
- **تحقّق مستقلّ كامل: 69/69 قالباً · 22138/22138 تطابق · صفر خطأ.**
- زمن التوليد: 5د+ (كان يفشل بـtimeout) → **50 ثانية** (تعداد `itertools.product` + كسر توقّف `STALL_LIMIT` للحلقات العشوائية).

**دفعة 2 — محرّك التوليد اللامتناهي على الجهاز + إثباته + الثيم (`8d6a189`):**
- **الهوية اللونية**: الأخضر → الطوبي/الدافئ (بقيت خُضرة النجاح الدلالية فقط) في `app/lib/core/theme/app_colors.dart`.
- **محرّك Dart** في `app/lib/core/gen/`: يقرأ أصلاً **177KB** (`templates.json`) ويولّد مسائل صحيحة بلا حدّ على الجهاز (بديل الـ44MB الثابتة).
- **إثبات رياضيّ كامل (بايثونياً، دون Dart)**: كلّها **صفر اختلاف**:
  - مقيّم التعابير `expr_eval.py` == `eval` على **30006** نداء عبر الـ69 قالباً.
  - المحرّك المرجعيّ المستقلّ `engine_ref.py` (من `templates.json` فقط) == المولّد المتحقَّق على **3537** تجهيزة ذهبية (2656 مقبولة · 881 مرفوضة).
  - تطابق التقريب Dart↔Python: fmt (948 قيمة) · fmt_sci (1294) · مسار round الأُسّي (1337) — لا تعادلات حقيقيّة تختلف.
- **pytest: 35/35** (32 قديمة + 3 جديدة تقفل الإثبات).

**الفحوص السابقة تبيّن أنها منجزة**: «FSRS» لا يظهر كنصّ للطالب (تعليقات/استيراد فقط) · لا أسماء دوال مسرّبة في خطوات MCQ · مدخل الأدمن غير مربوط بتطبيق الطالب (شيفرة ميتة تُشذَّب تلقائياً).

---

## 3) ⚠️ المشكلة العالقة الحاليّة (أولوية الجلسة القادمة رقم 1)
شغّل المالك `flutter test test/gen_golden_test.dart`. النتيجة:
- الاختبار **بدأ** ووصل السطر `+0: محرّك Dart يطابق المولّد المتحقَّق على 3537 تجهيزة ذهبية` وبقي عند **`+0`** (لم يكمل جسم الاختبار) طوال **~26 دقيقة**.
- ثمّ فشل بـ`PathNotFoundException: Deletion failed ... flutter_test_listener...` أثناء **إنهاء** الاختبار — **خلل بيئيّ في `flutter_tools` مع مجلّد temp على ويندوز، وليس فشل تأكيد منطقيّ**.

**التشخيص المرجّح**: مشكلة **أداء/إكمال** لا صحّة. الاختبار الواحد يمرّر 3537 تجهيزة ويقرأ ملف 6.2MB؛ 26 دقيقة رقم غير معقول ⇒ إمّا بطء فعليّ في مسار ما بالمحرّك على Dart VM، أو تعثّر بيئيّ (مضادّ فيروسات/temp/ضغط الجهاز بعد `git pull` ضخم بـ5.4M سطر).

**خطة الحلّ المقترحة (نفّذها بالترتيب):**
1. **قلّل حجم/زمن الاختبار**: في `tools/gen_golden.py` خفّض `SAMPLE_PER_TEMPLATE` (مثلاً 60 → 12–15) وأعد توليد `gen_golden.json` (سيصغر من 6.2MB) ⇒ تغطية ما تزال شاملة للأنماط. أعِد `python3 tools/gen_golden.py` ثمّ `python3 tools/engine_ref.py` (يجب صفر اختلاف) ثمّ `pytest`.
2. **قسِّم الاختبار**: بدل `test()` واحد بـ3537 تكراراً، اجعله `group` بمجموعات (مثلاً لكل قالب `test`) لعزل أي بطء/تعثّر ولإظهار تقدّم.
3. **جرّب `dart test`** بدل `flutter test` للنواة الخالصة (لا تعتمد على Flutter binding؛ الاختبار يقرأ ملفات فقط)، فقد يتفادى خلل `flutter_test_listener` على ويندوز.
4. إن ثبت البطء فعلياً: **قِس** أين (غالباً ليس في المحرّك). راجع `_floorLog10` (حلقات while على `math.pow`) و`Frac`/`_isqrtExact` — القيم صغيرة فالمفترض سريعة؛ لكن تأكّد لا حلقة لا نهائية على تجهيزة معيّنة.
5. أبلغ المالك ليُعيد فقط `cd app && flutter test test\gen_golden_test.dart` (أو `dart test test\gen_golden_test.dart`). المتوقّع بعد الإصلاح: **All tests passed** (عدد التجهيزات).

---

## 4) الخطة الكاملة (بعد حلّ #3)
1. **تثبيت الاختبار الذهبيّ** (القسم 3) — قبل أي شيء.
2. **ربط المحرّك بتبويب التدريب** كمصدر توليد لا متناهٍ، **مع رجوع آمن** إلى البنك الثابت (`items.json`) إن تعذّر. (تكامل UI — يحتاج فحص المالك بالبناء.)
3. **تجارب المختبر المتقدّمة** (طلب المالك: تجارب واقعية top-tier غير متوفّرة بسوريا). البدء موجود: `app/lib/features/lab/experiment_screen.dart` + الوثيقة `LAB_EXPERIMENTS_PROPOSAL.md`. مرشّحات: ميليكان · فرانك-هرتز · مايكلسون · يونغ · e/m طومسون · ثابت بلانك · كافنديش (انظر المصادر §7).
4. **إصلاح الوحدة الأولى في المنهاج فقط** (طلب المالك) — **يحتاج تحديد المالك: ما الخطأ تحديداً؟** (اسأله عند الوصول).
5. **SQL السحابة**: المالك يلصق `supabase/manual/apply_all_idempotent.sql` في Supabase. جهّز له الأمر/الخطوات عند الوصول (لا أسرار في الشات).
6. **شاشة البداية (splash)**.

---

## 5) قرارات المالك وقيوده (سارية — لا تُسقِط شيئاً)
- **كل العمل على `dev/self-content`؛ لا دمج في `main` إلا بأمر «ادمج».** التطبيق بكامله على هذا الفرع.
- **الحجم غير مهمّ** للمالك؛ يريد **المسارين معاً** (بنك ثابت أقصى + توليد لا متناهٍ) مع **تحقّق مستقلّ كامل**.
- **المسائل مولَّدة تغطّي كل احتمالات الفحص** (لا نقل أسئلة الدورات). الأنماط المحدودة فيزيائياً تُوسَّع بأنماط شقيقة لا بأرقام مصطنعة.
- **الثيم**: استبدال الأخضر بالطوبي (نُفِّذ). المختبر يُرفع لأعلى طراز. التدريب: توليد تلقائي على سلّم الوزارة (نُفِّذ). البطاقات: حذف «FSRS» من واجهة الطالب (لا يظهر). الكويز: حذف أسماء الدوال من شرح MCQ (نظيف). المراجعة تبويب فرعي. مدخل الأدمن يُزال من تطبيق الطالب (غير مربوط).
- **أداة المكتب** مستقلّة تحمل `OFFICE_KEY` فقط؛ لوحة الأدمن نُقلت إليها (`office_console_screen.dart`) وتُزال من تطبيق الطالب.
- **اسم الأستاذ فداء** يبقى في شاشة التفعيل (رغم قرار سابق بتجاهل الإشراف العلمي).
- «وضع المراجعة» أُزيل من تطبيق الطالب مع إبقاء «تبويب المراجعة» الدراسي.
- شعار لورانيم = بانر المالك العريض. اسم «فيزيا كلاش» على الأيقونة (نُفِّذ).
- بروتوكول docs/28: استعلم/تأكد ← موافقة ← تنفيذ (معلَّق للدفعات الكبيرة) · وثّق بالمستودع.

---

## 6) بيئة Git (تضيع كل دور — أعِد ضبطها)
`.git/config` (remote URL + user + promisor/partialclonefilter + sparseCheckout) يُفقد كل دور. الروتين الآمن للإيداع والدفع:
```bash
cd /home/user/aw
git config remote.origin.promisor true
git config remote.origin.partialclonefilter blob:none
git config core.sparseCheckout true
git remote set-url origin https://loraneem-tech:<PAT>@github.com/hady-albnnai/Almorshed.git
git fetch origin refs/heads/dev/self-content              # الحقيقة عبر FETCH_HEAD لا origin/...
git reset -q --soft FETCH_HEAD && git reset -q HEAD       # فهرس نظيف من رأس البعيد
git add --sparse <ملفاتك فقط>                              # content/ وdocs/ خارج sparse ⇒ --sparse إلزاميّ
grep -rlE "ghp_|-----BEGIN" <ملفاتك> && echo LEAK || echo clean
git -c user.name=loraneem-tech -c user.email=loraneem-tech@users.noreply.github.com commit -q -m "..."
git push origin HEAD:dev/self-content
git remote set-url origin https://github.com/hady-albnnai/Almorshed.git   # تنظيف PAT
grep -c ghp_ .git/config                                  # يجب = 0
git ls-remote origin refs/heads/dev/self-content          # تأكيد الرأس
```
- **التوكن (PAT) للجلسة** (مرّره المالك، «احتفظ فيه»): يُستعمل مؤقتاً في `set-url` ثم يُنظَّف؛ **لا يُكتب في أي ملف/‏.git**. القيمة تُطلب من المالك أو من ذاكرة الجلسة السابقة.
- بعد `reset --soft` نفّذ `git reset -q HEAD` ثمّ `git add` لملفاتك حصراً كي لا تُرجِع تغييرات قديمة.
- جلب SHA مباشرة يفشل ⇒ اجلب `refs/heads/…`. اعتمد `ls-remote`/`FETCH_HEAD` لا مراجع التتبّع.
- **مراجع بعيدة**: `dev/self-content` = **`8d6a189`** (والده `bc45357`، جدّه `39f2828`). **`main` = `2fdbce57`** (ليس شغلي؛ ممنوع الدمج).
- ملفات `/tmp` لا تدوم بين الأدوار.

---

## 7) مساحة العمل والملفات المهمّة
جذر العمل: `/home/user/aw`. المُحقَّق (sparse) = `app/` + `supabase/` + `tools/`. `content/` و`docs/` خارج sparse (استعمل `git add --sparse`).

**مولّد المسائل (بايثون):**
- `tools/gen_items.py` — المولّد. `--asset --parts-asset --approve`؛ `--per-template` افتراضي **2000** (تعداد شامل لقوالب parts، وكسر توقّف `STALL_LIMIT=6000` لحلقات MCQ). seed=2026.
- `tools/verify_problems.py` — **تحقّق مستقلّ 69/69 قالباً** (يعكس الفيزياء من الجذع + القيم المخرجة، لا من YAML/compute).
- `tools/tests/test_gen_items.py` (32) + `tools/tests/test_engine_ref.py` (3) = **35**.
- قوالب المصدر: `content/authoring/templates/{U1,U1b,U2,U3-U5,U6_extra_problems}.yaml` (69 قالب parts ضمنها). الدمج عبر `load_docs()` (يدمج `distractor_rules` + `constants` عبر الملفات).

**محرّك التوليد على الجهاز (الإثبات + Dart):**
- `tools/expr_eval.py` — مقيّم تعابير مستقلّ (نظير Dart). مُثبت == `eval`.
- `tools/engine_ref.py` — محرّك مرجعيّ مستقلّ من `templates.json` فقط. مُثبت == المولّد على الذهبيّ. يحوي المنسّقات (fmt/fmt_sci/nice/nice_sci/sqrt_str/pi_str) + `Engine` + `canon`/`deep_eq`.
- `tools/gen_golden.py` — يُصدِّر `app/test/fixtures/gen_golden.json` (تجهيزات ذهبية) + `app/assets/content/templates.json` (أصل المحرّك). ثابت `SAMPLE_PER_TEMPLATE`.
- `app/lib/core/gen/expr_eval.dart` — نقل `expr_eval.py`.
- `app/lib/core/gen/problem_engine.dart` — نقل `engine_ref.py` (المنسّقات + `Frac` نظير CPython + `ProblemEngine.fromParts`).
- `app/test/gen_golden_test.dart` — الفحص الذهبيّ (يشغّله المالك). يقرأ الأصل والتجهيزات من القرص مباشرةً.
- `app/assets/content/templates.json` (**177KB**) — 69 قالب parts + `constants` + `namespace`(g, pi_sq) + `distractorRules`. مشمول بالأصول تلقائياً (`assets/content/`).
- `app/test/fixtures/gen_golden.json` (**6.2MB** حالياً — سيصغر عند خفض العيّنة).

**المحتوى/الأصول:**
- `app/assets/content/items.json` (**12443 بند / 7380 مسألة**، 44MB) — المحمّل الثابت الحيّ حالياً.
- `content/generated/*.json` — مخرجات المولّد لكل وحدة.
- `app/lib/core/content/{generated_items.dart, content_loader.dart, models.dart}` — قراءة البنود؛ `_internalTagRe` يزيل وسوم `[rule]` من الخطوات.
- `app/lib/core/grading/parts_grading.dart` — تصحيح «سطراً سطراً» + متابعة الخطأ.

**الثيم والواجهة:**
- `app/lib/core/theme/{app_colors.dart (primary=طوبي 0xFFDD6E42), app_theme.dart}`.
- `app/lib/features/shell/app_shell.dart` — الرئيسية. `app/lib/features/training/{training_screen,item_session_screen,cards_screen,card_review_screen}.dart`.
- `app/lib/features/lab/{lab_screen,experiment_screen,spring_lab_screen}.dart` + الفيزياء `app/lib/core/lab/experiments.dart`.
- النكهات: `app/android/app/build.gradle.kts` + `app/lib/{main.dart, office_main.dart}`.

**السحابة:** `supabase/manual/apply_all_idempotent.sql` (جداول المنافسة/الدوري/المبارزات).

---

## 8) صيغ التوليد المرجعيّة (مؤكّدة)
- **بنية قالب parts**: `id, title, chapter(U#C#), type:problem, difficulty, source, vars{name:{set,unit}}, constants_used, compute{key:expr}, constraints[]?, stem, parts[], answer_basis`. الجزء: `label, ask, unit, value|text, answer{format:auto|sci, sig?, round?, unit_required?}, compute{}?, follow{depends_on,power,also?}?, lines[{relation,subst,expect,keys,anti_keys,points?,result?,unit?}], distractors[{rule,value|text,value_format?,allow_rough?,rationale?}]`.
- **الفضاء الاسميّ**: `pi, sqrt, sin, cos, tan, acos, asin, atan, abs, log, log10, exp, round, min, max, floor, ceil, int, float, radians, degrees` + ثوابت + `g=10, pi_sq=10` + `e_charge=1.6e-19, m_e=9.1e-31, c_light=3e8, h_planck=6.63e-34` (لا G؛ يُكتب literal 6.67e-11).
- **قواعد الـ69 قالب parts** (نطاق المحرّك): حساب + `**` + شرطيّ `a if c else b` (نادر) + `== > <=` + `sqrt/abs` + سلاسل. **لا** f-string ولا `.set` ولا فهرسة قاموس ولا `in` (هذه في قوالب MCQ فقط، خارج نطاق محرّك Dart حالياً).
- **`_render`**: `{name}` · `{name:sci|pi|sqrt}` · تحوّل علميّ تلقائيّ إذا `abs<1e-4 أو >=1e10 أو (>=1e4 وليس صحيحاً)`.
- **السلّم (parts-v1)**: العلاقة 5 · التعويض 3 · النتيجة 1 · الوحدة 1؛ وزن الجزء = مجموع أسطره، ووزن البند = مجموع أجزائه (لا يختلف السلّم عن الوزن).

---

## 9) أخطاء ومزالق (لا تُكرَّرها)
- **`--per-template` عالٍ مع سحب عشوائيّ ⇒ timeout.** الحلّ المطبَّق: تعداد شامل `itertools.product` لقوالب parts + `STALL_LIMIT` لحلقات MCQ.
- **regex الفاحص**: `([\d.]+)` يلتقط النقطة الختامية ⇒ استعمل `(\d+(?:\.\d+)?)`. وبعض «الثوابت» متغيّرة بين النسخ (مضاعِف h في U5.L1.P02، θmax في U1.L3.P01) ⇒ استخرجها بـregex.
- **بعض معرّفات القوالب (U1.L3.P01…) ليست في U6 YAML** بل قوالب أقدم؛ الفاحص المستقلّ يعتمد الجذع + القيم المخرجة.
- **`git commit` قد يفشل «Error building trees» إذا blob مفقود**؛ set-url قبل أي جلب lazy.
- **`git fetch` قد يكتب مرجع تتبّع قديماً مضلِّلاً** ⇒ اعتمد `ls-remote`/`FETCH_HEAD`.
- **`test_parts_have_no_flat_answer` يفرض followThrough؛ `follow:{power:0}` ممنوع.**
- **بناء Flutter يفشل بلا `--flavor`.**
- **⚠️ الاختبار الذهبيّ بطيء/يتعثّر على ويندوز** (القسم 3) — قيد الحلّ.
- **`Fraction` لأعداد عائمة**: نُقلت خوارزمية CPython (`limit_denominator` + `as_integer_ratio` عبر مضاعفة ×2). القيم في المحرّك بسيطة (√10, √40/3, √(5/2)…).
- **تقريب Dart نصف-لأعلى (ECMAScript) مقابل Python نصف-للزوج**: فُحص ولا يوجد تعادل حقيقيّ يختلف على مادّتنا (صفر). إن ظهر مستقبلاً، انقل التقريب لنصف-للزوج في `num_format`.

---

## 10) سجلّ الإجراءات (هذه الجلسة)
1. أكملت التحقّق المستقلّ 69/69 (`verify_problems.py`) — 17188 ثمّ 22138 فحص، صفر خطأ.
2. حوّلت توليد parts إلى تعداد شامل + `STALL_LIMIT` + رفعت الافتراضي إلى 2000 ⇒ 7380 مسألة، pytest 32/32، صفر معطوبات. إيداع `bc45357` + دفع.
3. الثيم: الأخضر → الطوبي (`app_colors.dart`).
4. `expr_eval.py` (مقيّم مستقلّ) — أثبتّ == `eval` على 30006 نداء (صفر اختلاف).
5. `gen_golden.py` ⇒ `gen_golden.json` (3537 تجهيزة) + `templates.json` (177KB).
6. `engine_ref.py` (محرّك مرجعيّ مستقلّ) — أثبتّ == المولّد على 3537 (صفر اختلاف).
7. نقل إلى Dart: `expr_eval.dart` + `problem_engine.dart` + `gen_golden_test.dart`. فحصت تطابق تقريب Dart↔Python (fmt/fmt_sci/round) — صفر اختلاف حقيقيّ.
8. `test_engine_ref.py` (3 اختبارات) ⇒ pytest **35/35**. إيداع `8d6a189` + دفع + تأكيد ls-remote + تنظيف PAT.
9. المالك شغّل الاختبار الذهبيّ ⇒ تعثّر بيئيّ/أداء على ويندوز (القسم 3). أنشأت ملف التسليم هذا.
