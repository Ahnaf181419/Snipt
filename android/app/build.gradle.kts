import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Reads keystore credentials from android/key.properties (gitignored).
// If the file is absent (e.g. CI without secrets), the release build falls
// back to debug signing so `flutter build apk` still works.
val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        load(FileInputStream(keystoreFile))
    }
}

android {
    namespace = "com.example.snipt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store application ID. The internal namespace stays
        // com.example.snipt for source/package alignment; only the
        // applicationId matters for store listing and device installs.
        applicationId = "com.snipt.app"
        // local_auth, flutter_secure_storage, foreground-service types and the
        // bubble/overlay APIs need a modern floor; pin instead of inheriting.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keystoreProperties["keyAlias"]?.let { keyAlias = it as String }
            keystoreProperties["keyPassword"]?.let { keyPassword = it as String }
            keystoreProperties["storeFile"]?.let { storeFile = file(it as String) }
            keystoreProperties["storePassword"]?.let { storePassword = it as String }
        }
    }

    buildTypes {
        release {
            // Uses the release keystore if android/key.properties exists;
            // otherwise falls back to debug signing (for dev/CI only).
            signingConfig = signingConfigs.getByName(
                if (keystoreProperties.containsKey("keyAlias")) "release" else "debug"
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
    // NotificationCompat / foreground-service helpers used by CaptureService.
    implementation("androidx.core:core-ktx:1.13.1")
}
