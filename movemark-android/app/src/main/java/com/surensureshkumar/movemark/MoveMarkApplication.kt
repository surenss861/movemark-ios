package com.surensureshkumar.movemark

import android.app.Application
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class MoveMarkApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val key = BuildConfig.REVENUECAT_PUBLIC_KEY
        if (key.isNotBlank()) {
            Purchases.configure(PurchasesConfiguration.Builder(this, key).build())
        }
    }
}
