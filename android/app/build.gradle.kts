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
    namespace = "dev.frostflux.snipt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store application ID. The namespace and applicationId match
        // so the source tree, Manifest class references, and Play Store
        // listing all use the same identifier.
        applicationId = "dev.frostflux.snipt"
        // local_auth, flutter_secure_storage, foreground-service types and the
        // bubble/overlay APIs need a modern floor; pin instead of inheriting.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Only split release APKs per CPU architecture so each download is ~3x
    // smaller. Debug builds produce a single universal APK — Flutter's
    // tooling expects app-debug.apk, not architecture-suffixed files.
    // AABs handle splitting automatically via Play Store dynamic delivery.
    if (gradle.startParameter.taskNames.any {
            it.contains("assemble") && it.contains("Release")
        }) {
        // The Flutter Gradle Plugin injects ndk abiFilters for all target
        // platforms, which conflicts with splits. Clear them first.
        defaultConfig.ndk.abiFilters.clear()
        splits {
            abi {
                isEnable = true
                reset()
                include("armeabi-v7a", "arm64-v8a", "x86_64")
                isUniversalApk = true
            }
        }
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
