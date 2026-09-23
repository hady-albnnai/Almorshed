# F3.1 — القاعدة المحلية المشفّرة (Drift + SQLCipher)

## ما في هذا المجلد
| الملف | الدور |
|---|---|
| `tables.dart` | تعريف الجداول الثمانية (تعريفات خالصة، بلا منطق) |
| `app_database.dart` | قاعدة Drift المركزية + فتح اتصال SQLCipher مشفّر + بذرة Keystore |
| `app_database.g.dart` | **مولَّد** — يُنشئه `build_runner` على جهازك (غير موجود بعد) |

## الجداول (تغطّي نطاق F3.1: منهاج/تقدم · أخطائي · بطاقات+FSRS · دفتر XP · سلسلة · إعدادات)
- `ChapterProgressRows` ← يحلّ محل `progress_v1`
- `DailyBatchRows` · `MistakeRows` · `CardStateRows` · `CardDayRows` · `LabChallengeRows` ← يحلّ محل `training_v1`
- `XpEventRows` ← يحلّ محل `xpledger_v1` (السلسلة تُخزّن كما هي — Drift ناقل)
- `SettingsRows` ← key/value عام (ثيم/أعلام/مفاتيح يوم مفردة)

> السلسلة اليومية (`streak_service`) تُحسب من صفوف `XpEventRows` مباشرةً — لا تحتاج جدولاً خاصاً.

## خطوتك على الجهاز (قرار ٥١)
```bat
cd C:\Users\ASUS\Almorshed\app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
- `build_runner` يولّد `app_database.g.dart`. **قبل توليده سيفشل `analyze`** على هذا الملف (part مفقود) — هذا متوقّع.
- الصق مخرجات `analyze`/`test` هنا لأصلح أي خطأ من نصّه.

## الأمان (قرار ٣٠)
- الملف `fizya_clash.db` مشفّر بالكامل على القرص بـSQLCipher (AES-256).
- المفتاح: بذرة ٣٢ بايت عشوائية تُنشأ **مرة واحدة** وتُحفظ في `flutter_secure_storage` (Keystore).
- `PRAGMA cipher_version` يُفحص عند الفتح — لو فارغ ⇒ المكتبة ليست SQLCipher ⇒ استثناء صريح (لا نكتب بلا تشفير صامتاً).

## التالي (أدوار قادمة — خطوة بخطوة)
1. تنفيذ `DriftProgressStore` / `DriftTrainingStore` / `DriftXpEventStore` خلف الواجهات المجرّدة القائمة (بلا كسر عقودها).
2. اختبارات وحدة على قاعدة `AppDatabase.forTesting()` (ذاكرة، بلا تشفير).
3. توصيل `main.dart` لاستخدام تنفيذات Drift + **ترحيل لمرة واحدة** من `shared_preferences` القديمة (يُقرأ المفتاح القديم مرة، يُكتب في القاعدة، يُعلَّم مُرحَّلاً).
