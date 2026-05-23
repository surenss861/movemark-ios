package com.surensureshkumar.movemark.data.subscription

import android.app.Activity
import kotlinx.coroutines.flow.StateFlow

interface SubscriptionBilling {
    val hasPro: StateFlow<Boolean>
    val packages: StateFlow<List<PlanPackageUi>>
    val loading: StateFlow<Boolean>
    val purchasing: StateFlow<Boolean>
    val errorMessage: StateFlow<String?>
    val restoreMessage: StateFlow<String?>

    suspend fun logIn(appUserId: String)
    suspend fun logOut()
    suspend fun refreshCustomerInfo()
    suspend fun fetchOfferings()
    suspend fun purchase(activity: Activity, plan: PlanPackageUi): PurchaseOutcome
    suspend fun restorePurchases(): RestoreOutcome
    fun clearRestoreMessage()
    fun clearError()
    suspend fun resetMockSubscription()
}
