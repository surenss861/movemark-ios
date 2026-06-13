package com.surensureshkumar.movemark.features.vault

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class VaultViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
    private val inspectionRepository: InspectionRepository,
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

    private val _previewImageUrl = MutableStateFlow<String?>(null)
    val previewImageUrl: StateFlow<String?> = _previewImageUrl.asStateFlow()

    init {
        viewModelScope.launch {
            property.collect { record ->
                refreshPreviewUrl(record)
            }
        }
    }

    fun activateProperty(propertyId: UUID) {
        val userId = sessionManager.userId.value ?: return
        viewModelScope.launch {
            propertyStore.activateProperty(propertyId, userId)
        }
    }

    private suspend fun refreshPreviewUrl(property: PropertyRecord?) {
        _previewImageUrl.value = null
        if (property == null || RoomProofMetrics.documentedCount(property) <= 0) return
        val path = RoomProofMetrics.firstPreviewPhotoPath(property) ?: return
        runCatching {
            inspectionRepository.signedUrl(path)
        }.onSuccess { url ->
            _previewImageUrl.value = url
        }
    }
}
