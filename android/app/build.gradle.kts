plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Build settings: environment variables, then .env (local, secret, ignored by
// git), then app.env (public defaults) in the repository root.
fun readEnvFile(file: File): Map<String, String> =
    if (!file.isFile) emptyMap() else file.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .associate { line ->
            val key = line.substringBefore("=").trim()
            val value = line.substringAfter("=").trim().removeSurrounding("\"").removeSurrounding("'")
            key to value
        }

val repositoryRoot = rootProject.projectDir.parentFile
val fileSettings = readEnvFile(repositoryRoot.resolve("app.env")) +
    readEnvFile(repositoryRoot.resolve(".env"))

fun setting(key: String): String? =
    System.getenv(key)?.takeIf { it.isNotBlank() } ?: fileSettings[key]?.takeIf { it.isNotBlank() }

val releaseKeystorePath = setting("REISUB_ANDROID_KEYSTORE")
val releaseStorePassword = setting("REISUB_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = setting("REISUB_ANDROID_KEY_ALIAS")
val releaseKeyPassword = setting("REISUB_ANDROID_KEY_PASSWORD")

// Host whose https invite links open in the app (Android App Links).
val inviteHost = (project.findProperty("reisubInviteHost") as String?)
    ?: setting("REISUB_INVITE_HOST")
    ?: throw GradleException("REISUB_INVITE_HOST is not set; see app.env")

// Meeting server that invite links on inviteHost stand for. The web host and
// the API host can differ while reaching the same server.
val inviteServer = setting("REISUB_SERVER_URL") ?: ""
val releaseSigningReady = listOf(
    releaseKeystorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) } && !releaseSigningReady) {
    throw GradleException("Android release signing requires REISUB_ANDROID_KEYSTORE, REISUB_ANDROID_STORE_PASSWORD, REISUB_ANDROID_KEY_ALIAS and REISUB_ANDROID_KEY_PASSWORD in the environment or in .env (see .env.example)")
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
        manifestPlaceholders["inviteHost"] = inviteHost
        manifestPlaceholders["inviteServer"] = inviteServer
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
