plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "dev.sogl.liquid_ai"
version = "1.0"

repositories {
    google()
    mavenCentral()
}

android {
    namespace = "dev.sogl.liquid_ai"
    compileSdk = 36

    defaultConfig {
        minSdk = 31
        targetSdk = 36
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation("ai.liquid.leap:leap-sdk:0.9.6")
    implementation("ai.liquid.leap:leap-gson:0.2.0")
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Test dependencies
    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.9")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    testImplementation("app.cash.turbine:turbine:1.0.0")
}
