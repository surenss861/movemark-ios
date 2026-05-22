package com.surensureshkumar.movemark.features.subscription

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
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
) : ViewModel() {
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
                _selectedPlan.value = repository.packages.value.firstOrNull()
            }
        }
    }

    fun selectPlan(plan: PlanPackageUi) {
        _selectedPlan.value = plan
    }

    fun purchase(activity: Activity, onSuccess: () -> Unit) {
        val plan = _selectedPlan.value ?: return
        viewModelScope.launch {
            when (repository.purchase(activity, plan)) {
                PurchaseOutcome.Success -> {
                    _purchaseSuccess.value = true
                    repository.refreshCustomerInfo()
                    onSuccess()
                }
                PurchaseOutcome.Cancelled -> Unit
                is PurchaseOutcome.Failed -> Unit
            }
        }
    }

    fun restore(onRestored: () -> Unit) {
        viewModelScope.launch {
            when (repository.restorePurchases()) {
                RestoreOutcome.Restored -> {
                    repository.refreshCustomerInfo()
                    onRestored()
                }
                RestoreOutcome.NoneFound, is RestoreOutcome.Failed -> Unit
            }
        }
    }

    fun clearMessages() {
        repository.clearError()
        repository.clearRestoreMessage()
    }

    fun resetPurchaseSuccess() {
        _purchaseSuccess.value = false
    }
}
