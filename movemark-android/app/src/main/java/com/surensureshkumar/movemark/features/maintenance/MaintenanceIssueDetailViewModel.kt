package com.surensureshkumar.movemark.features.maintenance

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.navigation.Routes
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.property.MaintenanceRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class MaintenanceIssueDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val propertyStore: PropertyStore,
    private val maintenanceRepository: MaintenanceRepository,
) : ViewModel() {

    private val issueId: UUID? = savedStateHandle.get<String>(Routes.MaintenanceIssueArg)
        ?.let { runCatching { UUID.fromString(it) }.getOrNull() }

    private val _issue = MutableStateFlow<MaintenanceRecord?>(null)
    val issue: StateFlow<MaintenanceRecord?> = _issue.asStateFlow()

    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    init {
        loadIssue()
    }

    private fun loadIssue() {
        val id = issueId ?: return
        _issue.value = propertyStore.maintenanceLog.value.firstOrNull { it.id == id }
    }

    private suspend fun refreshFromStore() {
        val propertyId = propertyStore.activePropertyId.value ?: return
        propertyStore.refreshMaintenance(propertyId)
        val id = issueId ?: return
        _issue.value = propertyStore.maintenanceLog.value.firstOrNull { it.id == id }
    }

    fun saveFollowUp(note: String) {
        val id = issueId ?: return
        val trimmed = note.trim()
        if (trimmed.isEmpty()) {
            _message.value = "Enter a follow-up note."
            return
        }
        viewModelScope.launch {
            _isUpdating.value = true
            _message.value = null
            try {
                maintenanceRepository.updateFollowUp(id, trimmed)
                refreshFromStore()
                _message.value = "Follow-up saved."
            } catch (e: Exception) {
                _message.value = e.message ?: "Couldn't save follow-up. Try again."
            } finally {
                _isUpdating.value = false
            }
        }
    }

    fun markResolved() {
        val id = issueId ?: return
        viewModelScope.launch {
            _isUpdating.value = true
            _message.value = null
            try {
                maintenanceRepository.markResolved(id)
                refreshFromStore()
                _message.value = "Issue marked as resolved."
            } catch (e: Exception) {
                _message.value = e.message ?: "Couldn't update status. Try again."
            } finally {
                _isUpdating.value = false
            }
        }
    }

    fun clearMessage() {
        _message.value = null
    }
}
