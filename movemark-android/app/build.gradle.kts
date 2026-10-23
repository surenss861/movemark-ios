import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun localProp(key: String, default: String = ""): String =
    (localProperties.getProperty(key) ?: default).trim()

val revenueCatKey = localProp("REVENUECAT_PUBLIC_KEY")
val debugBillingDefault = if (revenueCatKey.isBlank()) "mock" else "revenuecat"
val billingModeProp = localProp("BILLING_MODE", debugBillingDefault)

val prodNeonAuthUrl = "https://ep-steep-wind-b56266ss.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth"
val prodNeonDataApiUrl = "https://ep-steep-wind-b56266ss.apirest.c-7.us-east-2.aws.neon.tech/neondb/rest/v1"
val prodMoveMarkApiBaseUrl = "https://movemark-api-py-production.up.railway.app"

android {
    namespace = "com.surensureshkumar.movemark"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.surensureshkumar.movemark"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        buildConfigField("String", "REVENUECAT_PUBLIC_KEY", "\"$revenueCatKey\"")
        buildConfigField("String", "BILLING_MODE", "\"$billingModeProp\"")
    }

    buildTypes {
        debug {
            // Debug talks to whatever local.properties names (the Neon dev branch and a dev API).
            buildConfigField("String", "NEON_AUTH_URL", "\"${localProp("NEON_AUTH_URL")}\"")
            buildConfigField("String", "NEON_DATA_API_URL", "\"${localProp("NEON_DATA_API_URL")}\"")
            buildConfigField("String", "MOVEMARK_API_BASE_URL", "\"${localProp("MOVEMARK_API_BASE_URL")}\"")
        }
        release {
            // Release is hard-wired to production; local.properties can never redirect it.
            buildConfigField("String", "NEON_AUTH_URL", "\"$prodNeonAuthUrl\"")
            buildConfigField("String", "NEON_DATA_API_URL", "\"$prodNeonDataApiUrl\"")
            buildConfigField("String", "MOVEMARK_API_BASE_URL", "\"$prodMoveMarkApiBaseUrl\"")
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            buildConfigField("String", "BILLING_MODE", "\"revenuecat\"")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        // Repository/store code logs through android.util.Log; plain JVM tests get no-op stubs.
        unitTests.isReturnDefaultValues = true
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore)
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.coil.compose)
    implementation(libs.revenuecat)
    implementation(libs.okhttp)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    debugImplementation(libs.androidx.compose.ui.tooling.preview)
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.okhttp.mockwebserver)
}
