package com.surensureshkumar.movemark

import android.app.Application
import android.util.Log
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.surensureshkumar.movemark.data.subscription.BillingConfig
import com.surensureshkumar.movemark.data.subscription.RevenueCatSubscriptionBilling
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class MoveMarkApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BillingConfig.logStartup()
        val key = BuildConfig.REVENUECAT_PUBLIC_KEY
        if (BillingConfig.isRevenueCatMode && key.isNotBlank()) {
            if (BuildConfig.DEBUG) {
                Purchases.logLevel = LogLevel.DEBUG
            }
            Purchases.configure(PurchasesConfiguration.Builder(this, key).build())
            if (BuildConfig.DEBUG) {
                val prefix = key.take(6)
                Log.d(
                    TAG,
                    "RevenueCat configured build=debug keyPrefix=$prefix entitlement=${RevenueCatSubscriptionBilling.PRO_ENTITLEMENT_ID}",
                )
            }
        } else if (BuildConfig.DEBUG && BillingConfig.isRevenueCatMode) {
            Log.w(TAG, "RevenueCat skipped — set REVENUECAT_PUBLIC_KEY in local.properties")
        }
    }

    private companion object {
        const val TAG = "MoveMarkRC"
    }
}
