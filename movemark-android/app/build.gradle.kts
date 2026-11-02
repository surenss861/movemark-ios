import java.time.LocalDate
import java.time.format.DateTimeFormatter
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
// versionCode scheme YYYYMMDDNN (a real date plus a 01-99 sequence): sorts above the old single-digit codes and
// stays under Play's 2,100,000,000 ceiling through 2099.
val movemarkVersionName = (findProperty("movemarkVersionName") as String?)?.trim().orEmpty()
val movemarkVersionCode: Int = run {
    val raw = (findProperty("movemarkVersionCode") as String?)?.trim().orEmpty()
    val ok = Regex("""20\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(0[1-9]|[1-9]\d)""").matches(raw) &&
        runCatching { LocalDate.parse(raw.take(8), DateTimeFormatter.BASIC_ISO_DATE) }.isSuccess
    if (!ok) throw GradleException("movemarkVersionCode must be YYYYMMDDNN (a real date + 01-99), got '$raw'.")
    if (!Regex("""\d+\.\d+\.\d+""").matches(movemarkVersionName)) throw GradleException("movemarkVersionName must be x.y.z, got '$movemarkVersionName'.")
    raw.toInt()
}

val debugTargetsProduction = (findProperty("movemarkTarget") as String?)?.trim() == "production"

android {
    namespace = "com.surensureshkumar.movemark"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.surensureshkumar.movemark"
        minSdk = 26
        targetSdk = 36
        versionCode = movemarkVersionCode
        versionName = movemarkVersionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "REVENUECAT_PUBLIC_KEY", "\"$revenueCatKey\"")
        buildConfigField("String", "BILLING_MODE", "\"$billingModeProp\"")
        // Crash reporting (Sentry): empty DSN = disabled. Use the Android project's DSN, not the iOS one.
        buildConfigField("String", "SENTRY_DSN", "\"${localProp("SENTRY_DSN")}\"")
    }

    // Play upload key, read from local.properties (gitignored). Without it, release builds are left unsigned.
    val uploadStoreFile = localProp("MOVEMARK_UPLOAD_STORE_FILE")
    val uploadSigning = if (uploadStoreFile.isNotBlank() && file(uploadStoreFile).exists()) {
        signingConfigs.create("upload") {
            storeFile = file(uploadStoreFile)
            storePassword = localProp("MOVEMARK_UPLOAD_STORE_PASSWORD")
            keyAlias = localProp("MOVEMARK_UPLOAD_KEY_ALIAS")
            keyPassword = localProp("MOVEMARK_UPLOAD_KEY_PASSWORD")
        }
    } else null

    buildTypes {
        debug {
            // Debug talks to whatever local.properties names (the Neon dev branch and a dev API), unless the build
            // is run with -PmovemarkTarget=production: then it points at production (device QA with disposable
            // accounts), the Android equivalent of the iOS Debug production override.
            if (debugTargetsProduction) {
                buildConfigField("String", "NEON_AUTH_URL", "\"$prodNeonAuthUrl\"")
                buildConfigField("String", "NEON_DATA_API_URL", "\"$prodNeonDataApiUrl\"")
                buildConfigField("String", "MOVEMARK_API_BASE_URL", "\"$prodMoveMarkApiBaseUrl\"")
            } else {
                buildConfigField("String", "NEON_AUTH_URL", "\"${localProp("NEON_AUTH_URL")}\"")
                buildConfigField("String", "NEON_DATA_API_URL", "\"${localProp("NEON_DATA_API_URL")}\"")
                buildConfigField("String", "MOVEMARK_API_BASE_URL", "\"${localProp("MOVEMARK_API_BASE_URL")}\"")
            }
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
            signingConfig = uploadSigning
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
        // Robolectric + Compose UI tests run on the JVM (no device). Robolectric's SDK jars are fetched once
        // into the Gradle home on the data volume, not ~/.m2 on the startup disk.
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.systemProperty("maven.repo.local", "${gradle.gradleUserHomeDir}/robolectric-m2")
            it.maxHeapSize = "2g"
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

// Play release guard: a bundle without the upload key can't be uploaded, and one without a Google Play
// RevenueCat key ships a paywall that can't sell or restore. -PmovemarkAllowNoBilling=true lets an internal
// QA build through without the key (purchases then report "plans unavailable").
gradle.taskGraph.whenReady {
    val releasePackaging = allTasks.any { it.project == project && it.name in setOf("bundleRelease", "assembleRelease", "packageReleaseBundle") }
    if (!releasePackaging) return@whenReady
    val storeFile = localProp("MOVEMARK_UPLOAD_STORE_FILE")
    if (storeFile.isBlank() || !file(storeFile).exists()) {
        throw GradleException("Release builds need the Play upload key: set MOVEMARK_UPLOAD_STORE_FILE (and its passwords) in local.properties.")
    }
    val allowNoBilling = (findProperty("movemarkAllowNoBilling") as String?)?.trim() == "true"
    val keyProblem = when {
        revenueCatKey.isBlank() -> "REVENUECAT_PUBLIC_KEY is empty"
        revenueCatKey.startsWith("sk_") -> "REVENUECAT_PUBLIC_KEY is a secret key"
        !revenueCatKey.startsWith("goog_") -> "REVENUECAT_PUBLIC_KEY isn't a Google Play (goog_) key"
        else -> null
    }
    if (keyProblem != null) {
        if (allowNoBilling) logger.warn("WARNING: $keyProblem; building without working purchases (-PmovemarkAllowNoBilling).")
        else throw GradleException("$keyProblem. Add the RevenueCat Google Play public SDK key to local.properties, or pass -PmovemarkAllowNoBilling=true for a QA-only build.")
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
    implementation(libs.sentry.android)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    debugImplementation(libs.androidx.compose.ui.tooling.preview)
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.okhttp.mockwebserver)
    testImplementation(libs.robolectric)
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.test.junit4)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.ext.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.kotlinx.coroutines.test)
}
