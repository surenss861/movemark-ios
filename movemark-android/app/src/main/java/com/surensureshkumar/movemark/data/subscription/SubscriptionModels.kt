package com.surensureshkumar.movemark.data.subscription

import com.revenuecat.purchases.Package

data class PlanPackageUi(
    val id: String,
    val title: String,
    val periodLabel: String,
    val price: String,
    val isYearly: Boolean,
    /** A one-time Report Pack (one more move-in report), not a Pro plan. */
    val isReportPack: Boolean = false,
    /** Present only when [BillingConfig.isRevenueCatMode]. */
    val revenueCatPackage: Package? = null,
)

sealed class PurchaseOutcome {
    data object Success : PurchaseOutcome()
    data object Cancelled : PurchaseOutcome()
    data class Failed(val message: String) : PurchaseOutcome()
}

sealed class RestoreOutcome {
    data object Restored : RestoreOutcome()
    data object NoneFound : RestoreOutcome()
    data class Failed(val message: String) : RestoreOutcome()
}
