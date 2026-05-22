package com.surensureshkumar.movemark.features.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AccountViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val subscriptionRepository: SubscriptionRepository,
) : ViewModel() {
    companion object {
        const val PRIVACY_URL =
            "https://silver-peripheral-2ef.notion.site/MoveMark-Privacy-Policy-32f38275720980658acbe9aafa4e331b"
        const val TERMS_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    }

    val email: StateFlow<String?> = sessionManager.userEmail
    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro
    val restoreMessage: StateFlow<String?> = subscriptionRepository.restoreMessage
    val purchasing: StateFlow<Boolean> = subscriptionRepository.purchasing

    fun refreshSubscription() {
        viewModelScope.launch { subscriptionRepository.refreshCustomerInfo() }
    }

    fun restorePurchases() {
        viewModelScope.launch {
            subscriptionRepository.restorePurchases()
        }
    }

    fun signOut(onDone: () -> Unit) {
        viewModelScope.launch {
            sessionManager.signOut { propertyStore.clear() }
            onDone()
        }
    }
}
