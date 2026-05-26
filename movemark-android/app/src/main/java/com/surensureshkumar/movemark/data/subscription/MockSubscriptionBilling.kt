package com.surensureshkumar.movemark.data.subscription

import android.app.Activity
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MockSubscriptionBilling @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : SubscriptionBilling {

    companion object {
        private val MOCK_PRO_KEY = booleanPreferencesKey("mock_pro_active")
        const val MOCK_MONTHLY_ID = "mock_monthly"
        const val MOCK_YEARLY_ID = "mock_yearly"
    }

    private val mutex = Mutex()

    private val _hasPro = MutableStateFlow(false)
    override val hasPro: StateFlow<Boolean> = _hasPro.asStateFlow()

    private val _packages = MutableStateFlow(mockPackages())
    override val packages: StateFlow<List<PlanPackageUi>> = _packages.asStateFlow()

    private val _loading = MutableStateFlow(false)
    override val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _purchasing = MutableStateFlow(false)
    override val purchasing: StateFlow<Boolean> = _purchasing.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    override val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _restoreMessage = MutableStateFlow<String?>(null)
    override val restoreMessage: StateFlow<String?> = _restoreMessage.asStateFlow()

    suspend fun initialize() {
        _hasPro.value = readMockPro()
    }

    override suspend fun logIn(appUserId: String) {
        _hasPro.value = readMockPro()
    }

    override suspend fun logOut() {
        mutex.withLock {
            dataStore.edit { it.remove(MOCK_PRO_KEY) }
            _hasPro.value = false
            _packages.value = mockPackages()
            _restoreMessage.value = null
            _errorMessage.value = null
        }
    }

    override suspend fun refreshCustomerInfo() {
        _hasPro.value = readMockPro()
    }

    override suspend fun fetchOfferings() {
        _loading.value = true
        _errorMessage.value = null
        delay(200)
        _packages.value = mockPackages()
        _loading.value = false
    }

    override suspend fun purchase(activity: Activity, plan: PlanPackageUi): PurchaseOutcome {
        _purchasing.value = true
        _errorMessage.value = null
        return try {
            delay(700)
            setMockPro(true)
            _restoreMessage.value = "Pro unlocked for testing."
            PurchaseOutcome.Success
        } catch (e: Exception) {
            Log.e("MoveMarkBilling", "mock purchase failed", e)
            val msg = "Purchase couldn't complete. Try again."
            _errorMessage.value = msg
            PurchaseOutcome.Failed(msg)
        } finally {
            _purchasing.value = false
        }
    }

    override suspend fun restorePurchases(): RestoreOutcome {
        _purchasing.value = true
        _restoreMessage.value = null
        return try {
            delay(400)
            if (_hasPro.value) {
                _restoreMessage.value = "MoveMark Pro restored for testing."
                RestoreOutcome.Restored
            } else {
                _restoreMessage.value = "No active test subscription found."
                RestoreOutcome.NoneFound
            }
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

    override suspend fun resetMockSubscription() {
        mutex.withLock {
            setMockPro(false)
            _restoreMessage.value = null
            _errorMessage.value = null
        }
    }

    private suspend fun readMockPro(): Boolean =
        dataStore.data.map { prefs -> prefs[MOCK_PRO_KEY] == true }.first()

    private suspend fun setMockPro(active: Boolean) {
        dataStore.edit { it[MOCK_PRO_KEY] = active }
        _hasPro.value = active
    }

    private fun mockPackages(): List<PlanPackageUi> = listOf(
        PlanPackageUi(
            id = MOCK_MONTHLY_ID,
            title = "MoveMark Pro Monthly",
            periodLabel = "Billed monthly",
            price = "$9.99 / month",
            isYearly = false,
        ),
        PlanPackageUi(
            id = MOCK_YEARLY_ID,
            title = "MoveMark Pro Yearly",
            periodLabel = "Billed yearly",
            price = "$79.99 / year",
            isYearly = true,
        ),
    )
}
