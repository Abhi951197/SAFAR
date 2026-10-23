plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val safarSigningVariables = listOf("SAFAR_ANDROID_KEYSTORE_PATH", "SAFAR_ANDROID_STORE_PASSWORD", "SAFAR_ANDROID_KEY_ALIAS", "SAFAR_ANDROID_KEY_PASSWORD")
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } &&
    safarSigningVariables.any { System.getenv(it).isNullOrBlank() }) {
    throw GradleException("Configure persistent Safar release signing first. See backend/PERSONAL_BACKUPS.md. Never generate a new debug key for an app update.")
}

android {
    namespace = "com.abhishekpal.dailydiary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.abhishekpal.dailydiary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("safarRelease") {
            storeFile = System.getenv("SAFAR_ANDROID_KEYSTORE_PATH")?.let { file(it) }
            storePassword = System.getenv("SAFAR_ANDROID_STORE_PASSWORD")
            keyAlias = System.getenv("SAFAR_ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("SAFAR_ANDROID_KEY_PASSWORD")
            storeType = "PKCS12"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("safarRelease")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
