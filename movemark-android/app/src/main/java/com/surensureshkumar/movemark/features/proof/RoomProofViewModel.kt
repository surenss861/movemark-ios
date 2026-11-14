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
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceCenter
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceDraft
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceInput
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceItem
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceKey
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceSync
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceSyncResult
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.core.navigation.Routes
import com.surensureshkumar.movemark.features.proof.camera.CameraCaptureResultHolder
import com.surensureshkumar.movemark.features.proof.camera.CameraPhotoStorage
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.util.UUID
import javax.inject.Inject

private const val UPLOAD_TAG = "MoveMarkUpload"
private const val RESTORE_WAIT_MS = 15_000L

@HiltViewModel
class RoomProofViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val receiptCache: SavedProofReceiptCache,
    private val cameraResultHolder: CameraCaptureResultHolder,
    private val inspectionRepository: InspectionRepository,
    private val pendingCenter: PendingEvidenceCenter,
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

    private var pendingReceipt: SavedProofReceiptPayload? = null

    private var restoredKey: PendingEvidenceKey? = null

    init {
        if (roomId == null) {
            _message.value = "Invalid room. Please go back and try again."
        } else {
            viewModelScope.launch { restorePending() }
        }
    }

    /** Back from the camera: shots it wrote to the pending set appear, then any hand-off (gallery picks) is added. */
    fun consumeCameraCaptures() {
        val id = roomId ?: return
        viewModelScope.launch {
            val key = restoredKey
            if (key != null && !_saveState.value.isBusy) showStored(key)
            cameraResultHolder.consume(id)?.let { addUris(it) }
        }
    }

    /** This room's new-entry pending set on this phone (null until the user and rental are known). */
    private fun pendingKey(appendTo: UUID? = null): PendingEvidenceKey? {
        val userId = sessionManager.userId.value ?: return null
        val propertyId = propertyStore.currentProperty.value?.id ?: return null
        val roomId = roomId ?: return null
        return PendingEvidenceKey.of(userId, propertyId, roomId, proofPhase == ProofPhase.MoveOut, appendTo)
    }

    private fun currentPendingDraft(): PendingEvidenceDraft = _draft.value.let {
        PendingEvidenceDraft(it.title, it.notes, it.tags.sorted(), it.conditionRating)
    }

    /**
     * Brings back what an earlier visit left on this phone (after leaving, a crash or a process kill), then checks
     * it against the server: photos an interrupted save had in fact saved leave the phone, and an interrupted
     * Add photos set is sent again (the renter already asked for it).
     */
    private suspend fun restorePending() {
        val key = withTimeoutOrNull(RESTORE_WAIT_MS) {
            sessionManager.userId.first { it != null }
            propertyStore.currentProperty.first { it != null }
            pendingKey()
        } ?: return
        restoredKey = key
        val shownBefore = showStored(key)
        when (val outcome = pendingCenter.reconcile(key)) {
            is PendingEvidenceSync.ReconcileOutcome.Checked -> if (outcome.alreadySaved > 0 && !_saveState.value.isBusy) {
                refreshAfterSave()
                showStored(key)
                if (_photos.value.isEmpty() && shownBefore > 0) {
                    val saved = pendingCenter.store.manifest(key)?.savedCount?.takeIf { it > 0 } ?: outcome.alreadySaved
                    _entryNotice.tryEmit(if (saved == 1) "1 photo saved" else "$saved photos saved")
                }
            }
            else -> Unit
        }
        // Add photos sets of this room that didn't finish.
        pendingCenter.store.manifests(key.userId)
            .filter { it.key.base == key && it.key.appendTo != null && it.items.isNotEmpty() }
            .forEach { sendAppend(it.key) }
    }

    /** Rebuilds the form or the retry from what is on this phone for [key]. Returns how many photos are shown. */
    private suspend fun showStored(key: PendingEvidenceKey): Int {
        val restored = pendingCenter.store.restore(key)
        if (restored == null || restored.items.isEmpty()) {
            if (!_saveState.value.isBusy) {
                _photos.value = emptyList()
                if (_saveState.value is RoomProofSaveState.PartialSuccess || _saveState.value is RoomProofSaveState.Failed) {
                    _saveState.value = RoomProofSaveState.Idle
                    _message.value = null
                }
            }
            return 0
        }
        val manifest = restored.manifest
        val photos = withContext(Dispatchers.Default) {
            restored.items.map { (item, source) ->
                PendingPhoto(
                    id = item.id,
                    bytes = EvidenceImport.thumbnail(source) ?: ByteArray(0),
                    status = if (item.status == PendingEvidenceItem.Status.Pending) PhotoUploadStatus.Pending else PhotoUploadStatus.Failed,
                    sha256 = source.sha256Hex,
                )
            }
        }
        _photos.value = photos
        val linked = manifest.entryId != null && (manifest.savedCount > 0 || restored.items.any { it.item.unresolved != null })
        if (linked) {
            // A partial save: the entry exists; these photos are its retry.
            val requested = maxOf(manifest.requestedCount, manifest.savedCount + photos.size)
            _saveState.value = RoomProofSaveState.PartialSuccess(manifest.savedCount, photos.size)
            _message.value = RoomProofUploadMessages.partial(manifest.savedCount, requested)
            pendingReceipt = room.value?.let { r ->
                propertyStore.currentProperty.value?.let { p ->
                    buildReceiptPayload(r, p.id, manifest.savedCount, requested, manifest.draft.tags.size)
                }
            }
        } else {
            val d = manifest.draft
            _draft.value = EntryDraft(d.title, d.notes, d.conditionRating, d.tags.toSet())
            if (photos.any { it.status == PhotoUploadStatus.Failed }) {
                _saveState.value = RoomProofSaveState.Failed(RoomProofUploadMessages.FULL_FAILURE)
                _message.value = RoomProofUploadMessages.NOT_UPLOADED_YET
            } else {
                _saveState.value = RoomProofSaveState.Idle
                _message.value = null
            }
        }
        return photos.size
    }

    fun addUris(uris: List<Uri>) {
        if (_saveState.value.isBusy) return
        viewModelScope.launch {
            val key = pendingKey() ?: run {
                _message.value = "Sign in required."
                return@launch
            }
            val imported = withContext(Dispatchers.IO) { importSources(uris) }
            val sources = imported.mapNotNull { it.getOrNull() }
            if (sources.isEmpty() && uris.isNotEmpty()) {
                _message.value = importFailureMessage(imported)
                return@launch
            }
            // The same file picked twice is one photo (its source hash is its identity).
            val existing = _photos.value.mapNotNull { it.sha256 }.toSet()
            val fresh = sources.distinctBy { it.sha256Hex }.filter { it.sha256Hex !in existing }
            val inputs = fresh.map { PendingEvidenceInput(UUID.randomUUID(), it) }
            if (inputs.isNotEmpty()) {
                // On disk first: a photo is shown as taken only once it is safe on this phone.
                try {
                    pendingCenter.admit(inputs, key, room.value?.name ?: "Room", currentPendingDraft())
                } catch (e: Exception) {
                    Log.e(UPLOAD_TAG, "Couldn't keep photos on the device", e)
                    _message.value = RoomProofUploadMessages.COULD_NOT_KEEP
                    return@launch
                }
                val newPhotos = withContext(Dispatchers.Default) {
                    inputs.map { input ->
                        PendingPhoto(
                            id = input.id.toString().lowercase(),
                            bytes = EvidenceImport.thumbnail(input.source) ?: ByteArray(0),
                            sha256 = input.source.sha256Hex,
                        )
                    }
                }
                _photos.value = _photos.value + newPhotos
                if (_saveState.value !is RoomProofSaveState.PartialSuccess) _saveState.value = RoomProofSaveState.Idle
                _message.value = if (sources.size < uris.size) importFailureMessage(imported) else null
            }
            // The camera's working copies are now in the pending store (or were duplicates); drop them.
            withContext(Dispatchers.IO) { deleteCameraCopies(uris) }
        }
    }

    /** Removes a photo that isn't saved yet (iOS: the thumbnail's remove button). */
    fun removePhoto(id: String) {
        if (_saveState.value.isBusy) return
        val key = pendingKey() ?: return
        _photos.value = _photos.value.filterNot { it.id == id }
        viewModelScope.launch {
            pendingCenter.remove(listOf(id), key)
            if (_photos.value.isEmpty()) {
                if (_saveState.value is RoomProofSaveState.Failed) _saveState.value = RoomProofSaveState.Idle
                _message.value = null
            }
        }
    }

    /** The picked/captured files' bytes, untouched, as evidence sources (one result per uri). */
    private fun importSources(uris: List<Uri>): List<Result<EvidenceSource>> = uris.map { uri ->
        runCatching { EvidenceImport.source(context, uri, captureSourceOf(uri)) }
    }

    private fun deleteCameraCopies(uris: List<Uri>) {
        val captures = CameraPhotoStorage.capturesDir(context).canonicalPath
        uris.filter { captureSourceOf(it) == EvidenceCaptureSource.Camera }.forEach { uri ->
            val file = uri.path?.let(::File) ?: return@forEach
            if (file.canonicalPath.startsWith(captures)) file.delete()
        }
    }

    private fun importFailureMessage(results: List<Result<EvidenceSource>>): String =
        results.firstNotNullOfOrNull { it.exceptionOrNull()?.message }
            ?: "Could not read selected photos. Try different images."

    /**
     * Saves the room's pending photos (the form's, or a partial save's retry) through [PendingEvidenceCenter]: the
     * photos are already on this phone; they leave it only once confirmed.
     */
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
        val key = pendingKey() ?: return
        if (_photos.value.isEmpty()) {
            _message.value = "Add at least one photo before saving."
            return
        }
        val isFormSave = _saveState.value !is RoomProofSaveState.PartialSuccess
        val draft = currentPendingDraft()

        viewModelScope.launch {
            _saveState.value = RoomProofSaveState.Preparing
            _message.value = null
            try {
                if (isFormSave) pendingCenter.updateDraft(draft, key)
                _photos.value = _photos.value.map { it.copy(status = PhotoUploadStatus.Uploading) }
                val result = pendingCenter.send(key) { index, total ->
                    _saveState.value = RoomProofSaveState.Uploading(index, total)
                }
                if (result.confirmed > 0) {
                    withContext(Dispatchers.IO) {
                        propertyStore.applyEvidenceSync(
                            roomId = room.id,
                            entryId = result.entryId,
                            title = draft.title.trim().ifEmpty { room.name },
                            confirmed = result.confirmed,
                            phase = proofPhase,
                            userId = userId,
                        )
                    }
                }
                val pendingIds = result.pending.map { it.item.id }.toSet()
                val stillPending = _photos.value.filter { it.id in pendingIds }.map { it.copy(status = PhotoUploadStatus.Failed) }

                if (result.nothingLinked && result.pending.isNotEmpty()) {
                    // Nothing saved and no entry holds anything of it: the photos stay in the form as they were.
                    _photos.value = stillPending
                    val failure = RoomProofUploadMessages.failure(
                        (result.failure as? PendingEvidenceSyncResult.Failure.Unreachable)?.error ?: result.lastError,
                    )
                    _saveState.value = RoomProofSaveState.Failed(failure)
                    _message.value = failure
                    return@launch
                }

                // The entry exists now: the form is done with either way.
                _draft.value = EntryDraft()
                val issueCount = draft.tags.size
                if (!result.isComplete) {
                    _photos.value = stillPending
                    pendingReceipt = buildReceiptPayload(room, property.id, result.savedTotal, result.requestedTotal, issueCount)
                    _saveState.value = RoomProofSaveState.PartialSuccess(result.savedTotal, stillPending.size)
                    _message.value = RoomProofUploadMessages.partial(result.savedTotal, result.requestedTotal)
                    return@launch
                }
                val payload = buildReceiptPayload(room, property.id, result.savedTotal, result.requestedTotal, issueCount)
                receiptCache.put(payload)
                _photos.value = emptyList()
                pendingReceipt = null
                _saveState.value = RoomProofSaveState.Success(result.savedTotal)
                _message.value = null
                _proofSaved.tryEmit(payload)
            } catch (e: Exception) {
                Log.e(UPLOAD_TAG, "Save proof failed", e)
                val friendly = MMUserMessages.proofSave(e)
                _photos.value = _photos.value.map { it.copy(status = PhotoUploadStatus.Failed) }
                _saveState.value = RoomProofSaveState.Failed(friendly)
                _message.value = friendly
            } finally {
                if (_saveState.value.isBusy) _saveState.value = RoomProofSaveState.Idle
            }
        }
    }

    fun retryFailedUploads() {
        if (_saveState.value.isBusy) return
        if (_photos.value.isEmpty()) return
        save()
    }

    /**
     * Leave with what was saved. The photos that didn't make it stay on this phone (and on the Proof home's
     * "not uploaded yet" row) and come back when the room is opened again.
     */
    fun continueWithSavedProof() {
        val payload = pendingReceipt ?: return
        receiptCache.put(payload)
        pendingReceipt = null
        _saveState.value = RoomProofSaveState.Idle
        _message.value = null
        _proofSaved.tryEmit(payload)
    }

    fun isUploadInProgress(): Boolean = _saveState.value.isBusy || _entryBusy.value

    fun updateDraft(transform: (EntryDraft) -> EntryDraft) {
        _draft.value = transform(_draft.value)
        // Typed details are kept with the photos, so a restore brings both back.
        val key = pendingKey() ?: return
        if (_photos.value.isEmpty() || _saveState.value.isBusy || _saveState.value is RoomProofSaveState.PartialSuccess) return
        val draft = currentPendingDraft()
        viewModelScope.launch { pendingCenter.updateDraft(draft, key) }
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

    /**
     * Add photos to an existing entry (iOS `appendPhotos`). The photos go to this phone first (their own set,
     * keyed to the entry) and leave it only once saved; an unfinished set is sent again when the room reopens.
     */
    fun appendPhotos(entryId: UUID, uris: List<Uri>) {
        val key = pendingKey(appendTo = entryId) ?: return
        if (uris.isEmpty()) return
        runEntryAction(success = null, failure = RoomProofUploadMessages.FULL_FAILURE) {
            val sources = withContext(Dispatchers.IO) { importSources(uris) }.mapNotNull { it.getOrNull() }
            if (sources.isEmpty()) throw IllegalStateException("Could not read selected photos.")
            val inputs = sources.distinctBy { it.sha256Hex }.map { PendingEvidenceInput(UUID.randomUUID(), it) }
            pendingCenter.admit(inputs, key, room.value?.name ?: "Room")
            sendAppend(key)
            true
        }
    }

    /** Sends one Add photos set and reports the outcome. */
    private suspend fun sendAppend(key: PendingEvidenceKey) {
        val result = pendingCenter.send(key)
        if (result.confirmed > 0) {
            sessionManager.userId.value?.let { withContext(Dispatchers.IO) { propertyStore.refreshActive(it) } }
        }
        val notice = when {
            result.failure == PendingEvidenceSyncResult.Failure.EntryMissing -> {
                restoredKey?.let { showStored(it) }
                "That entry was deleted, so its photos moved to a new entry here. Save to upload them."
            }
            result.pending.isNotEmpty() && result.confirmed == 0 ->
                "${RoomProofUploadMessages.FULL_FAILURE} The photos are kept on this phone."
            result.pending.isNotEmpty() ->
                "${RoomProofUploadMessages.partial(result.savedTotal, result.requestedTotal)} The rest are kept on this phone."
            result.confirmed == 1 -> "1 photo added"
            result.confirmed > 1 -> "${result.confirmed} photos added"
            else -> null
        }
        notice?.let { _entryNotice.tryEmit(it) }
    }

    private suspend fun refreshAfterSave() {
        sessionManager.userId.value?.let { withContext(Dispatchers.IO) { propertyStore.refreshActive(it) } }
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
