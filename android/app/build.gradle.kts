import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Reads android/key.properties (gitignored); see
// project_docs/diegema/ANDROID_RELEASE.md. Without it, bundleRelease fails
// (a store bundle must never be debug-signed). assembleRelease / flutter run
// --release fall back to the debug key only when explicitly allowed:
//   -PallowDebugReleaseSigning=true  or  env ALLOW_DEBUG_RELEASE_SIGNING=true
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keyProps.getProperty("storeFile") != null
val allowDebugRelease =
    project.findProperty("allowDebugReleaseSigning") == "true" ||
        System.getenv("ALLOW_DEBUG_RELEASE_SIGNING") == "true"

android {
    namespace = "com.overengineeredhobbies.diegema"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.overengineeredhobbies.diegema"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
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

// No release key and no explicit opt-in: refuse to produce a store bundle.
gradle.taskGraph.whenReady {
    val bundling = allTasks.any { it.path == ":app:bundleRelease" }
    if (bundling && !hasReleaseKey) {
        throw GradleException(
            "bundleRelease needs android/key.properties (upload keystore). " +
                "See project_docs/diegema/ANDROID_RELEASE.md. Refusing to debug-sign a store bundle.",
        )
    }
    val assembling = allTasks.any { it.path == ":app:assembleRelease" }
    if (assembling && !hasReleaseKey && !allowDebugRelease) {
        throw GradleException(
            "No android/key.properties: release APK would be debug-signed. " +
                "Pass -PallowDebugReleaseSigning=true or set ALLOW_DEBUG_RELEASE_SIGNING=true to allow (local/CI only).",
        )
    }
}

flutter {
    source = "../.."
}
