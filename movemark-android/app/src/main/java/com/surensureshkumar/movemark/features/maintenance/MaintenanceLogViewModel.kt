package com.surensureshkumar.movemark.features.maintenance

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceImport
import com.surensureshkumar.movemark.data.evidence.PendingEvidence
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.MaintenanceRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class MaintenanceLogViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val propertyStore: PropertyStore,
    private val maintenanceRepository: MaintenanceRepository,
    private val inspectionRepository: InspectionRepository,
    private val sessionManager: SessionManager,
) : ViewModel() {

    val maintenanceLog: StateFlow<List<MaintenanceRecord>> = propertyStore.maintenanceLog
    val currentProperty: StateFlow<PropertyRecord?> = propertyStore.currentProperty

    /** The last refresh failed (with nothing loaded the log says "Cases didn't load"; otherwise a calm notice). */
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    /** A calm notice after a save (partial photos, stale list). */
    private val _notice = MutableStateFlow<String?>(null)
    val notice: StateFlow<String?> = _notice.asStateFlow()

    /** An error inside the "Record an issue" sheet. */
    private val _sheetError = MutableStateFlow<String?>(null)
    val sheetError: StateFlow<String?> = _sheetError.asStateFlow()

    /** Bumped once per saved issue; the log closes the sheet when it changes. */
    private val _savedCount = MutableStateFlow(0)
    val savedCount: StateFlow<Int> = _savedCount.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()

    /** Newest photo per case, signed, for the row thumbnails (best effort; a failure leaves rows without photos). */
    private val _covers = MutableStateFlow<Map<UUID, MaintenanceThumb>>(emptyMap())
    val covers: StateFlow<Map<UUID, MaintenanceThumb>> = _covers.asStateFlow()

    /** Kept for the debug fixture gallery: a save without photos. */
    fun addIncident(title: String, category: String, details: String) =
        saveIssue(MaintenanceIssueDraft(title, category, details))

    /**
     * Creates the case (the same `insertIssue` call as before), then saves any picked photos through the
     * maintenance evidence pipeline the case file's "Add photos" uses, then refreshes the log.
     */
    fun saveIssue(draft: MaintenanceIssueDraft) {
        if (_isSubmitting.value) return
        val propertyId = propertyStore.activePropertyId.value
        val userId = sessionManager.userId.value
        if (propertyId == null || userId == null) {
            _sheetError.value = "No active rental found."
            return
        }
        if (draft.title.isBlank()) {
            _sheetError.value = "Enter an issue title."
            return
        }
        viewModelScope.launch {
            _isSubmitting.value = true
            _sheetError.value = null
            try {
                val inserted = maintenanceRepository.insertIssue(
                    propertyId = propertyId,
                    userId = userId,
                    title = draft.title.trim(),
                    category = MaintenanceCategory.fromStored(draft.category)?.raw ?: draft.category.trim().ifEmpty { MaintenanceCategory.Default.raw },
                    description = draft.details.trim(),
                )
                val partialPhotos = draft.photos.isNotEmpty() &&
                    !savePhotos(draft, UUID.fromString(inserted.id), propertyId)
                val refreshed = propertyStore.refreshMaintenance(propertyId)
                loadCovers(propertyId)
                _errorMessage.value = null
                _notice.value = when {
                    partialPhotos && !refreshed -> "$PARTIAL_PHOTOS If the list looks wrong, open Maintenance again."
                    partialPhotos -> PARTIAL_PHOTOS
                    !refreshed -> "Issue saved. If it doesn’t show below, go back and open Maintenance again."
                    else -> null
                }
                _savedCount.value += 1
            } catch (e: Exception) {
                _sheetError.value = "Couldn’t save this issue. Check your connection and try again."
            } finally {
                _isSubmitting.value = false
            }
        }
    }

    /** True when every picked photo was saved. */
    private suspend fun savePhotos(draft: MaintenanceIssueDraft, issueId: UUID, propertyId: UUID): Boolean {
        val imported = withContext(Dispatchers.IO) {
            draft.photos.map { runCatching { EvidenceImport.source(context, it, EvidenceCaptureSource.Library) } }
        }
        val pending = imported.mapNotNull { it.getOrNull() }.distinctBy { it.sha256Hex }.map { PendingEvidence(it) }
        if (pending.isEmpty()) return false
        val result = runCatching {
            withContext(Dispatchers.IO) { inspectionRepository.maintenanceSaver(issueId, propertyId).save(pending) }
        }.getOrNull() ?: return false
        return result.isComplete && pending.size == draft.photos.size
    }

    fun refresh() {
        val propertyId = propertyStore.activePropertyId.value ?: return
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                val ok = propertyStore.refreshMaintenance(propertyId)
                loadCovers(propertyId)
                if (!ok) _errorMessage.value = LIST_SYNC_FAILED
            } catch (e: Exception) {
                _errorMessage.value = LIST_SYNC_FAILED
            } finally {
                _isLoading.value = false
            }
        }
    }

    private suspend fun loadCovers(propertyId: UUID) {
        val found = runCatching { maintenanceRepository.fetchCoverPhotos(propertyId) }.getOrNull() ?: return
        _covers.value = found.mapNotNull { (issueId, photo) ->
            val path = photo.thumbnailPath ?: photo.filePath
            val url = runCatching { inspectionRepository.signedUrl(path) }.getOrNull() ?: return@mapNotNull null
            issueId to MaintenanceThumb(url, path)
        }.toMap()
    }

    fun clearError() {
        _errorMessage.value = null
    }

    fun clearSheetError() {
        _sheetError.value = null
    }

    companion object {
        const val LIST_SYNC_FAILED = "Couldn’t refresh the maintenance log just now. Your recorded cases are still here."
        const val PARTIAL_PHOTOS =
            "Issue saved. Some photos didn’t upload or attach—only the photos that succeeded are on this issue. You can add more from the issue detail."
    }
}
