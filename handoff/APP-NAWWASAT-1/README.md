# APP-NAWWASAT-1 — نوطة النواسات الكاملة + الفلاشات الجديدة داخل التطبيق

> تاريخ: 2026-10-04 · الفرع: `arena/01a0f912-almorshed` (تأليف + محتوى) ← يُطبَّق على `dev/self-content` (التطبيق)

## ما الذي أضيف

### 1) المحتوى (في الحزمة)
| الملف | المحتوى |
|---|---|
| `tools/nawwasat-learning-units.json` | 33 وحدة (1.1–1.14، 2.1–2.11، 3.1–3.8): شرح = نص الأستاذ كما هو + بطاقات (143) + أمثلة + قوالب أسئلة (148) + `approved_by_teacher: false` |
| `tools/merge_nawwasat_pack.py` | **قاهر (idempotent)** — يدمج الوحدات في `app/assets/content/pack.json`: حقل `learningUnits` + بطاقات (9100+) + أسئلة (9300+، `approved:false`) + مواقع الفلاشات |
| `app/assets/content/pack.json` (فرعنا) | نسخة مدمجة للتحقق — على dev يُنفَّذ السكريبت (نفس الناتج) |

### 2) مواقع الفلاشات الجديدة داخل الدروس (دقيقة)
| الموقع | الفلاش | السبب |
|---|---|---|
| `U1C1P5` | `spring` | «حالة الحركة: Fs = k·(x₀+x)» — النابض نشط |
| `U1C2P6` | `torsion` | «٤. ماذا يعتمد عليه الدور؟ (التجارب الثلاث في الكتاب ص ٢٣–٢٤)» = تمهيد + تج ١–٣ |
| `U1C3P2` | `gravity` | «لماذا النواس الثقلي غير توافقي؟» (موجود مسبقاً) |
| `U1C3P11` | `simple` | «٦. التعريف — النواس الثقلي البسيط» ← T ~ √l |

### 3) ربط الفلاشات بتدفق الدرس (Dart)
الشاشات الموحّدة موجودة عندك على dev (دفعات 29–37) لكن تدفق الدرس لا يفتحها
(سجل `labExperiments` فيه 4 تجارب عامة فقط). الملفان:
- `handoff/APP-NAWWASAT-1/app/lib/features/lab/lesson_unified_experiments.dart` — سجل موازٍ + غلاف يحمّل TrainingData ويفتح الشاشة الصحيحة
- `tools/lesson_screen.patch` — 3 تعديلات دقيقة في `lesson_screen.dart` (يُطبَّق بـ `git apply`)

## الأوامر — حرفياً (نسخة Windows، فرع dev/self-content)

```bat
cd C:\Users\ASUS\Almorshed
git checkout dev/self-content
git pull
git fetch origin arena/01a0f912-almorshed

REM ⓪ إصلاح 7 أخطاء قديمة في شاشات مخبر (توقف البناء) — blvrails/induct/spring/strings/tube
git show origin/arena/01a0f912-almorshed:tools/fix-lab-screens.patch > tools\fix-lab-screens.patch
git apply tools\fix-lab-screens.patch

REM ① ملفات الحزمة من فرعنا
git show origin/arena/01a0f912-almorshed:handoff/APP-NAWWASAT-1/app/lib/features/lab/lesson_unified_experiments.dart > app\lib\features\lab\lesson_unified_experiments.dart
git show origin/arena/01a0f912-almorshed:tools/lesson_screen.patch > tools\lesson_screen.patch
git show origin/arena/01a0f912-almorshed:tools/nawwasat-learning-units.json > tools\nawwasat-learning-units.json
git show origin/arena/01a0f912-almorshed:tools/merge_nawwasat_pack.py > tools\merge_nawwasat_pack.py

REM ② ربط الفلاشات بتدفق الدرس
git apply tools\lesson_screen.patch

REM ③ دمج الـ 33 وحدة في الحزمة (يعمل مرة أو أكثر)
python tools\merge_nawwasat_pack.py

REM ④ فحص
flutter analyze
flutter test

REM ⑤ حجز ودفع
git add tools\fix-lab-screens.patch app\lib\features\lab\blvrails_screen.dart app\lib\features\lab\induct_screen.dart app\lib\features\lab\spring_screen.dart app\lib\features\lab\strings_screen.dart app\lib\features\lab\tube_screen.dart app\lib\features\lab\lesson_unified_experiments.dart app\lib\features\curriculum\lesson_screen.dart tools\lesson_screen.patch tools\nawwasat-learning-units.json tools\merge_nawwasat_pack.py app\assets\content\pack.json
git commit -m "APP-NAWWASAT-1: نوطة النواسات الكاملة (33 وحدة) في الحزمة + الفلاشات الجديدة (spring/torsion/simple/syringe) في الدروس بمواقعها"
git push origin dev/self-content
```

## ملاحظات
- **⓪ أخطاء قديمة (9 مواقع خطأ) في شاشات مخبر قديمة** (blvrails/induct/spring/strings/tube) — موجودة على dev من قبل حزمة، كانت توقف البناء. الإصلاحات: `w`→`size.width` (blvrails×3، spring×1)، `uOf()`→`uOf` (getter، induct×2)، `** 2`→`q*q` (ليس Dart، spring+strings)، `const Radius.circular(r)`→بدون const (tube).
- **لا شيء يُحذف**: الدمج إضافي فقط (حقل `learningUnits` + نطاقات معرّفات 9100+).
- **الأسئلة الجديدة `approved:false`** — محجوبة عن التدريب/المبارزات حتى اعتماد
  الأستاذ (قرار ٢٤). التفعيل = قلب `approved` بعد المراجعة.
- **الشاشات الخمسة للوحدة** (شرح ← بطاقة ← تجربة+تنبؤ ← مثال ← سؤال ∞) = مرحلة D
  من docs/35 — تُبنى بعد اعتماد الأستاذ؛ المحتوى كله حاضر في الحزمة الآن.
- إن أعطى `flutter analyze` أو `git apply` أي خطأ: انسخه هنا وأصلحه فوراً.
- `git apply` إذا قال «does not apply»: تأكد أنك على dev/self-content محدث (`git pull`).
