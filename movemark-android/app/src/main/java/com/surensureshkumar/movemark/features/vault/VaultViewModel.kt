package com.surensureshkumar.movemark.features.vault

import androidx.lifecycle.ViewModel
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import javax.inject.Inject

@HiltViewModel
class VaultViewModel @Inject constructor(
    propertyStore: PropertyStore,
    subscriptionRepository: SubscriptionRepository,
) : ViewModel() {
    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty
    val loading: StateFlow<Boolean> = propertyStore.isLoading
    val error: StateFlow<String?> = propertyStore.errorMessage
    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro
    val propertyCount: StateFlow<Int> = propertyStore.properties
        .map { it.size }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)
}
