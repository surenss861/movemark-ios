package com.surensureshkumar.movemark.features.proof

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceImport
import com.surensureshkumar.movemark.data.evidence.EvidenceSaveOutcome
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import com.surensureshkumar.movemark.data.evidence.PendingEvidence
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.property.EvidenceUploadContext
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.core.navigation.Routes
import com.surensureshkumar.movemark.features.proof.camera.CameraCaptureResultHolder
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject

private const val UPLOAD_TAG = "MoveMarkUpload"

@HiltViewModel
class RoomProofViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val receiptCache: SavedProofReceiptCache,
    private val cameraResultHolder: CameraCaptureResultHolder,
    private val inspectionRepository: InspectionRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    /** Signed URL for a saved evidence photo (the Room hero plate); null if signing fails. */
    suspend fun signedPhotoUrl(path: String): String? =
        runCatching { inspectionRepository.signedUrl(path) }.getOrNull()

    val roomId: UUID? = runCatching {
        UUID.fromString(checkNotNull(savedStateHandle.get<String>(Routes.RoomProofArg)))
    }.getOrNull()
    val proofPhase: ProofPhase = ProofPhase.fromKey(savedStateHandle.get<String>(Routes.ProofPhaseArg))

    val room: StateFlow<RoomRecord?> = propertyStore.currentProperty
        .map { prop -> prop?.rooms?.firstOrNull { it.id == roomId } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    private val _photos = MutableStateFlow<List<PendingPhoto>>(emptyList())
    val photos: StateFlow<List<PendingPhoto>> = _photos.asStateFlow()

    val photoCount: StateFlow<Int> = _photos
        .map { list -> list.count { it.status != PhotoUploadStatus.Uploaded } }
        .stateIn(viewModelScope, SharingStarted.Eagerly, 0)

    private val _saveState = MutableStateFlow<RoomProofSaveState>(RoomProofSaveState.Idle)
    val saveState: StateFlow<RoomProofSaveState> = _saveState.asStateFlow()

    val saveButtonLabel: StateFlow<String> = _saveState
        .map { it.saveButtonLabel() }
        .stateIn(viewModelScope, SharingStarted.Eagerly, "Save proof")

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _proofSaved = MutableSharedFlow<SavedProofReceiptPayload>(extraBufferCapacity = 1)
    val proofSaved: SharedFlow<SavedProofReceiptPayload> = _proofSaved.asSharedFlow()

    /** Details for the next saved entry (title, notes, condition, issue tags). */
    private val _draft = MutableStateFlow(EntryDraft())
    val draft: StateFlow<EntryDraft> = _draft.asStateFlow()

    /** Edit / add photos / delete on a saved entry. */
    private val _entryBusy = MutableStateFlow(false)
    val entryBusy: StateFlow<Boolean> = _entryBusy.asStateFlow()

    /** One-shot result of an entry action, shown as a snackbar. */
    private val _entryNotice = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val entryNotice: SharedFlow<String> = _entryNotice.asSharedFlow()

    private val _loadingOlder = MutableStateFlow(false)
    val loadingOlder: StateFlow<Boolean> = _loadingOlder.asStateFlow()

    private var uploadContext: EvidenceUploadContext? = null
    private var pendingReceipt: SavedProofReceiptPayload? = null

    init {
        if (roomId == null) {
            _message.value = "Invalid room. Please go back and try again."
        }
    }

    fun consumeCameraCaptures() {
        val id = roomId ?: return
        viewModelScope.launch {
            cameraResultHolder.consume(id)?.let { addUris(it) }
        }
    }

    fun addUris(uris: List<Uri>) {
        if (_saveState.value.isBusy) return
        viewModelScope.launch {
            val imported = withContext(Dispatchers.IO) { importSources(uris) }
            val sources = imported.mapNotNull { it.getOrNull() }
            if (sources.isEmpty() && uris.isNotEmpty()) {
                _message.value = importFailureMessage(imported)
                return@launch
            }
            // The same file picked twice is one photo (its source hash is its identity).
            val existing = _photos.value.mapNotNull { it.evidence?.source?.sha256Hex }.toSet()
            val newPhotos = withContext(Dispatchers.Default) {
                sources
                    .distinctBy { it.sha256Hex }
                    .filter { it.sha256Hex !in existing }
                    .mapNotNull { source ->
                        val preview = EvidenceImport.thumbnail(source) ?: return@mapNotNull null
                        PendingPhoto(bytes = preview, evidence = PendingEvidence(source))
                    }
            }
            if (newPhotos.isNotEmpty()) {
                _photos.value = _photos.value + newPhotos
                _saveState.value = RoomProofSaveState.Idle
                _message.value = if (sources.size < uris.size) importFailureMessage(imported) else null
            }
        }
    }

    /** The picked/captured files' bytes, untouched, as evidence sources (one result per uri). */
    private fun importSources(uris: List<Uri>): List<Result<EvidenceSource>> = uris.map { uri ->
        runCatching { EvidenceImport.source(context, uri, captureSourceOf(uri)) }
    }

    private fun importFailureMessage(results: List<Result<EvidenceSource>>): String =
        results.firstNotNullOfOrNull { it.exceptionOrNull()?.message }
            ?: "Could not read selected photos. Try different images."

    fun save() {
        if (_saveState.value.isBusy) return
        val userId = sessionManager.userId.value ?: run {
            _message.value = "Sign in required."
            return
        }
        val property = propertyStore.currentProperty.value ?: run {
            _message.value = "No active rental."
            return
        }
        val room = room.value ?: run {
            _message.value = "Room not found."
            return
        }
        val toUpload = _photos.value.filter {
            it.status == PhotoUploadStatus.Pending || it.status == PhotoUploadStatus.Failed
        }
        if (toUpload.isEmpty()) {
            _message.value = "Add at least one photo before saving."
            return
        }

        viewModelScope.launch {
            _saveState.value = RoomProofSaveState.Preparing
            _message.value = null
            pendingReceipt = null
            try {
                val uploadCtx = uploadContext ?: withContext(Dispatchers.IO) {
                    val d = _draft.value
                    propertyStore.createEvidenceUploadContext(
                        roomId = room.id,
                        title = d.title.trim().ifEmpty { room.name },
                        notes = d.notes.trim(),
                        propertyId = property.id,
                        userId = userId,
                        proofPhase = proofPhase,
                        conditionRating = d.conditionRating,
                        issueTags = d.tags.toList(),
                    )
                }.also { uploadContext = it }

                var uploadedThisRun = 0
                var lastFailure: Throwable? = null
                val batchSize = toUpload.size

                toUpload.forEachIndexed { index, photo ->
                    _saveState.value = RoomProofSaveState.Uploading(index + 1, batchSize)
                    setPhotoStatus(photo.id, PhotoUploadStatus.Uploading)
                    val evidence = photo.evidence ?: return@forEachIndexed setPhotoStatus(photo.id, PhotoUploadStatus.Failed)
                    when (val outcome = withContext(Dispatchers.IO) { propertyStore.saveEvidencePhoto(uploadCtx, evidence) }) {
                        is EvidenceSaveOutcome.Saved -> {
                            setPhotoStatus(photo.id, PhotoUploadStatus.Uploaded)
                            uploadedThisRun++
                        }
                        is EvidenceSaveOutcome.Pending -> {
                            // Keep the row id and any unresolved upload: the retry settles it before re-sending.
                            updatePhoto(photo.id) { it.copy(status = PhotoUploadStatus.Failed, evidence = outcome.item) }
                            lastFailure = outcome.error ?: lastFailure
                        }
                    }
                }

                val totalUploaded = _photos.value.count { it.status == PhotoUploadStatus.Uploaded }
                val failedCount = _photos.value.count { it.status == PhotoUploadStatus.Failed }

                when {
                    uploadedThisRun > 0 -> {
                        withContext(Dispatchers.IO) {
                            propertyStore.commitEvidenceUpload(
                                context = uploadCtx,
                                uploadedCount = uploadedThisRun,
                                attemptedCount = batchSize,
                            )
                        }
                    }
                    totalUploaded == 0 -> {
                        withContext(Dispatchers.IO) {
                            uploadContext?.let { propertyStore.abandonEvidenceUpload(it) }
                        }
                        uploadContext = null
                        val failure = RoomProofUploadMessages.failure(lastFailure)
                        _saveState.value = RoomProofSaveState.Failed(failure)
                        _message.value = failure
                        return@launch
                    }
                }

                when {
                    failedCount > 0 -> {
                        val attempted = _photos.value.size
                        pendingReceipt = buildReceiptPayload(
                            room = room,
                            propertyId = property.id,
                            savedCount = totalUploaded,
                            attemptedCount = attempted,
                            issueCount = uploadCtx.issueTags.toSet().size,
                        )
                        _saveState.value = RoomProofSaveState.PartialSuccess(totalUploaded, failedCount)
                        _message.value = RoomProofUploadMessages.partial(totalUploaded, attempted)
                    }
                    else -> {
                        val attempted = _photos.value.size
                        val payload = buildReceiptPayload(
                            room = room,
                            propertyId = property.id,
                            savedCount = totalUploaded,
                            attemptedCount = attempted,
                            issueCount = uploadCtx.issueTags.toSet().size,
                        )
                        receiptCache.put(payload)
                        _photos.value = emptyList()
                        _draft.value = EntryDraft()
                        uploadContext = null
                        _saveState.value = RoomProofSaveState.Success(totalUploaded)
                        _message.value = null
                        _proofSaved.tryEmit(payload)
                    }
                }
            } catch (e: Exception) {
                Log.e(UPLOAD_TAG, "Save proof failed", e)
                val friendly = MMUserMessages.proofSave(e)
                _saveState.value = RoomProofSaveState.Failed(friendly)
                _message.value = friendly
            } finally {
                if (_saveState.value is RoomProofSaveState.Preparing ||
                    _saveState.value is RoomProofSaveState.Uploading
                ) {
                    _saveState.value = RoomProofSaveState.Idle
                }
            }
        }
    }

    fun retryFailedUploads() {
        if (_saveState.value.isBusy) return
        val hasFailed = _photos.value.any { it.status == PhotoUploadStatus.Failed }
        if (!hasFailed) return
        save()
    }

    fun continueWithSavedProof() {
        val payload = pendingReceipt ?: return
        receiptCache.put(payload)
        _photos.value = emptyList()
        uploadContext = null
        pendingReceipt = null
        _saveState.value = RoomProofSaveState.Idle
        _message.value = null
        _proofSaved.tryEmit(payload)
    }

    fun isUploadInProgress(): Boolean = _saveState.value.isBusy || _entryBusy.value

    fun updateDraft(transform: (EntryDraft) -> EntryDraft) {
        _draft.value = transform(_draft.value)
    }

    /** Edit a saved entry's details (iOS `saveEditedEvidence`). Returns false on failure. */
    fun updateEntry(entryId: UUID, edit: EntryDraft, onDone: (Boolean) -> Unit) {
        val userId = sessionManager.userId.value ?: return onDone(false)
        val fallbackTitle = room.value?.name ?: "Room"
        runEntryAction(success = "Entry updated", failure = "Couldn't update this entry. Try again.", onDone = onDone) {
            propertyStore.updateEvidence(
                entryId = entryId,
                title = edit.title.trim().ifEmpty { fallbackTitle },
                notes = edit.notes.trim(),
                issueTags = edit.tags.toList(),
                conditionRating = edit.conditionRating,
                userId = userId,
            )
        }
    }

    /** Delete a saved entry with its photos and tags (iOS `deleteEntry`). */
    fun deleteEntry(entryId: UUID) {
        val userId = sessionManager.userId.value ?: return
        runEntryAction(success = "Entry deleted", failure = "Couldn't delete this entry. Try again.") {
            propertyStore.deleteEvidence(entryId, userId)
        }
    }

    /** Add photos to an existing entry (iOS `appendPhotos`). */
    fun appendPhotos(entryId: UUID, uris: List<Uri>) {
        val userId = sessionManager.userId.value ?: return
        val property = propertyStore.currentProperty.value ?: return
        val roomId = roomId ?: return
        if (uris.isEmpty()) return
        runEntryAction(success = null, failure = RoomProofUploadMessages.FULL_FAILURE) {
            val sources = withContext(Dispatchers.IO) { importSources(uris) }.mapNotNull { it.getOrNull() }
            if (sources.isEmpty()) throw IllegalStateException("Could not read selected photos.")
            val pending = sources.distinctBy { it.sha256Hex }.map { PendingEvidence(it) }
            val result = withContext(Dispatchers.IO) {
                propertyStore.appendPhotosToEvidence(entryId, roomId, proofPhase, pending, property.id, userId)
            }
            _entryNotice.tryEmit(
                if (result.hadPartialFailure) RoomProofUploadMessages.partial(result.savedCount, result.attemptedCount)
                else if (result.savedCount == 1) "1 photo added" else "${result.savedCount} photos added",
            )
            result.hydrationRefreshed
        }
    }

    private fun runEntryAction(
        success: String?,
        failure: String,
        onDone: (Boolean) -> Unit = {},
        block: suspend () -> Boolean,
    ) {
        if (_entryBusy.value || _saveState.value.isBusy) return
        viewModelScope.launch {
            _entryBusy.value = true
            val ok = try {
                block()
                true
            } catch (e: Exception) {
                Log.e(UPLOAD_TAG, "Entry action failed", e)
                false
            } finally {
                _entryBusy.value = false
            }
            if (ok) success?.let { _entryNotice.tryEmit(it) } else _entryNotice.tryEmit(failure)
            onDone(ok)
        }
    }

    /** Load the next page of this room's older entries (iOS "Show older entries"). */
    fun loadOlderEntries() {
        val id = roomId ?: return
        if (_loadingOlder.value) return
        viewModelScope.launch {
            _loadingOlder.value = true
            try {
                propertyStore.loadOlderEntries(id, proofPhase)
            } catch (e: Exception) {
                Log.e(UPLOAD_TAG, "loadOlderEntries failed", e)
                _entryNotice.tryEmit("Couldn't load older entries. Try again.")
            } finally {
                _loadingOlder.value = false
            }
        }
    }

    /** Load every photo of an entry (iOS "Show all N photos"). */
    fun loadAllPhotos(entryId: UUID) {
        val id = roomId ?: return
        runEntryAction(success = null, failure = "Couldn't load all photos. Try again.") {
            propertyStore.loadAllPhotos(entryId, id, proofPhase)
            true
        }
    }

    private fun setPhotoStatus(id: String, status: PhotoUploadStatus) {
        updatePhoto(id) { it.copy(status = status) }
    }

    private fun updatePhoto(id: String, transform: (PendingPhoto) -> PendingPhoto) {
        _photos.value = _photos.value.map { photo -> if (photo.id == id) transform(photo) else photo }
    }

    private fun buildReceiptPayload(
        room: RoomRecord,
        propertyId: UUID,
        savedCount: Int,
        attemptedCount: Int,
        issueCount: Int,
    ): SavedProofReceiptPayload {
        val thumbnail = _photos.value.firstOrNull { it.status == PhotoUploadStatus.Uploaded }?.bytes
            ?: _photos.value.firstOrNull()?.bytes
        return SavedProofReceiptPayload(
            roomId = room.id,
            roomName = room.name,
            propertyId = propertyId,
            savedCount = savedCount,
            attemptedCount = attemptedCount,
            hadPartialFailure = savedCount < attemptedCount,
            timestampMillis = System.currentTimeMillis(),
            thumbnailJpeg = thumbnail,
            proofPhase = proofPhase,
            issueCount = issueCount,
        )
    }

}

/** Camera captures are files this app wrote into its capture folder; everything else came from the library. */
private fun captureSourceOf(uri: Uri): EvidenceCaptureSource =
    if (uri.scheme == "file" && uri.path?.contains("/movemark_captures/") == true) EvidenceCaptureSource.Camera
    else EvidenceCaptureSource.Library

/** Details for a Room entry — same fields iOS saves (title is stored as the first line of notes). */
data class EntryDraft(
    val title: String = "",
    val notes: String = "",
    /** 1 Poor … 5 Excellent; default Good, as on iOS. */
    val conditionRating: Int = 4,
    val tags: Set<String> = emptySet(),
)

/** Must match the seeded `issue_tags` rows — same list as iOS `fixedIssueTags`. */
val RoomIssueTags = listOf("Scratch", "Stain", "Water damage", "Chipped paint", "Cracked tile", "Appliance damage")

/** iOS `RoomRecord.ConditionRating` order and wording. */
val RoomConditionLabels = listOf(1 to "Poor", 2 to "Below fair", 3 to "Fair", 4 to "Good", 5 to "Excellent")
