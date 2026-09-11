# 🏭 دليل البناء على جهاز صاحب المشروع (قرار ٥١)

> cmd.exe **حصراً** (لا PowerShell — قاعدة المشروع) · كل مخرجات تُلصق في المحادثة **حرفياً** — نجاحاً أو خطأً.
> حلقة العمل: الجلسة تكتب الكود ← أنت تبني وتلصق النتيجة ← الجلسة تصلح ← تعيد.

## الخطوة ٠ — التجهيز (مرة واحدة في الحياة)
```bat
:: 1) أندرويد ستوديو (يشمل SDK وأدوات المنصة)
winget install -e --id Google.AndroidStudio

:: 2) فتح Android Studio مرة واحدة وإكمال معالج التثبيت (Default) ثم إغلاقه

:: 3) Flutter stable
winget install -e --id Flutter.Flutter

:: 4) فتح نافذة cmd **جديدة** والتحقق
flutter --version
flutter doctor -v
```
**الصق نتيجة `flutter doctor -v` كاملة هنا** — نصلح أي ✗ قبل أول بناء (متوقع: Licenses).
```bat
flutter doctor --android-licenses
```

## الخطوة ١ — أول بناء (F0.2)
```bat
cd /d %USERPROFILE%\<مسار المستودع>\Almorshed\app
flutter pub get
flutter build apk --debug
```
- أول بناء ينزّل Gradle والمكتبات — قد يستغرق ٥–١٥ دقيقة، هذا طبيعي.
- **الصق المخرجات كاملة هنا** مهما كانت.
- APK يظهر في: `build\app\outputs\flutter-apk\app-debug.apk`

## الخطوة ٢ — التثبيت على موبايلك
- فعّل «خيارات المطور + تثبيت من مصادر غير معروفة» على الموبايل، أو:
```bat
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```
- التحقق المطلوب: التطبيق يفتح بعنوان «فيزيا كلاش»، زر التبديل الفاتح/الداكن يعمل.

## الخطوط (تجهيز F0.3 — عند طلب الجلسة فقط)
حمّل من Google Fonts (OFL):
- Cairo (Variable): https://github.com/google/fonts/raw/main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf
- Tajawal: https://github.com/google/fonts/raw/main/ofl/tajawal/Tajawal-Regular.ttf و `Tajawal-Bold.ttf` و `Tajawal-Medium.ttf`
ضعها في `app\assets\fonts\` — وتعلن الجلسة عنها في pubspec ثم تبني مجدداً.

## قواعد الحلقة
1. لا تعدّل أي كود بيدك — كل تعديل عبر الجلسة (يظل موثقاً بالمستودع).
2. أي خطأ: انسخ **آخر ٥٠ سطراً** من المخرجات والصقها — لا تلخيص («ما زبطت» لا يكفي).
3. بعد كل نجاح: الجلسة تشطب المهمة وترفع — وأنت تكمل.
