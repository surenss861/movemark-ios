package com.surensureshkumar.movemark.features.maintenance

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.navigation.Routes
import android.content.Context
import android.net.Uri
import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceImport
import com.surensureshkumar.movemark.data.evidence.PendingEvidence
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
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

data class MaintenancePhotoUi(
    val id: UUID,
    val filePath: String,
    val thumbnailPath: String? = null,
    val signedUrl: String?,
) {
    /** Grid display prefers the thumbnail path (both for the fetch and for Coil's cache key). */
    val displayPath: String get() = thumbnailPath ?: filePath
}

@HiltViewModel
class MaintenanceIssueDetailViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    savedStateHandle: SavedStateHandle,
    private val propertyStore: PropertyStore,
    private val maintenanceRepository: MaintenanceRepository,
    private val inspectionRepository: InspectionRepository,
) : ViewModel() {

    private val issueId: UUID? = savedStateHandle.get<String>(Routes.MaintenanceIssueArg)
        ?.let { runCatching { UUID.fromString(it) }.getOrNull() }

    private val _issue = MutableStateFlow<MaintenanceRecord?>(null)
    val issue: StateFlow<MaintenanceRecord?> = _issue.asStateFlow()

    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _photos = MutableStateFlow<List<MaintenancePhotoUi>>(emptyList())
    val photos: StateFlow<List<MaintenancePhotoUi>> = _photos.asStateFlow()

    private val _isUploadingPhotos = MutableStateFlow(false)
    val isUploadingPhotos: StateFlow<Boolean> = _isUploadingPhotos.asStateFlow()

    init {
        loadIssue()
        viewModelScope.launch { loadPhotos() }
    }

    private fun loadIssue() {
        val id = issueId ?: return
        _issue.value = propertyStore.maintenanceLog.value.firstOrNull { it.id == id }
    }

    private suspend fun loadPhotos() {
        val id = issueId ?: return
        val files = runCatching { inspectionRepository.fetchEvidenceFilesByMaintenanceIssue(id) }.getOrNull().orEmpty()
        _photos.value = files.map { file ->
            // Prefer signing the thumbnail (grid display) over the full-size file; rows saved
            // before thumbnails existed have no thumbnail_path and fall back to the full-size path.
            val displayPath = file.thumbnailPath ?: file.filePath
            val signed = runCatching { inspectionRepository.signedUrl(displayPath) }.getOrNull()
            MaintenancePhotoUi(
                id = UUID.fromString(file.id),
                filePath = file.filePath,
                thumbnailPath = file.thumbnailPath,
                signedUrl = signed,
            )
        }
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

    /**
     * Saves each picked photo as maintenance evidence (untouched source + derivative + thumbnail through the
     * MoveMark API, then its `evidence_files` row). Photos are saved one by one; a failure never leaves a
     * duplicate row, and the ones that made it stay saved.
     */
    fun attachPhotos(uris: List<Uri>) {
        if (uris.isEmpty()) return
        val id = issueId ?: return
        val propertyId = propertyStore.activePropertyId.value ?: return

        viewModelScope.launch {
            _isUploadingPhotos.value = true
            _message.value = null
            val imported = withContext(Dispatchers.IO) {
                uris.map { runCatching { EvidenceImport.source(context, it, EvidenceCaptureSource.Library) } }
            }
            val pending = imported.mapNotNull { it.getOrNull() }.distinctBy { it.sha256Hex }.map { PendingEvidence(it) }
            if (pending.isEmpty()) {
                _message.value = imported.firstNotNullOfOrNull { it.exceptionOrNull()?.message }
                    ?: "Couldn't read that photo. Try another one."
                _isUploadingPhotos.value = false
                return@launch
            }
            val result = withContext(Dispatchers.IO) {
                inspectionRepository.maintenanceSaver(id, propertyId).save(pending)
            }
            if (!result.isComplete) {
                _message.value = if (result.saved.isEmpty()) {
                    "Couldn't upload photo. Try again."
                } else {
                    "${result.saved.size} of ${pending.size} photos saved. Try the rest again."
                }
            }
            loadPhotos()
            refreshFromStore()
            _isUploadingPhotos.value = false
        }
    }

    fun clearMessage() {
        _message.value = null
    }
}
