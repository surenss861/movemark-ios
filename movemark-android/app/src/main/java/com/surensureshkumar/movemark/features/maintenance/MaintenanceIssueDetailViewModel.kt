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
import com.surensureshkumar.movemark.data.models.EvidencePhoto
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
    /** `captured_at` / `created_at` as stored: the case file leads with the newest photo (iOS). */
    val capturedAt: String? = null,
    val createdAt: String? = null,
) {
    /** Grid display prefers the thumbnail path (both for the fetch and for Coil's cache key). */
    val displayPath: String get() = thumbnailPath ?: filePath

    val asEvidencePhoto: EvidencePhoto get() = EvidencePhoto(id, filePath, thumbnailPath)
}

/** Newest first (iOS `orderedPhotos`): by capture date, else record date; ties keep the later-loaded first. */
internal fun orderMaintenancePhotos(photos: List<MaintenancePhotoUi>): List<MaintenancePhotoUi> =
    photos.withIndex().sortedWith { a, b ->
        val da = MaintenanceCaseDate.parse(a.value.capturedAt)?.dateTime ?: MaintenanceCaseDate.parse(a.value.createdAt)?.dateTime
        val db = MaintenanceCaseDate.parse(b.value.capturedAt)?.dateTime ?: MaintenanceCaseDate.parse(b.value.createdAt)?.dateTime
        if (da != null && db != null && da != db) db.compareTo(da) else b.index.compareTo(a.index)
    }.map { it.value }

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

    /** The case: the log's record at first, then the full row (dates, report method) once it loads. */
    private val _issue = MutableStateFlow<MaintenanceCase?>(null)
    val issue: StateFlow<MaintenanceCase?> = _issue.asStateFlow()

    /** The first lookup finished (found or not), so "not found" isn't claimed while it runs. */
    private val _hasLoadedIssue = MutableStateFlow(false)
    val hasLoadedIssue: StateFlow<Boolean> = _hasLoadedIssue.asStateFlow()

    private val _issueLookupFailed = MutableStateFlow(false)
    /** The row couldn't be read (network/server) and nothing was shown: "The case file didn't load" + Try again. */
    val issueLookupFailed: StateFlow<Boolean> = _issueLookupFailed.asStateFlow()

    private val _isSavingFollowUp = MutableStateFlow(false)
    val isSavingFollowUp: StateFlow<Boolean> = _isSavingFollowUp.asStateFlow()

    private val _isResolving = MutableStateFlow(false)
    val isResolving: StateFlow<Boolean> = _isResolving.asStateFlow()

    /** Either flag: kept for callers that only need "something is saving". */
    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    /** An error notice (with Try again when [retryAvailable]); success is shown by the case itself. */
    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    /** A calm, non-error notice (photos that couldn't be read, previews still catching up). */
    private val _softNotice = MutableStateFlow<String?>(null)
    val softNotice: StateFlow<String?> = _softNotice.asStateFlow()

    private var retry: (() -> Unit)? = null
    private val _retryAvailable = MutableStateFlow(false)
    val retryAvailable: StateFlow<Boolean> = _retryAvailable.asStateFlow()

    private val _photos = MutableStateFlow<List<MaintenancePhotoUi>>(emptyList())
    val photos: StateFlow<List<MaintenancePhotoUi>> = _photos.asStateFlow()

    private val _hasLoadedPhotos = MutableStateFlow(false)
    val hasLoadedPhotos: StateFlow<Boolean> = _hasLoadedPhotos.asStateFlow()

    private val _photosLoadFailed = MutableStateFlow(false)
    val photosLoadFailed: StateFlow<Boolean> = _photosLoadFailed.asStateFlow()

    private val _isUploadingPhotos = MutableStateFlow(false)
    val isUploadingPhotos: StateFlow<Boolean> = _isUploadingPhotos.asStateFlow()

    init {
        loadIssue()
        viewModelScope.launch { loadPhotos() }
    }

    private fun loadIssue() {
        val id = issueId ?: run { _hasLoadedIssue.value = true; return }
        propertyStore.maintenanceLog.value.firstOrNull { it.id == id }?.let { _issue.value = MaintenanceCase.from(it) }
        viewModelScope.launch {
            reloadRow(id)
            _hasLoadedIssue.value = true
        }
    }

    /** iOS container "Try again": reads the case file again. */
    fun retryLoadIssue() {
        val id = issueId ?: return
        _issueLookupFailed.value = false
        _hasLoadedIssue.value = false
        viewModelScope.launch {
            reloadRow(id)
            _hasLoadedIssue.value = true
        }
    }

    /** Reads the full row; on failure keeps what is shown (the store's record) rather than blanking the case. */
    private suspend fun reloadRow(id: UUID) {
        val result = runCatching { maintenanceRepository.fetchIssue(id) }
        // A failed lookup (not "no such row") with nothing to show is recoverable, not "not found".
        _issueLookupFailed.value = result.isFailure && _issue.value == null
        val row = result.getOrNull() ?: return
        // Guard against a stale link to a different rental's case (iOS container view).
        val active = propertyStore.activePropertyId.value
        if (active != null && !row.propertyId.equals(active.toString(), ignoreCase = true)) return
        _issue.value = MaintenanceCase.from(row)
    }

    private suspend fun loadPhotos(): Boolean {
        val id = issueId ?: run { _hasLoadedPhotos.value = true; return false }
        val files = runCatching { inspectionRepository.fetchEvidenceFilesByMaintenanceIssue(id) }.getOrElse {
            _photosLoadFailed.value = true
            _hasLoadedPhotos.value = true
            return false
        }
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
                capturedAt = file.capturedAt,
                createdAt = file.createdAt,
            )
        }
        _photosLoadFailed.value = false
        _hasLoadedPhotos.value = true
        return true
    }

    /** Signs any stored path (the lead photo's full image, the viewer). */
    suspend fun signedPhotoUrl(path: String): String? = runCatching { inspectionRepository.signedUrl(path) }.getOrNull()

    private suspend fun refreshFromStore() {
        val propertyId = propertyStore.activePropertyId.value
        if (propertyId != null) propertyStore.refreshMaintenance(propertyId)
        val id = issueId ?: return
        val before = _issue.value
        reloadRow(id)
        if (_issue.value === before) {
            propertyStore.maintenanceLog.value.firstOrNull { it.id == id }?.let { record ->
                // The row read failed: take the store's status/response over what was shown.
                _issue.value = (before ?: MaintenanceCase.from(record)).copy(
                    status = record.status,
                    landlordResponse = record.landlordResponse,
                )
            }
        }
    }

    private fun fail(text: String, retryAction: (() -> Unit)?) {
        _message.value = text
        retry = retryAction
        _retryAvailable.value = retryAction != null
    }

    private fun clearNotices() {
        _message.value = null
        _softNotice.value = null
        retry = null
        _retryAvailable.value = false
    }

    fun retry() {
        retry?.invoke()
    }

    fun saveFollowUp(note: String, onSaved: () -> Unit = {}) {
        val id = issueId ?: return
        val trimmed = note.trim()
        if (trimmed.isEmpty() || _isSavingFollowUp.value) return
        viewModelScope.launch {
            _isSavingFollowUp.value = true
            _isUpdating.value = true
            clearNotices()
            try {
                maintenanceRepository.updateFollowUp(id, trimmed, _issue.value?.landlordResponse)
                onSaved()
                refreshFromStore()
            } catch (e: Exception) {
                fail("Couldn’t save follow-up. Try again.", retryAction = { saveFollowUp(trimmed, onSaved) })
            } finally {
                _isSavingFollowUp.value = false
                _isUpdating.value = _isResolving.value
            }
        }
    }

    fun markResolved() {
        val id = issueId ?: return
        if (_isResolving.value) return
        viewModelScope.launch {
            _isResolving.value = true
            _isUpdating.value = true
            clearNotices()
            try {
                maintenanceRepository.markResolved(id)
                _issue.value = _issue.value?.copy(status = "resolved", updatedAt = java.time.Instant.now().toString())
                refreshFromStore()
            } catch (e: Exception) {
                fail("Couldn’t update status. Try again.", retryAction = { markResolved() })
            } finally {
                _isResolving.value = false
                _isUpdating.value = _isSavingFollowUp.value
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
            clearNotices()
            val imported = withContext(Dispatchers.IO) {
                uris.map { runCatching { EvidenceImport.source(context, it, EvidenceCaptureSource.Library) } }
            }
            val pending = imported.mapNotNull { it.getOrNull() }.distinctBy { it.sha256Hex }.map { PendingEvidence(it) }
            if (pending.isEmpty()) {
                fail(
                    imported.firstNotNullOfOrNull { it.exceptionOrNull()?.message }
                        ?: "Couldn't read that photo. Try another one.",
                    null,
                )
                _isUploadingPhotos.value = false
                return@launch
            }
            val result = withContext(Dispatchers.IO) {
                inspectionRepository.maintenanceSaver(id, propertyId).save(pending)
            }
            if (!result.isComplete) {
                fail(
                    if (result.saved.isEmpty()) {
                        "Couldn't upload photo. Try again."
                    } else {
                        "${result.saved.size} of ${pending.size} photos saved. Try the rest again."
                    },
                    null,
                )
            }
            val reloaded = loadPhotos()
            val skipped = imported.count { it.isFailure }
            if (result.isComplete) {
                val notices = buildList {
                    if (skipped > 0) add(if (skipped == 1) "1 photo couldn't be read." else "$skipped photos couldn't be read.")
                    if (!reloaded) add("Photos are saved; previews may take a moment. Leave and return if images don’t appear.")
                }
                _softNotice.value = notices.takeIf { it.isNotEmpty() }?.joinToString(" ")
            }
            refreshFromStore()
            _isUploadingPhotos.value = false
        }
    }

    fun retryPhotos() {
        viewModelScope.launch {
            clearNotices()
            _hasLoadedPhotos.value = false
            loadPhotos()
        }
    }

    fun clearMessage() {
        clearNotices()
    }
}
