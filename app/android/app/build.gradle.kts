import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// توقيع الإصدار (قرار المالك — dev/self-content): تُقرأ بيانات المفتاح من
// android/key.properties (مُتجاهَل في Git). إن غاب الملف يتراجع البناء إلى توقيع
// debug تلقائياً حتى لا تتعطّل الاختبارات/التجريب.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.loraneemtech.fizya_clash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // مطلوب لـAGP الحديث حتى يُسمح بـresValue داخل النكهات (اسم التطبيق لكل نكهة).
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        applicationId = "com.loraneemtech.fizya_clash"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // F3.7: flutter_secure_storage v9 يشترط API 23+ (أندرويد 6+)
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // يُنشأ فقط عند وجود key.properties (وإلا نستخدم debug في release).
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // مفتاح الإنتاج إن وُجد key.properties، وإلا debug للتجريب/الاختبارات.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // F4.4-تحصين (MASVS-CODE/RESILIENCE): تقليص وتعمية — يجب
            // اختبار أول بناء إصدار يدوياً (M7) قبل التوزيع.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // نكهتان (قرار المالك): تطبيق الطالب «فيزيا كلاش» + أداة المكتب المستقلّة
    // «أكواد لورانيم» بمعرّف حزمة مختلف حتى تُنصَّب جنبه لا بدله.
    //   الطالب: flutter build apk --flavor student
    //   المكتب: flutter build apk --flavor office -t lib/office_main.dart
    flavorDimensions += "app"
    productFlavors {
        create("student") {
            dimension = "app"
            // يرث applicationId الافتراضي (com.loraneemtech.fizya_clash)
            resValue("string", "app_name", "فيزيا كلاش")
        }
        create("office") {
            dimension = "app"
            applicationId = "com.loraneemtech.fizya_clash.office"
            resValue("string", "app_name", "أكواد لورانيم")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
