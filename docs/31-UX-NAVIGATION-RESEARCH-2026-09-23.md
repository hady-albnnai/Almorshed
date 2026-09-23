# ٣١ — بحث عميق: أفضل تجارب الملاحة (Navigation UX) لتطبيقات مراجعة الامتحانات — ٢٠٢٦-٠٩-٢٣

> بحث في مصادر ٢٠٢٥–٢٠٢٦ (أنماط الملاحة، Duolingo، الحمل المعرفي، التلعيب، RTL
> العربي)، مربوطًا ببنية «فيزيا كلاش» الفعلية. الغرض: قرارات تصميم مسنَدة بأدلة
> قبل أي تعديل واجهة كبير — لا تنفيذ بلا أمر المالك (بروتوكول docs/28).

---

## ٠. الخلاصة التنفيذية (٦ أسطر)
1. **بنيتنا الحالية سليمة أساسًا:** ٣ تبويبات سفلية (المنهاج/التدريب/التحديات) = ضمن
   قاعدة «٣–٥ وجهات» المتّفق عليها في كل المصادر. لا نغيّر الهيكل.
2. **أكبر مكسب متاح = تقليل الحمل المعرفي على الشاشة الرئيسية** (إيموجي متعدّد،
   ازدواج «تدريب»)، لا تغيير الملاحة.
3. **درس Duolingo:** «مسار واحد موجَّه» رفع نتائج التعلّم لكنه أثار ردّة فعل لأنه
   صادر حرية الاختيار — فلا نفرض مسارًا؛ نضيف **توصية «تابِع»** فوق الاختيار الحر.
4. **RTL:** يجب تدقيق انعكاس الأيقونات الاتجاهية (سهم «التالي» ←) مع إبقاء الأرقام
   والصيغ LTR (عندنا `MathText` يعالج هذا جزئيًا — نوسّعه للأسهم).
5. **التلعيب:** السلسلة/النقاط/الدوري موجودة — القاعدة: «لا يطغى الدوري بصريًا على
   الدرس». نراجع وزنها البصري.
6. **معايير قابلة للقياس** (§٦) لتقييم أي شاشة: ≤٣ نقرات، هدف واحد للشاشة،
   منطقة الإبهام، ٤٤–٤٨px لمسة.

---

## ١. المبادئ المتّفق عليها عبر كل المصادر (2026)

| المبدأ | القاعدة | المصدر |
|--------|---------|--------|
| عدد التبويبات | **٣–٥** وجهات رئيسية؛ أكثر = دقّة لمس أسوأ | [2](https://www.forasoft.com/blog/article/mobile-app-ux-design-best-practices) · [5](https://www.uxpin.com/studio/blog/mobile-navigation-examples/) · [8](https://deventiatech.com/blogs/mobile-ux-best-practices-every-app-must-follow) |
| ثلاث نقرات لأي شيء | أي ميزة رئيسية تُبلَغ في **≤٣ نقرات** من الرئيسية | [2](https://www.forasoft.com/blog/article/mobile-app-ux-design-best-practices) · [1](https://pmc.ncbi.nlm.nih.gov/articles/PMC11422584/) |
| شاشة = مهمة واحدة | إن كان للشاشة إجراءان رئيسيان متساويان ⇒ اجعلها شاشتين | [2](https://www.forasoft.com/blog/article/mobile-app-ux-design-best-practices) |
| منطقة الإبهام | ٧٥٪ من التفاعل بالإبهام؛ الثلث السفلي = المنطقة الآمنة للـCTA | [1](https://medium.com/ui-ux-designing-trends/mobile-app-navigation-design-2026-ux-best-practices-5b2db901790d) · [8](https://deventiatech.com/blogs/mobile-ux-best-practices-every-app-must-follow) |
| أيقونة + كلمة | الأيقونة وحدها ملتبسة؛ اقرنها بنصّ قصير | [3](https://www.designstudiouiux.com/blog/mobile-navigation-ux/) · [8](https://deventiatech.com/blogs/mobile-ux-best-practices-every-app-must-follow) |
| حالة نشطة واضحة | المستخدم لا يخمّن أين هو أبدًا | [5](https://www.uxpin.com/studio/blog/mobile-navigation-examples/) |
| مقاس اللمس | **٤٤×٤٤pt (iOS) / ٤٨×٤٨dp (Android)** حدًّا أدنى | [4](https://medium.com/@secuodsoft/the-complete-guide-to-creating-user-friendly-mobile-navigation-in-2025-59c9dd620c1d) · [5](https://www.uxpin.com/studio/blog/mobile-navigation-examples/) |
| لا تدفن المتكرر | لا تُخفِ المهام عالية التكرار في drawer/overflow | [3](https://www.designstudiouiux.com/blog/mobile-navigation-ux/) |

**تقييم بنيتنا:** ✅ ٣ تبويبات · ✅ أيقونة+كلمة (`NavigationDestination`) · ✅ حالة
نشطة (`selectedIndex`) · ✅ لا hamburger لوجهات رئيسية (الحساب أيقونة علوية —
ثانوية، مقبول). **نمرّ على القواعد الأساسية.**

---

## ٢. درس Duolingo — «المسار الواحد» (الأهم لنا)

Duolingo انتقل ٢٠٢٢ من «الشجرة» (اختيار حر متشعّب) إلى **«مسار خطّي واحد»**:
- **الهدف المعلن:** «تقليل الحيرة + رفع نتائج التعلّم» بجدولة مراجعة متباعدة تلقائيًا
  بدل ترك التوقيت للطالب [9](https://www.nbcnews.com/tech/tech-news/duolingos-update-redesign-luis-von-ahn-interview-rcna44655) · [3](https://blog.duolingo.com/new-duolingo-home-screen-design/).
- **مبدأ مضادّ للنمط:** «إياك أن تجعل الشاشة الرئيسية مجرّد لوحة تنقّل (hub) —
  اجعل **قلب الخدمة** (المسار/الدرس) هو أول ما يُعرض» [10](https://t-i-show.medium.com/design-for-learning-apps-ux-research-and-case-study-on-duolingo-1800d33744c9).
- **لكن ردّة الفعل كانت عنيفة:** المستخدمون غضبوا لأنه **صادر حرية الاختيار**
  (لا يمكن القفز بين المواضيع، لا اختيار «قصة أم درس»)، وكثُر التمرير
  [2](https://news.ycombinator.com/item?id=33673522) · [7](https://www.reddit.com/r/duolingo/comments/wx9ldb/thoughts_on_the_new_design/) · [8](https://uxdesign.cc/down-the-wrong-path-the-disaster-of-the-latest-duolingo-ui-update-a4cdd1e6ea1c).

**الترجمة لـ«فيزيا كلاش» (توازن، لا نسخ):**
- ✅ **خُذ:** بطاقة **«تابِع من حيث وقفت»** بارزة أعلى الرئيسية (عندنا بذرتها:
  `_continueChapter` سطر ٤١١) — تعطي التوجيه دون مصادرة الحرية.
- ✅ **خُذ:** عناوين وصفية بدل رموز («المجال المغناطيسي ٣» أفضل من «الوحدة ٣»).
- ❌ **اترك:** لا تفرض مسارًا خطّيًا يمنع فتح أي وحدة — طالب البكالوريا يراجع
  **حسب جدول امتحانه** لا حسب تسلسلنا. الحرية هنا ميزة لا عيب.

---

## ٣. الحمل المعرفي (Cognitive Load) — تشخيص الشاشة الرئيسية

المصادر الأكاديمية والتطبيقية تُجمع: **الحمل الدخيل (extraneous load) عدوّ التعلّم**؛
كل عنصر بصري زائد يستهلك ذاكرة عاملة كان يجب أن تذهب للفيزياء
[PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC11422584/) · [swavid](https://www.swavid.com/blogs/edtech-cognitive-load-student-overwhelm).

**قواعد مستخلصة:**
- «إن لم يفهم المستخدم الشاشة خلال ٣ ثوانٍ ⇒ فشلنا» [glance](https://thisisglance.com/blog/educational-apps-cognitive-learning-principles-in-design).
- محتوى بوحدات صغيرة، مسافات بيضاء، هرمية واضحة، **عنصر واحد مهيمن لكل شاشة**.
- خطّ ١٤–٢٢pt للأزرار، ≥١٠pt للنص؛ خط sans-serif [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC11422584/).
- «تجنّب المؤثّرات الزخرفية والأنيميشن الفخم» — تزيد التعقيد البصري.

**تشخيص شاشتنا الرئيسية (من الكود الفعلي `home_screen.dart`):**
| ملاحظة | الحالة | التوصية |
|--------|--------|---------|
| **إيموجي مختلف لكل بطاقة** 📘📝🎯⚔️📡🧪💡 | حمل بصري متنافس | أيقونات Material موحّدة الأسلوب بلون العلامة؛ الإيموجي للتمييز الخفيف فقط |
| **ازدواج مفاهيم «تدريب»**: «تدريب سريع» (رئيسية) + تبويب «التدريب» + «أسئلة الدورات» + «تدريب بالوحدة» | التباس تصنيفي | سطر توضيحي تحت كل خيار يفرّق الغرض؛ أو دمج «تدريب سريع» كاختصار داخل تبويب التدريب |
| كثرة البطاقات المتساوية الوزن | لا عنصر مهيمن | ارفع «تابِع من حيث وقفت» كعنصر مهيمن؛ اخفض البقية لقائمة أنظف |
| رسالة الخطأ في التفعيل بارتفاع ثابت ٢٠px | قد تُقصّ | تأكّد من عدم قصّ الرسائل الطويلة |

---

## ٤. التلعيب (Gamification) — أين نضع السلسلة/النقاط/الدوري

الإجماع: التلعيب **مرئيّ لكن لا يطغى**؛ القاعدة الذهبية:
> «خطأ شائع: السماح للوحة الصدارة أو أنيميشن المكافأة بأخذ انتباه أكبر من الدرس
> نفسه» [abbacus](https://www.abbacustechnologies.com/how-to-build-an-educational-app-with-gamification-and-rewards/).

**الميكانيكا المثبَتة لتطبيقات المراجعة** (Duolingo/RevisionDojo/Brilliant)
[trophy](https://trophy.so/blog/gamified-study-revision-apps):
- **السلسلة (streak)** + تجميد + تذكير لطيف (لا «إشعار تأنيب» عدائي).
- **XP + مستويات + هدف يومي/أسبوعي** = محرّك العادة اليومية.
- **دوري أسبوعي/موسمي** = منافسة اجتماعية — لكن اجعله **اختياريًا** ولوحة واحدة نظيفة.
- **شارات/إنجازات** للمعالم (٧ أيام، ١٠٠ سؤال…).

**تقييم «فيزيا كلاش»:** ✅ لدينا السلسلة (`streak_service`) + XP + دوري موسمي تراكمي
(قرار ٦٥) + الشهادة (F6.5) + مبارزات. **المنظومة مكتملة تقريبًا.** التوصية:
مراجعة **الوزن البصري** — تأكّد أن «تحدي اليوم» و«الدرس» أبرز من رقم الدوري.

---

## ٥. RTL العربي — تدقيق واجب (تطبيقنا عربي بالكامل)

القاعدة الحاسمة عبر كل مصادر RTL: **الانعكاس انتقائي لا شامل**
[milaaj](https://www.milaajbrandset.com/blog/rtl-mobile-app-design-arabic-users/) ·
[hamrix](https://hamrix.com/ksa/blog/arabic-rtl-ui-ux-design-guide) ·
[saudisoft](https://localization.saudisoft.com/rtl-design/):

| يُعكَس (RTL) | لا يُعكَس (يبقى LTR) |
|-------------|---------------------|
| تخطيط الصفحة، محاذاة النص لليمين | **الأرقام** (غربية ١٢٣ وعربية ١٢٣) |
| أسهم «التالي/السابق» (← بدل →) | **الصيغ الرياضية والمعادلات** |
| مؤشّرات التقدّم (تملأ من اليمين) | أزرار الوسائط (تشغيل/تقديم) |
| ترتيب التبويبات (الرئيسي لليمين) | الشعارات والرموز العالمية |
| الإيماءات (السحب معكوس) | أرقام الهواتف/الأكواد |

**تقييم «فيزيا كلاش»:**
- ✅ **الصيغ:** `MathText` يعزل الصيغ (FSI/PDI) — عمّمناه للتوّ على شاشات الأسئلة
  (كومِت `d670ef3`). ممتاز، يطابق التوصية حرفيًا.
- ✅ **التبويبات:** RTL يضع «المنهاج» يمينًا تلقائيًا (Flutter + `Directionality`).
- 🔲 **يلزم تدقيق:** الأسهم النصّية في الكود مثل `'${title} ←'` (home سطر ٤١١)
  و`'١٠ أسئلة ←'` — في RTL السهم `←` يشير لليسار = «التالي» صحيح بصريًا، لكن
  **يجب التأكد** أنه لا يُعرض معكوسًا مع محاذاة النص. تدقيق بصري على جهاز.
- 🔲 **يلزم تدقيق:** أي `Icons.arrow_forward/back` — هل تنعكس؟ Flutter يعكس
  بعضها تلقائيًا (`Icons.arrow_back` ذو نسخة معكوسة) لكن ليس كلها.

---

## ٦. قائمة تدقيق قابلة للقياس (طبّقها على أي شاشة)

مستخلصة من [2](https://www.forasoft.com/blog/article/mobile-app-ux-design-best-practices) (تدقيق ١٥ نقطة) و[3](https://www.designstudiouiux.com/blog/mobile-navigation-ux/) (١٤ نقطة):
1. ⬜ زمن أول قيمة < ٦٠ ثانية على تثبيت جديد.
2. ⬜ كل ميزة رئيسية ≤ ٣ نقرات من الرئيسية.
3. ⬜ CTA الأساسي في متناول الإبهام (الثلث السفلي).
4. ✅ التبويبات ٣–٥ (عندنا ٣).
5. ⬜ لمسة ≥ ٤٤–٤٨px لكل عنصر تفاعلي.
6. ✅ أيقونة + كلمة في الشريط السفلي.
7. ✅ حالة نشطة واضحة.
8. ⬜ شاشة واحدة = هدف واحد (الرئيسية تحتاج ضبطًا — §٣).
9. ⬜ لا تمرير طويل بلا داعٍ.
10. ⬜ رجوع متّسق يحترم زر النظام (Android).
11. ⬜ الأيقونات الاتجاهية منعكسة صحيحًا في RTL (§٥).
12. ⬜ الأرقام/الصيغ تبقى LTR (✅ عبر MathText؛ تدقيق البقية).
13. ⬜ تباين لوني ٤.٥:١ للنص (AppColors موثّقة النسب — جيّد).

---

## ٧. توصيات مرتّبة بالأولوية (قابلة للتنفيذ، بلا كسر بنية)

| # | التحسين | الأثر | الجهد | الحالة |
|---|---------|------|------|--------|
| ✅ | إعادة تصميم شريط إسناد التفعيل (توازن، لا كسر اسم) | بصري فوري | صغير | **مُنجز هذه الجلسة** (بانتظار دفع) |
| 1 | **توحيد أيقونات الرئيسية** (Material outlined بلون العلامة) بدل الإيموجي المتنافس | ↓ حمل معرفي | متوسط | مقترح |
| 2 | **إبراز «تابِع من حيث وقفت»** كعنصر مهيمن أعلى الرئيسية | ↑ توجيه (درس Duolingo) | صغير | مقترح |
| 3 | **سطر توضيحي** يفرّق «تدريب سريع/أسئلة الدورات/تدريب بالوحدة» | ↓ التباس | صغير | مقترح |
| 4 | **تدقيق RTL للأسهم** (نصّية + Icons) على جهاز حقيقي | صحّة عرض | صغير | مقترح |
| 5 | **مراجعة الوزن البصري للتلعيب** (الدرس > رقم الدوري) | ↑ تركيز | صغير | مقترح |
| 6 | **قياس ≤٣ نقرات** لكل ميزة + مقاس لمسة ٤٨dp | مطابقة معايير | متوسط | مقترح |

**القاعدة الحاكمة:** لا نغيّر الهيكل (٣ تبويبات سليمة) — كل التحسينات **تنقية
بصرية وتوجيه**، لا إعادة معمار. أي تعديل واجهة كبير يبقى موقوفًا على أمر المالك.

---

## ٨. المصادر
- أنماط الملاحة 2026: [1](https://medium.com/ui-ux-designing-trends/mobile-app-navigation-design-2026-ux-best-practices-5b2db901790d) · [2](https://www.forasoft.com/blog/article/mobile-app-ux-design-best-practices) · [3](https://www.designstudiouiux.com/blog/mobile-navigation-ux/) · [4](https://medium.com/@secuodsoft/the-complete-guide-to-creating-user-friendly-mobile-navigation-in-2025-59c9dd620c1d) · [5](https://www.uxpin.com/studio/blog/mobile-navigation-examples/) · [8](https://deventiatech.com/blogs/mobile-ux-best-practices-every-app-must-follow)
- Duolingo / المسار الواحد: [3](https://blog.duolingo.com/new-duolingo-home-screen-design/) · [9](https://www.nbcnews.com/tech/tech-news/duolingos-update-redesign-luis-von-ahn-interview-rcna44655) · [10](https://t-i-show.medium.com/design-for-learning-apps-ux-research-and-case-study-on-duolingo-1800d33744c9) · [2](https://news.ycombinator.com/item?id=33673522) · [8](https://uxdesign.cc/down-the-wrong-path-the-disaster-of-the-latest-duolingo-ui-update-a4cdd1e6ea1c)
- الحمل المعرفي: [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC11422584/) · [swavid](https://www.swavid.com/blogs/edtech-cognitive-load-student-overwhelm) · [glance](https://thisisglance.com/blog/educational-apps-cognitive-learning-principles-in-design)
- التلعيب: [trophy](https://trophy.so/blog/gamified-study-revision-apps) · [abbacus](https://www.abbacustechnologies.com/how-to-build-an-educational-app-with-gamification-and-rewards/)
- RTL العربي: [milaaj](https://www.milaajbrandset.com/blog/rtl-mobile-app-design-arabic-users/) · [hamrix](https://hamrix.com/ksa/blog/arabic-rtl-ui-ux-design-guide) · [saudisoft](https://localization.saudisoft.com/rtl-design/) · [simplelocalize](https://simplelocalize.io/blog/posts/rtl-design-guide-developers/)
