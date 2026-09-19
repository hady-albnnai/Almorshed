# الخطوط المستخدمة في إعادة البناء (NHTML-2)

خطوط حرة الترخيص (SIL Open Font License 1.1) تُضمَّن محلياً كي يعمل HTML/PDF بلا إنترنت:

| الملف | الخط | المصدر | الترخيص |
|---|---|---|---|
| `NotoNaskhArabic.ttf` | Noto Naskh Arabic (متغيّر wght 400–700) | https://github.com/google/fonts/tree/main/ofl/notonaskharabic | OFL 1.1 |
| `Amiri-Regular.ttf` | Amiri | https://github.com/google/fonts/tree/main/ofl/amiri | OFL 1.1 |
| `NotoKufiArabic.ttf` | Noto Kufi Arabic | https://github.com/google/fonts/tree/main/ofl/notokufiarabic | OFL 1.1 |

**الاستعمال:** النصّ العربي في `html/styles.css` عبر `@font-face` (مسار نسبي)، وتُدمج الخطوط base64 في `html/preview-nhtml2.html` (معاينة قائمة بذاتها).

**تنبيه:** لا تُستبدل خطوط المعادلات بأي خطّ عربي؛ معادلات MathML تُعرض بخطّ النظام الرياضي (`Cambria Math`/`Latin Modern Math`/`DejaVu Serif`).
