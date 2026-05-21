package com.surensureshkumar.movemark.features.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import com.surensureshkumar.movemark.data.remote.ExportJobStatus
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

sealed class ReportUiState {
    data object Loading : ReportUiState()
    data object NoVault : ReportUiState()
    data class Ready(
        val subtitle: String,
        val canExport: Boolean,
        val blockReason: String,
        val exporting: Boolean = false,
        val message: String? = null,
        val isError: Boolean = false,
    ) : ReportUiState()
}

@HiltViewModel
class ReportsViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val exportApi: ExportApiClient,
) : ViewModel() {
    private val _exporting = MutableStateFlow(false)
    private val _banner = MutableStateFlow<Pair<String, Boolean>?>(null)

    private val _uiState = MutableStateFlow<ReportUiState>(ReportUiState.Loading)
    val uiState: StateFlow<ReportUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            combine(propertyStore.currentProperty, propertyStore.isLoading, _exporting, _banner) {
                    property, loading, exporting, banner ->
                when {
                    loading && property == null -> ReportUiState.Loading
                    property == null -> ReportUiState.NoVault
                    else -> {
                        val documented = RoomProofMetrics.documentedCount(property)
                        val total = property.rooms.size
                        ReportUiState.Ready(
                            subtitle = "$documented of $total rooms ready",
                            canExport = documented > 0,
                            blockReason = "Document at least one room first",
                            exporting = exporting,
                            message = banner?.first,
                            isError = banner?.second == true,
                        )
                    }
                }
            }.collect { _uiState.value = it }
        }
    }

    fun requestExport() {
        val property = propertyStore.currentProperty.value ?: return
        viewModelScope.launch {
            _exporting.value = true
            _banner.value = null
            try {
                val token = sessionManager.accessToken() ?: error("Sign in required")
                val resp = withContext(Dispatchers.IO) {
                    exportApi.requestMoveInExport(token, property.id)
                }
                _banner.value = when (resp.status) {
                    ExportJobStatus.Failed -> "Report failed. Try again." to true
                    else -> "Report queued. Check back shortly." to false
                }
            } catch (e: Exception) {
                _banner.value = (e.message ?: "Export failed") to true
            } finally {
                _exporting.value = false
            }
        }
    }
}
