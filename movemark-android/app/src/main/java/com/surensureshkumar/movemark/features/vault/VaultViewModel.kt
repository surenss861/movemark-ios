package com.surensureshkumar.movemark.features.vault

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class VaultViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
    subscriptionRepository: SubscriptionRepository,
) : ViewModel() {
    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty
    val properties: StateFlow<List<PropertyRow>> = propertyStore.properties
    val loading: StateFlow<Boolean> = propertyStore.isLoading
    val error: StateFlow<String?> = propertyStore.errorMessage
    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro
    val propertyCount: StateFlow<Int> = propertyStore.properties
        .map { it.size }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)

    fun activateProperty(propertyId: UUID) {
        val userId = sessionManager.userId.value ?: return
        viewModelScope.launch {
            propertyStore.activateProperty(propertyId, userId)
        }
    }
}
