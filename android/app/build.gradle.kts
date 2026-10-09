import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci tanda tangan APK. Kunci yang sama wajib dipakai terus supaya
// pembaruan aplikasi bisa dipasang tanpa menghapus versi lama.
// Sumber: android/key.properties (lokal, tidak di-commit) atau
// variabel lingkungan BM_KEYSTORE_* (GitHub Actions secrets).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
fun keyValue(prop: String, env: String): String? = keyProps.getProperty(prop) ?: System.getenv(env)
val releaseStore: String? = keyValue("storeFile", "BM_KEYSTORE_PATH")

android {
    namespace = "com.reyhan.baterai_motor"
    compileSdk = 37 // dibutuhkan permission_handler & reactive_ble
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.reyhan.bateraimotor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseStore != null) {
                storeFile = file(releaseStore)
                storePassword = keyValue("storePassword", "BM_KEYSTORE_PASSWORD")
                keyAlias = keyValue("keyAlias", "BM_KEY_ALIAS")
                keyPassword = keyValue("keyPassword", "BM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStore != null) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
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
