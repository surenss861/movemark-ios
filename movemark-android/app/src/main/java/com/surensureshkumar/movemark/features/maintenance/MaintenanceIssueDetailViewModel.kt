package com.surensureshkumar.movemark.features.maintenance

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.navigation.Routes
import com.surensureshkumar.movemark.core.util.thumbnailPathFor
import com.surensureshkumar.movemark.core.util.toThumbnailJpeg
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.MaintenanceRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
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
    savedStateHandle: SavedStateHandle,
    private val propertyStore: PropertyStore,
    private val maintenanceRepository: MaintenanceRepository,
    private val inspectionRepository: InspectionRepository,
    private val sessionManager: SessionManager,
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
            val signed = runCatching { maintenanceRepository.signedUrl(displayPath) }.getOrNull()
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

    /** Uploads each photo's bytes to maintenance-media, then links it via an evidence_files row. Stops at the first failure. */
    fun attachPhotos(photoBytes: List<ByteArray>) {
        if (photoBytes.isEmpty()) return
        val id = issueId ?: return
        val propertyId = propertyStore.activePropertyId.value ?: return
        val userId = sessionManager.userId.value ?: return

        viewModelScope.launch {
            _isUploadingPhotos.value = true
            _message.value = null
            for (bytes in photoBytes) {
                val path = "$userId/$propertyId/$id/${UUID.randomUUID()}.jpg"
                try {
                    maintenanceRepository.uploadAttachment(bytes, path)
                } catch (e: Exception) {
                    _message.value = e.message ?: "Couldn't upload photo. Try again."
                    _isUploadingPhotos.value = false
                    return@launch
                }
                // Thumbnail is a best-effort enhancement (grid loading only) -- a failure here
                // shouldn't fail the attachment, which is why it's not inside the try/catch above.
                val thumbPath = thumbnailPathFor(path)
                val thumbBytes = bytes.toThumbnailJpeg()
                val thumbUploaded = thumbBytes != null && runCatching {
                    maintenanceRepository.uploadAttachment(thumbBytes, thumbPath)
                }.isSuccess
                try {
                    inspectionRepository.insertMaintenanceEvidenceFile(
                        propertyId,
                        id,
                        path,
                        thumbnailPath = if (thumbUploaded) thumbPath else null,
                    )
                } catch (e: Exception) {
                    maintenanceRepository.removeOrphanAttachment(path)
                    if (thumbUploaded) maintenanceRepository.removeOrphanAttachment(thumbPath)
                    _message.value = e.message ?: "Photo uploaded but couldn't be saved. Try again."
                    _isUploadingPhotos.value = false
                    return@launch
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
