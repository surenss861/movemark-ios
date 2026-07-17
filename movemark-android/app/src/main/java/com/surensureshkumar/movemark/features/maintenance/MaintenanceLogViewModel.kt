package com.surensureshkumar.movemark.features.maintenance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.property.MaintenanceRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MaintenanceLogViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val maintenanceRepository: MaintenanceRepository,
    private val sessionManager: SessionManager,
) : ViewModel() {

    val maintenanceLog: StateFlow<List<MaintenanceRecord>> = propertyStore.maintenanceLog

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()

    fun addIncident(title: String, category: String, details: String) {
        val propertyId = propertyStore.activePropertyId.value
        val userId = sessionManager.userId.value
        if (propertyId == null || userId == null) {
            _errorMessage.value = "No active rental found."
            return
        }
        if (title.isBlank()) {
            _errorMessage.value = "Enter a title for this incident."
            return
        }
        viewModelScope.launch {
            _isSubmitting.value = true
            _errorMessage.value = null
            try {
                maintenanceRepository.insertIssue(
                    propertyId = propertyId,
                    userId = userId,
                    title = title.trim(),
                    category = category.trim().ifEmpty { "General" },
                    description = details.trim(),
                )
                propertyStore.refreshMaintenance(propertyId)
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Couldn't save incident. Try again."
            } finally {
                _isSubmitting.value = false
            }
        }
    }

    fun refresh() {
        val propertyId = propertyStore.activePropertyId.value ?: return
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                propertyStore.refreshMaintenance(propertyId)
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Couldn't load maintenance log."
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
