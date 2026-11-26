group = "xyz.reisub.calls"
version = "1.0"

plugins {
    id("com.android.library")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// AGP 9.3 deprecates the generated android { } accessor.
extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    namespace = "xyz.reisub.calls"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 26
    }
}
