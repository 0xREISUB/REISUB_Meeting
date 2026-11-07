plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("REISUB_ANDROID_KEYSTORE")
val releaseStorePassword = System.getenv("REISUB_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("REISUB_ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("REISUB_ANDROID_KEY_PASSWORD")
val releaseSigningReady = listOf(
    releaseKeystorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) } && !releaseSigningReady) {
    throw GradleException("Android release signing requires REISUB_ANDROID_KEYSTORE, REISUB_ANDROID_STORE_PASSWORD, REISUB_ANDROID_KEY_ALIAS and REISUB_ANDROID_KEY_PASSWORD")
}

android {
    namespace = "xyz.reisub.meeting"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "xyz.reisub.meeting"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Host whose https invite links open in the app (App Links). Override
        // with -PreisubInviteHost=meeting.example.com for another server.
        manifestPlaceholders["inviteHost"] =
            (project.findProperty("reisubInviteHost") as String?) ?: "meeting.reisub.xyz"
    }

    signingConfigs {
        create("release") {
            if (releaseSigningReady) {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
