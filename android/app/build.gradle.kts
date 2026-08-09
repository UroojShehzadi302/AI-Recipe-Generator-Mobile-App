import java.util.Properties

// Release signing credentials live outside version control. Absent on a fresh
// clone and in CI, which is why every use below is guarded by `.exists()`.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.urooj.cookmate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Registered in Firebase as com.urooj.cookmate with both the debug and
        // release SHA-1s. Changing this again means registering a new Android
        // app, re-adding both fingerprints, and re-downloading
        // google-services.json — Google Sign-In authenticates against the
        // package name + signing certificate pair.
        applicationId = "com.urooj.cookmate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing, loaded from android/key.properties (git-ignored).
    //
    // The debug keystore is shared by every Flutter install on the machine, so
    // anything signed with it can be replaced by anyone. Play Store upload
    // requires a real key. Until the owner generates one (see OWNER_SETUP.md),
    // key.properties is absent and the build falls back to debug signing so
    // `flutter run --release` keeps working locally.
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Local-only fallback. NOT publishable.
                signingConfigs.getByName("debug")
            }

            // Shrink + obfuscate. Without this the release APK unzips into
            // readable class names, which makes pulling the bundled Gemini key
            // and the Firebase config trivial.
            isMinifyEnabled = true
            isShrinkResources = true
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
