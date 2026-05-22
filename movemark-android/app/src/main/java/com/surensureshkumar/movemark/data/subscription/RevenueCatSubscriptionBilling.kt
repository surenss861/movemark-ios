package com.surensureshkumar.movemark.data.subscription

import android.app.Activity
import android.util.Log
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitLogOut
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.surensureshkumar.movemark.BuildConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RevenueCatSubscriptionBilling @Inject constructor() : SubscriptionBilling, UpdatedCustomerInfoListener {

    companion object {
        private const val TAG = "MoveMarkRC"
        const val PRO_ENTITLEMENT_ID = "movemark_pro1"
        private val MONTHLY_IDS = setOf("movemark_pro_monthly", "\$rc_monthly", "monthly")
        private val YEARLY_IDS = setOf("movemark_pro_yearly", "\$rc_annual", "yearly", "annual")
    }

    private val mutex = Mutex()

    private val _hasPro = MutableStateFlow(false)
    override val hasPro: StateFlow<Boolean> = _hasPro.asStateFlow()

    private val _packages = MutableStateFlow<List<PlanPackageUi>>(emptyList())
    override val packages: StateFlow<List<PlanPackageUi>> = _packages.asStateFlow()

    private val _loading = MutableStateFlow(false)
    override val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _purchasing = MutableStateFlow(false)
    override val purchasing: StateFlow<Boolean> = _purchasing.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    override val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _restoreMessage = MutableStateFlow<String?>(null)
    override val restoreMessage: StateFlow<String?> = _restoreMessage.asStateFlow()

    init {
        if (isConfigured) {
            Purchases.sharedInstance.updatedCustomerInfoListener = this
        }
    }

    val isConfigured: Boolean
        get() = BuildConfig.REVENUECAT_PUBLIC_KEY.isNotBlank() &&
            runCatching { Purchases.isConfigured }.getOrDefault(false)

    override fun onReceived(customerInfo: CustomerInfo) {
        applyCustomerInfo(customerInfo)
    }

    override suspend fun logIn(appUserId: String) {
        if (!isConfigured) return
        mutex.withLock {
            runCatching {
                val result = Purchases.sharedInstance.awaitLogIn(appUserId)
                applyCustomerInfo(result.customerInfo)
                Log.d(TAG, "logIn ok user=$appUserId hasPro=${_hasPro.value}")
            }.onFailure { e ->
                Log.e(TAG, "logIn failed", e)
            }
        }
    }

    override suspend fun logOut() {
        if (!isConfigured) {
            _hasPro.value = false
            return
        }
        mutex.withLock {
            runCatching {
                val info = Purchases.sharedInstance.awaitLogOut()
                applyCustomerInfo(info)
                _packages.value = emptyList()
                Log.d(TAG, "logOut ok")
            }.onFailure { e ->
                Log.e(TAG, "logOut failed", e)
                _hasPro.value = false
            }
        }
    }

    override suspend fun refreshCustomerInfo() {
        if (!isConfigured) return
        mutex.withLock {
            runCatching {
                applyCustomerInfo(Purchases.sharedInstance.awaitCustomerInfo())
            }.onFailure { e ->
                Log.e(TAG, "refreshCustomerInfo failed", e)
            }
        }
    }

    override suspend fun fetchOfferings() {
        if (!isConfigured) {
            _errorMessage.value = "Plans didn't load. Try again."
            return
        }
        _loading.value = true
        _errorMessage.value = null
        try {
            val offerings: Offerings = Purchases.sharedInstance.awaitOfferings()
            val current = offerings.current
            if (current == null || current.availablePackages.isEmpty()) {
                _packages.value = emptyList()
                _errorMessage.value = "Plans didn't load. Try again."
                return
            }
            _packages.value = mapPackages(current.availablePackages)
        } catch (e: Exception) {
            Log.e(TAG, "fetchOfferings failed", e)
            _packages.value = emptyList()
            _errorMessage.value = sanitizeError(e)
        } finally {
            _loading.value = false
        }
    }

    override suspend fun purchase(activity: Activity, plan: PlanPackageUi): PurchaseOutcome {
        val rcPackage = plan.revenueCatPackage
            ?: return PurchaseOutcome.Failed("Purchase couldn't complete. Try again.")
        if (!isConfigured) return PurchaseOutcome.Failed("Purchases aren't available right now.")
        _purchasing.value = true
        _errorMessage.value = null
        return try {
            val params = PurchaseParams.Builder(activity, rcPackage).build()
            val result = Purchases.sharedInstance.awaitPurchase(params)
            applyCustomerInfo(result.customerInfo)
            PurchaseOutcome.Success
        } catch (e: PurchasesTransactionException) {
            if (e.userCancelled) {
                PurchaseOutcome.Cancelled
            } else {
                Log.e(TAG, "purchase failed", e)
                val msg = "Purchase couldn't complete. Try again."
                _errorMessage.value = msg
                PurchaseOutcome.Failed(msg)
            }
        } catch (e: Exception) {
            Log.e(TAG, "purchase failed", e)
            val msg = sanitizeError(e)
            _errorMessage.value = msg
            PurchaseOutcome.Failed(msg)
        } finally {
            _purchasing.value = false
        }
    }

    override suspend fun restorePurchases(): RestoreOutcome {
        if (!isConfigured) return RestoreOutcome.Failed("Purchases couldn't be restored. Try again.")
        _purchasing.value = true
        _restoreMessage.value = null
        return try {
            val info = Purchases.sharedInstance.awaitRestore()
            applyCustomerInfo(info)
            if (_hasPro.value) {
                _restoreMessage.value = "MoveMark Pro restored."
                RestoreOutcome.Restored
            } else {
                _restoreMessage.value = "No active subscription found for this Google account."
                RestoreOutcome.NoneFound
            }
        } catch (e: Exception) {
            Log.e(TAG, "restore failed", e)
            val msg = "Purchases couldn't be restored. Try again."
            _restoreMessage.value = msg
            RestoreOutcome.Failed(msg)
        } finally {
            _purchasing.value = false
        }
    }

    override fun clearRestoreMessage() {
        _restoreMessage.value = null
    }

    override fun clearError() {
        _errorMessage.value = null
    }

    override suspend fun resetMockSubscription() = Unit

    private fun applyCustomerInfo(info: CustomerInfo?) {
        _hasPro.value = info?.entitlements?.get(PRO_ENTITLEMENT_ID)?.isActive == true
    }

    private fun mapPackages(packages: List<Package>): List<PlanPackageUi> {
        val monthly = packages.firstOrNull { pkg ->
            val id = pkg.product.id.lowercase()
            pkg.packageType.name.contains("MONTH", ignoreCase = true) ||
                MONTHLY_IDS.any { id.contains(it.removePrefix("$")) }
        }
        val yearly = packages.firstOrNull { pkg ->
            val id = pkg.product.id.lowercase()
            pkg.packageType.name.contains("ANNUAL", ignoreCase = true) ||
                pkg.packageType.name.contains("YEAR", ignoreCase = true) ||
                YEARLY_IDS.any { id.contains(it.removePrefix("$")) }
        }
        return listOfNotNull(
            monthly?.toUi(isYearly = false),
            yearly?.toUi(isYearly = true),
        )
    }

    private fun Package.toUi(isYearly: Boolean): PlanPackageUi {
        val product = product
        return PlanPackageUi(
            id = identifier,
            revenueCatPackage = this,
            title = if (isYearly) "MoveMark Pro Yearly" else "MoveMark Pro Monthly",
            periodLabel = if (isYearly) "Billed yearly" else "Billed monthly",
            price = product.price.formatted,
            isYearly = isYearly,
        )
    }

    private fun sanitizeError(error: Throwable): String {
        val raw = error.message.orEmpty()
        if (raw.isBlank() ||
            raw.contains("RevenueCat", ignoreCase = true) ||
            raw.contains("Billing", ignoreCase = true) ||
            raw.contains("Play", ignoreCase = true) ||
            raw.length > 120
        ) {
            return "Plans didn't load. Try again."
        }
        return raw
    }
}
