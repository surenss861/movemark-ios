package com.surensureshkumar.movemark.data.subscription

import android.util.Log
import com.surensureshkumar.movemark.BuildConfig

object BillingConfig {
    const val MODE_REVENUECAT = "revenuecat"
    const val MODE_MOCK = "mock"

    private const val TAG = "MoveMarkBilling"

    val billingMode: String = BuildConfig.BILLING_MODE

    val isMockMode: Boolean
        get() = billingMode == MODE_MOCK

    val isRevenueCatMode: Boolean
        get() = !isMockMode

    /**
     * What is wrong with a RevenueCat public SDK key for this Android app, or null when it is usable. Google Play
     * keys start with `goog_`; an App Store key (`appl_`) or a secret key (`sk_`) would configure the SDK and then
     * fail every purchase. The release build runs the same check before it will bundle (app/build.gradle.kts).
     */
    fun keyProblem(key: String): String? {
        val trimmed = key.trim()
        return when {
            trimmed.isEmpty() -> "REVENUECAT_PUBLIC_KEY is empty: purchases and restore are unavailable."
            trimmed.startsWith("sk_") -> "REVENUECAT_PUBLIC_KEY is a secret key; use the Google Play public SDK key (goog_…)."
            !trimmed.startsWith("goog_") -> "REVENUECAT_PUBLIC_KEY isn't a Google Play key (goog_…)."
            else -> null
        }
    }

    /** RevenueCat is configured only with a usable Google Play key; otherwise the paywall reports plans unavailable. */
    fun shouldConfigureRevenueCat(key: String): Boolean = isRevenueCatMode && keyProblem(key) == null

    /**
     * Play billing mode, but this build has no usable Google Play key: an internal-testing build made with
     * -PmovemarkAllowNoBilling=true before RevenueCat Android exists. The paywall says subscriptions are coming soon.
     */
    val subscriptionsComingSoon: Boolean
        get() = isRevenueCatMode && keyProblem(BuildConfig.REVENUECAT_PUBLIC_KEY) != null

    const val COMING_SOON = "Subscriptions are coming soon. Everything free in MoveMark works today."

    fun logStartup() {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "Billing mode: $billingMode")
        }
        if (isRevenueCatMode) keyProblem(BuildConfig.REVENUECAT_PUBLIC_KEY)?.let { Log.w(TAG, it) }
    }
}
