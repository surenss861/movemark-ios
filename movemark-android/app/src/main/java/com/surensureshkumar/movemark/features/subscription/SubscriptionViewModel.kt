package com.surensureshkumar.movemark.features.subscription

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import com.surensureshkumar.movemark.data.subscription.ReportCreditsManager
import com.surensureshkumar.movemark.data.subscription.PurchaseOutcome
import com.surensureshkumar.movemark.data.subscription.RestoreOutcome
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SubscriptionViewModel @Inject constructor(
    private val repository: SubscriptionRepository,
    private val credits: ReportCreditsManager,
    private val sessionManager: SessionManager,
) : ViewModel() {
    /** A restore outcome decided here (Report Pack credits need the server balance), shown over the store's. */
    private val _restoreNote = MutableStateFlow<String?>(null)
    val restoreNote: StateFlow<String?> = _restoreNote.asStateFlow()

    /** The last successful purchase was a Report Pack ("Report Pack unlocked"). */
    private val _purchaseWasReportPack = MutableStateFlow(false)
    val purchaseWasReportPack: StateFlow<Boolean> = _purchaseWasReportPack.asStateFlow()

    val isMockMode: Boolean get() = repository.isMockMode
    val hasPro: StateFlow<Boolean> = repository.hasPro
    val packages: StateFlow<List<PlanPackageUi>> = repository.packages
    val loading: StateFlow<Boolean> = repository.loading
    val purchasing: StateFlow<Boolean> = repository.purchasing
    val errorMessage: StateFlow<String?> = repository.errorMessage
    val restoreMessage: StateFlow<String?> = repository.restoreMessage

    private val _selectedPlan = MutableStateFlow<PlanPackageUi?>(null)
    val selectedPlan: StateFlow<PlanPackageUi?> = _selectedPlan.asStateFlow()

    private val _purchaseSuccess = MutableStateFlow(false)
    val purchaseSuccess: StateFlow<Boolean> = _purchaseSuccess.asStateFlow()

    fun loadPlans() {
        viewModelScope.launch {
            repository.fetchOfferings()
            if (_selectedPlan.value == null) {
                _selectedPlan.value = repository.packages.value.firstOrNull { !it.isReportPack }
            }
            credits.refresh(sessionManager.userId.value)
        }
    }

    fun selectPlan(plan: PlanPackageUi) {
        _selectedPlan.value = plan
    }

    fun purchase(activity: Activity, onSuccess: () -> Unit) {
        val plan = _selectedPlan.value ?: return
        purchasePlan(activity, plan, onSuccess)
    }

    /** One report, no subscription (the paywall's Report Pack row). */
    fun purchaseReportPack(activity: Activity, pack: PlanPackageUi, onSuccess: () -> Unit) = purchasePlan(activity, pack, onSuccess)

    private fun purchasePlan(activity: Activity, plan: PlanPackageUi, onSuccess: () -> Unit) {
        viewModelScope.launch {
            when (repository.purchase(activity, plan)) {
                PurchaseOutcome.Success -> {
                    repository.refreshCustomerInfo()
                    credits.purchaseCompleted(sessionManager.userId.value)
                    _purchaseWasReportPack.value = plan.isReportPack
                    _purchaseSuccess.value = true
                    onSuccess()
                }
                PurchaseOutcome.Cancelled -> Unit
                is PurchaseOutcome.Failed -> Unit
            }
        }
    }

    /**
     * Pro, or a Report Pack credit that can still be spent (server balance when reachable), counts as restored;
     * an already-used pack does not (iOS `restorePurchases`).
     */
    fun restore(onRestored: () -> Unit) {
        viewModelScope.launch {
            _restoreNote.value = null
            when (repository.restorePurchases()) {
                RestoreOutcome.Restored -> {
                    repository.refreshCustomerInfo()
                    val userId = sessionManager.userId.value
                    credits.restored(userId)
                    when {
                        repository.hasPro.value -> onRestored()
                        credits.hasUsablePackCredit(userId) -> {
                            _restoreNote.value = "Report Pack restored."
                            onRestored()
                        }
                        else -> _restoreNote.value = repository.restoreFoundNothingMessage
                    }
                }
                RestoreOutcome.NoneFound, is RestoreOutcome.Failed -> Unit
            }
        }
    }

    fun clearMessages() {
        _restoreNote.value = null
        repository.clearError()
        repository.clearRestoreMessage()
    }

    fun resetPurchaseSuccess() {
        _purchaseSuccess.value = false
    }
}
