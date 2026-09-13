# F4.4-تحصين — قواعد R8 للإصدار (Flutter يضيف قواعد المحرك تلقائياً).
# إبقاء ما يُستدعى انعكاسياً حصراً — البقية تُعمّى وتُقلَّص.
-keepattributes Annotation,Signature
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
