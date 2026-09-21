# content/generated — مخرجات المولّد (المادة ١٠)

| الملف | المحتوى |
|---|---|
| `U1.items.json` … `U5.items.json` | المجمّع لكل وحدة: كل البنود الصالحة من قوالب `content/authoring/templates/*.yaml` (البذرة 2026، ٦ بنود لكل قالب محسوب) |
| `ALL.items.json` | المجمّع الكامل للوحدات الخمس (١٧ فصلاً — ~٥٥٠ بنداً) |
| `ALL.sample100.json` | عيّنة ١٠٠ بند للأستاذ فداء البني موزّعة بأوزان السلم الوزاري ٢٠٢٦ (`CHAPTER_WEIGHTS`) ومتوازنة بين القوالب |
| `U1.sample100.json` | عيّنة الوحدة الأولى القديمة (تُنتَج بـ`--u1-only`) |

- إعادة التوليد: `python3 tools/gen_items.py --seed 2026 --n 100 --per-template 6` (أضف `--asset` لكتابة `app/assets/content/items.json`)
- ملفات القوالب: `U1.yaml` (النواسات) · `U1b.yaml` (الموائع + النسبية) · `U2.yaml` (المغناطيسية → المحوّلات) · `U3-U5.yaml` (الأوتار/المزامير، بور/المهبطية/الكهرضوئي، الفلك).
- المحرّك العام: القالب يصف `vars` (مجموعات) + `compute` (تعابير بايثون تُقيَّم بالترتيب، `key` إلزامي) + `constraints` + `stem` بمتغيرات `{x}`؛
  الرقمي: `answer: {unit, format: sci|auto, sig, round}` + `distractors: [{value, rule, rationale}]`؛ الاختياري: `options.key` + `distractors[].text`؛
  المفاهيمي: `variants[]`. كل `rule` يجب أن تكون موثّقة في `schema.distractor_rules` بأحد الملفات.
- الدمج في حزمة التطبيق (`app/assets/content/pack.json` قسم `items`): أضف `--pack` — **لا يُنفَّذ قبل اعتماد الأستاذ**.
- الاختبارات: `python3 -m pytest tools/tests -q`
- كل بند `approved: false`؛ حقول `optionRules/optionValues/solutionSteps` تشرح كل مشتت بقاعدته الموثّقة.
- القوالب التي تحتاج شكلاً (`needs_figure`) لا تُولَّد بعد: `U1.L1.T20`, `U1.L2.T13`, `U1.L3.T15`.
- المصادر (الكتاب، النوطة، أوراق الدورات) خارج المستودع (قرار ٥٥).

تم الإشراف على المادة العلمية من قبل الأستاذ القدير فداء مأمون البني

## المادة ١٢ — شاشة التدريب في التطبيق

- الأصل: `app/assets/content/items.json` = نسخة `ALL.items.json` (المنهاج كاملاً، ١٧ فصلاً، كلها `approved:false`).
- النموذج: `app/lib/core/content/generated_items.dart` — `GeneratedItemsPack.visible(reviewMode:)`:
  الطالب يرى **المعتمد فقط** (قرار ٢٤)، والأستاذ في وضع المراجعة يرى الكل.
- الشاشة: `app/lib/features/training/item_session_screen.dart` (المدخل: التدريب ← «البنود المولّدة من المنهاج»):
  اختياري ببطاقات ملوّنة + سبب كل مشتت · رقمي (قيمة + وحدة، ±٢٪ والوحدة درجة مستقلة) ·
  علّل (نص حر بمفاتيح مطبَّعة) · برهان (ترتيب الخطوات بالنقر + إعلان «بلا إشارة»/«بلا φ» ⇒ −٤/−١).
- بندا `problem` بلا مفتاح رقمي (زاوية/رمزي: 20259، 20267) يُعرضان كخيارات — لا تخمين في التصحيح.
- بلا XP وبلا حفظ للجلسة قبل المصادقة.
