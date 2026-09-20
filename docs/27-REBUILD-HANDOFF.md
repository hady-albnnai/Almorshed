# ٢٧ — ملف تسليم إعادة البناء (NHTML)

> يُقرأ بعد `docs/26-REBUILD-HTML-PDF-PLAN.md`. يُحدَّث بعد **كل** مرحلة.

---

## الحالة الحالية

النوطة صارت **صفحة HTML دلالية كاملة (RTL)** مبنية من المصدر المجمّد بلا أي مساس به، ومعها معاينة جاهزة للعرض ومنظومة تحقّق مستقلة. لا CSS طباعة ولا PDF بعد.

- **NHTML-0** (جرد) ✅ ثم **إصلاحات جرد** ✅ (نص المربعات، تتبّع أبناء المجموعات، الفحوصات الفعالة، **منع تصادم معرّفات الكتل**).
- **NHTML-1** (استخراج) ✅ — نص حرفي · 1346 معادلة (مصحّحة R1–R14) · 78 صورة بايت-لبايت · تقارير مقارنة.
- **NHTML-4** (PDF) ✅ — `pdf/نوطة-النواسات.pdf` · 79 صفحة A4 · تذييل الأستاذ على كل صفحة · 0 قصّ/0 فارغة.
- **NHTML-3** (طباعة A4) ✅ — `html/print.css` · 0 قصّ/تجاوز · 101 صفحة · تذييل الأستاذ (حرفي) يُطبع في NHTML-4.
- **NHTML-2** (HTML) ✅ — `html/index.html` · MathML Core للـ 1346 معادلة · 399/399 رسماً في `<figure>` · 217 شبكة أعمدة · 13 سؤالاً · 6 جداول · بلا `float`/`position:absolute` · معاينة `preview-nhtml2.html` (7.51MB) · تحقّق: **0 حرف مفقود**.

## آخر مرحلة مكتملة

**NHTML-1 — استخراج المحتوى والأصول** + تطبيق قرار المالك بتصحيح الرموز R1–R14.

## آخر commit

- كومِت إصلاحات الجرد: `NHTML-0 fix: …` (انظر `git log --oneline -6`).
- كومِت المرحلة: `NHTML-1: extract literal content and source assets`.
- **آخر كومِت على `main` الآن:** اقرأه بأمر `git log -1 --format='%h %s'`.
- **آخر كومِت قبل هاتين المرحلتين:** `5dfb41d` (توثيق NHTML-0).

## المرحلة التالية

**NHTML-5 — التحقّق النهائي:** مقابلة كل عنصر معروض بعنصر مصدري (نصّ/صور/معادلات) عبر `content/reference-map.json` + مسح بصري لصفحات PDF (تغطية كل الصفحات) + تقرير مطابقة نهائي.

**قرارات NHTML-4:** مقاس العرض في الإخراج = منطقة محتوى A4 (680px) لا مقاس A4 الكامل · الملاءمة تُقاس بـ`scrollWidth` · الشبكة غير الملائمة تُحوَّل صفّاً واحداً · الجدول العريض يُصغَّر خطّه فقط · الرسوم تنزل في التدفّق (79 صفحة مقابل 66 في Word برسوم متراكبة).

**قرارات اتُّخذت في NHTML-3:** هامش سفلي 20مم (بدل 18) ليتّسع التذييل · `break-inside: auto` للأسئلة الطويلة (منع كسرها كان يُنتج صفحات فارغة) · تذييل الأستاذ يُرسم بقالب Chromium (تثبيت CSS داخل الصفحة يُقصّ عند حدّها — مُجرَّب).

**قرار اتُّخذ (كان معلّقاً):** المعادلات = **MathML Core أصلية** بتحويل مباشر OMML→MathML (نجحت في الاختبار العملي: كسور/جذور/محددات خضراء/`±`/`∓`/`⟸`/أسس).

**حُسم في NHTML-3:** الفجوات البيضاء ⇒ قياس على 217 شبكة أظهر 6 شبكات فقط فيها فراغ داخلي (مجموع 3090px) و**0 فراغات ميتة** بين الكتل؛ فقُبل الشكل مع إصلاح العرض الشريطي للأعمدة (حدود نسب 22–62%).

## العوائق / نقاط الخطر

1. ~~عرض المعادلات~~ ✅ حُلّ: MathML Core أصلية، 1346/1346، واللون الأخضر `008000` للمحددات محفوظ في مواضعه الستّة.
2. **التخطيط الجانبي:** ✅ 217 شبكة أعمدة (بحذف 78 خلية فارغة) — تحقّق: 0 حرف مفقود. المتبقّي: **الفجوات البيضاء** حيث كانت الرسوم عائمة في Word فأُعيدت في التدفّق بعد فقرتها — تحتاج ضبطاً في NHTML-3.
3. **162 مربعاً نصياً** داخل الرسومات تحمل تسميات الأستاذ (ليست زينة): نصوصها الآن كتل مستقلة في `content/text.json` (`in_textbox_of`) ويجب إعادتها كتسميات/بطاقات في مكانها الصحيح.
4. **صورة يتيمة واحدة** (`image1.png`) وصورتان تُستعملان في فرع VML المرآتي فقط — لا تُحذف، ومرجعها موثّق في `content/images.json`.
5. **فرق ترتيب حرف واحد** (`*` في خلية جدول فيها مربع نصي): موثّق في `reports/NHTML-1-content-extraction.md`؛ لا حرف مفقود أو مضاف (تعدّد الأحرف متطابق تماماً).
6. ملف الصور الوحيد الخارج عن الاستخدام المرئي: لا شيء — 78/78 نُسخت، و75 مستخدمة فعلياً.
7. توصية أمنية: رمز GitHub (token) الذي أُرسل في المحادثة يُبطَل ويُستبدل.

## الملفات الناتجة (NHTML-4)

| الملف | المضمون |
|---|---|
| `rebuild/nawwasat/pdf/نوطة-النواسات.pdf` | المخرج النهائي — 79 صفحة A4 · 4.81MB · تذييل الأستاذ على كل صفحة |
| `rebuild/nawwasat/tools/make_pdf.py` | مُخرِج PDF (Playwright) + فحوصه الآلية |
| `rebuild/nawwasat/content/pdf-check.json` | نتائج الفحص (متصفح + PDF) |
| `rebuild/nawwasat/reports/nhtml4-shots/` | 5 لقطات بمقاس منطقة المحتوى |
| `rebuild/nawwasat/reports/NHTML-4-pdf.md` | تقرير المرحلة (يشمل العيوب الخمسة) |

## الملفات الناتجة (NHTML-3)

| الملف | المضمون |
|---|---|
| `rebuild/nawwasat/html/print.css` | قواعد الطباعة A4 + تنسيق تذييل الشاشة |
| `rebuild/nawwasat/tools/check_print.py` | فحص الطباعة: قصّ/تجاوز/فراغات + لقطات + PDF تشخيصي |
| `rebuild/nawwasat/content/print-check.json` | نتائج الفحص الرقمية |
| `rebuild/nawwasat/reports/nhtml3-shots/` | 6 لقطات بمقاس عمود المحتوى المطبوع |
| `rebuild/nawwasat/reports/NHTML-3-print-css.md` | تقرير المرحلة |

## الملفات الناتجة (NHTML-2)

| الملف | المضمون |
|---|---|
| `rebuild/nawwasat/html/index.html` | المستند الدلالي الكامل (1,307,126 بايت) — المصدر الرسمي لـ NHTML-3/4 |
| `rebuild/nawwasat/html/styles.css` | تنسيق الشاشة والقاعدة (خطوط محليّة `assets/fonts`: Noto Naskh Arabic · Amiri · Noto Kufi Arabic) |
| `rebuild/nawwasat/html/fit-math.js` | ملاءمة عرض المعادلات الطويلة (تصغير فقط حتى 55%) — يُستدعى قبل الطباعة |
| `rebuild/nawwasat/html/preview-nhtml2.html` | معاينة قائمة بذاتها (خطوط + 75 صورة base64) للعرض الفوري بلا شبكة |
| `rebuild/nawwasat/tools/build_html.py` | بنّاء HTML (يقرأ المصدر للقراءة فقط) |
| `rebuild/nawwasat/tools/omml_to_mathml.py` | محوّل OMML→MathML Core (lxml فقط) |
| `rebuild/nawwasat/tools/make_preview.py` | مُنتِج المعاينة القائمة بذاتها |
| `rebuild/nawwasat/tools/build_reference_map.py` | خريطة كل عنصر ↔ موضعه المصري (أساس تحقّق NHTML-5) |
| `rebuild/nawwasat/tools/verify_html.py` | تحقّق «لا فقدان نصّ» عبر Chromium |
| `rebuild/nawwasat/content/structure.json` · `reference-map.json` · `verify-text.json` | التغطية · الخريطة المرجعية · نتائج التحقّق |
| `rebuild/nawwasat/reports/NHTML-2-structure.md` | تقرير المرحلة (يشمل العيوب الستّة التي أُصلحت) |
| `rebuild/nawwasat/reports/nhtml2-shots/` | 5 لقطات معاينة (بداية · سؤال · قوائم · عنقود · منتصف سؤال) |

## الملفات الناتجة (NHTML-1)

| الملف | المضمون |
|---|---|
| `rebuild/nawwasat/assets/images/` | 78 ملف صورة بايت-لبايت (بلا إعادة ضغط) |
| `rebuild/nawwasat/assets/equations/omml-corrected.jsonl` | 443 معادلة تغيّرت (OMML بعد التصحيح) |
| `rebuild/nawwasat/assets/equations/README.md` | سجل المصدر وكيف يُعاد التوليد |
| `rebuild/nawwasat/content/text.json` | 1916 كتلة بالنص الحرفي + المراجع والوسوم |
| `rebuild/nawwasat/content/text-literal.txt` | تفريغ مقروء للمراجعة العينية |
| `rebuild/nawwasat/content/images.json` | سجل الصور: بصمة · أبعاد · دور · موضع أول ظهور |
| `rebuild/nawwasat/content/equations.json` | 1346 معادلة: نص أصلي · مصحّح · بنية · موضع |
| `rebuild/nawwasat/content/extraction.json` | ملخّص الأعداد والفحوصات ومطابقة قواعد التصحيح |
| `rebuild/nawwasat/reports/NHTML-1-content-extraction.md` | تقرير المرحلة |
| `rebuild/nawwasat/tools/extract_content.py` | أداة الاستخراج (المصدر للقراءة فقط) |

## أرقام مرجعية معتمدة (مقيسة)

- المصدر: `notes/النواسات م_101932-r23-all-absolute-value-bars-green.docx` · SHA-256 `39dcae28ec74ad26520823b6057faeeefe9981ddd3c86a9f78244c27afd35d50`
- كتل: 1916 = 1910 فقرة + 6 جداول (1558 أعلى المستند · 245 في مربعات نصية · 107 في جداول)
- **معادلات معروضة: 1346** (و137 نسخة fallback مرآتية غير معروضة) — مفهرسة كلها، ومصحّحة 443 منها
- رسومات: 399 كائناً (383 عائم · 1 مضمّن · 15 ابن مجموعة) · صور 75 مستخدمة · 2 في fallback · 1 يتيمة
- الجداول: 6 كلها RTL · تذييل الأستاذ: «أ . فداء البني22  ******  0999608158»

## كيف تُعاد الأرقام

```bash
python3 rebuild/nawwasat/tools/inventory_docx.py     # الجرد (NHTML-0)
python3 rebuild/nawwasat/tools/source_audit.py       # تدقيق المصدر والرموز
python3 rebuild/nawwasat/tools/extract_content.py    # الاستخراج والتصحيح (NHTML-1)
```

الأدوات الثلاث **قراءة فقط** على ملف المصدر: لا تكتب ولا تعيد حفظ أي `.docx`.
