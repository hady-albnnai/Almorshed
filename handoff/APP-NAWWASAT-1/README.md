# APP-NAWWASAT-1 — نوطة النواسات الكاملة + الفلاشات الجديدة داخل التطبيق

> تاريخ: 2026-10-04 · الفرع: `arena/01a0f912-almorshed` (تأليف + محتوى) ← يُطبَّق على `dev/self-content` (التطبيق)

## ما الذي أضيف في هذا الحزمة

### 1) المحتوى (جاهز — لا يحتاج تطبيق يدوي على dev/self-content)
| الملف | المحتوى |
|---|---|
| `content/generated/nawwasat-learning-units.json` | 33 وحدة (1.1–1.14، 2.1–2.11، 3.1–3.8): شرح = نص الأستاذ كما هو + بطاقات (143) + أمثلة + قوالب أسئلة (148) + أشكال + `approved_by_teacher: false` |
| `tools/build_nawwasat_learning_units.py` | يعيد توليد الملف أعلاه من `rebuild/nawwasat/units/*.json` |
| `tools/merge_nawwasat_pack.py` | **قاهر (idempotent)** — يدمج الوحدات في `app/assets/content/pack.json`: حقل `learningUnits` + بطاقات (9100–9242) + أسئلة (9300–9447، `approved:false` حتى اعتماد الأستاذ) + مواقع الفلاشات |
| `app/assets/content/pack.json` | **بعد الدمج** — نفس الحرفية، التغييرات: `learningUnits` + 143 بطاقة + 148 سؤال + 4 مواقع `experimentId` |

### 2) مواقع الفلاشات الجديدة داخل الدروس (دقيقة)
| الموقع | الفلاش | السبب |
|---|---|---|
| `U1C1P5` | `spring` | «حالة الحركة: Fs = k·(x₀+x)» — النابض نشط |
| `U1C2P6` | `torsion` | «٤. ماذا يعتمد عليه الدور؟ (التجارب الثلاث في الكتاب ص ٢٣–٢٤)» = تمهيد + تج ١–٣ |
| `U1C3P2` | `gravity` | «لماذا النواس الثقلي غير توافقي؟» (موجود مسبقاً) |
| `U1C3P11` | `simple` | «٦. التعريف — النواس الثقلي البسيط» ← T ~ √l |

### 3) ربط الفلاشات بتدفق الدرس (يُطبَّق على dev/self-content)
الشاشات الموحّدة (TorsionScreen/SimpleScreen/SyringeScreen/SpringLabScreen) موجودة
في `dev/self-content` (دفعات 29–37) لكن تدفق الدرس لا يفتحها (سجل `labExperiments`
يحتوي 4 تجارب عامة فقط). الملفان أدناه يفعّلان بطاقة «جرّبها بنفسك» للفلاشات الأربعة.

## خطوات التطبيق على جهازك (نسخة Windows — فرع dev/self-content)

```bash
cd C:\Users\ASUS\Almorshed
git checkout dev/self-content
git pull origin dev/self-content

# 1) انسخ ملفات الحزمة من فرعنا (أو انسخها يدوياً من GitHub):
git fetch origin arena/01a0f912-almorshed
git show origin/arena/01a0f912-almorshed:handoff/APP-NAWWASAT-1/app/lib/features/lab/lesson_unified_experiments.dart > app/lib/features/lab/lesson_unified_experiments.dart
git show origin/arena/01a0f912-almorshed:handoff/APP-NAWWASAT-1/app/lib/features/curriculum/lesson_screen.dart.patch > /tmp/lesson_screen.dart.patch

# 2) طبّق الـ patch على lesson_screen.dart:
git apply /tmp/lesson_screen.dart.patch

# 3) حدّث pack.json بالوحدات (السكريبت قاهر — يعمل مرة أو أكثر):
git show origin/arena/01a0f912-almorshed:content/generated/nawwasat-learning-units.json > content/generated/nawwasat-learning-units.json
git show origin/arena/01a0f912-almorshed:tools/merge_nawwasat_pack.py > tools/merge_nawwasat_pack.py
python tools/merge_nawwasat_pack.py

# 4) تحقق ثم احجز:
flutter analyze
flutter test
git add app/lib/features/lab/lesson_unified_experiments.dart app/lib/features/curriculum/lesson_screen.dart content/generated/nawwasat-learning-units.json tools/merge_nawwasat_pack.py app/assets/content/pack.json
git commit -m "APP-NAWWASAT-1: نوطة النواسات الكاملة (33 وحدة) في الحزمة + الفلاشات الجديدة (spring/torsion/simple/syringe) في الدروس بمواقعها"
git push origin dev/self-content
```

## ملاحظات
- **لا شيء يُحذف**: الدمج إضافي فقط (حقل `learningUnits` + نطاقات معرّفات مخصصة 9100+).
- **الأسئلة الجديدة `approved:false`** — محجوبة عن التدريب/المبارزات حتى اعتماد
  الأستاذ (قرار ٢٤). التفعيل = قلب `approved` بعد المراجعة.
- **الشاشات الخمسة للوحدة** (شرح ← بطاقة ← تجربة+تنبؤ ← مثال ← سؤال ∞) = مرحلة D من
  docs/35 — تُبنى بعد اعتماد الأستاذ للوحدات؛ المحتوى كله حاضر في الحزمة الآن.
- إن أعطى `flutter analyze` أخطاء: انسخها هنا وأصلحها فوراً.
