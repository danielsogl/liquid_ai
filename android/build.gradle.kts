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
    compileSdk = 34

    defaultConfig {
        minSdk = 31
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

dependencies {
    implementation("ai.liquid.leap:leap-sdk:0.9.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
