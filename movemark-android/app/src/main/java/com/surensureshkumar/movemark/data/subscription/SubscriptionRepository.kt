package com.surensureshkumar.movemark.data.subscription

import android.app.Activity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * App-facing subscription API. Delegates to [RevenueCatSubscriptionBilling] or [MockSubscriptionBilling].
 */
@Singleton
class SubscriptionRepository @Inject constructor(
    private val revenueCat: RevenueCatSubscriptionBilling,
    private val mock: MockSubscriptionBilling,
) {
    companion object {
        const val PRO_ENTITLEMENT_ID = RevenueCatSubscriptionBilling.PRO_ENTITLEMENT_ID
    }

    private val impl: SubscriptionBilling =
        if (BillingConfig.isMockMode) mock else revenueCat

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    init {
        if (BillingConfig.isMockMode) {
            scope.launch { mock.initialize() }
        }
    }

    val isMockMode: Boolean get() = BillingConfig.isMockMode

    val hasPro: StateFlow<Boolean> get() = impl.hasPro
    val packages: StateFlow<List<PlanPackageUi>> get() = impl.packages
    val loading: StateFlow<Boolean> get() = impl.loading
    val purchasing: StateFlow<Boolean> get() = impl.purchasing
    val errorMessage: StateFlow<String?> get() = impl.errorMessage
    val restoreMessage: StateFlow<String?> get() = impl.restoreMessage

    suspend fun logIn(appUserId: String) = impl.logIn(appUserId)

    suspend fun logOut() = impl.logOut()

    suspend fun refreshCustomerInfo() = impl.refreshCustomerInfo()

    suspend fun fetchOfferings() = impl.fetchOfferings()

    suspend fun purchase(activity: Activity, plan: PlanPackageUi) = impl.purchase(activity, plan)

    suspend fun restorePurchases() = impl.restorePurchases()

    fun clearRestoreMessage() = impl.clearRestoreMessage()

    fun clearError() = impl.clearError()

    suspend fun resetMockSubscription() = impl.resetMockSubscription()
}
