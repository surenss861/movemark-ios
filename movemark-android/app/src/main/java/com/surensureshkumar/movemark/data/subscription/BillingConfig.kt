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

    fun logStartup() {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "Billing mode: $billingMode")
        }
    }
}
