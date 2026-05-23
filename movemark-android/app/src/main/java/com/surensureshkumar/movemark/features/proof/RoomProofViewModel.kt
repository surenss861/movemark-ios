package com.surensureshkumar.movemark.features.proof

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.property.EvidenceUploadContext
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
import java.io.ByteArrayOutputStream
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
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    val roomId: UUID = UUID.fromString(checkNotNull(savedStateHandle.get<String>(Routes.RoomProofArg)))
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

    private var uploadContext: EvidenceUploadContext? = null
    private var pendingReceipt: SavedProofReceiptPayload? = null

    fun consumeCameraCaptures() {
        cameraResultHolder.consume(roomId)?.let { addUris(it) }
    }

    fun addUris(uris: List<Uri>) {
        if (_saveState.value.isBusy) return
        viewModelScope.launch {
            val bytes = withContext(Dispatchers.IO) {
                uris.mapNotNull { uri -> uri.toJpegBytes(context) }
            }
            if (bytes.isEmpty() && uris.isNotEmpty()) {
                _message.value = "Could not read selected photos. Try different images."
                return@launch
            }
            val existing = _photos.value.map { it.bytes.contentHashCode() }.toSet()
            val newPhotos = bytes
                .filter { it.contentHashCode() !in existing }
                .map { PendingPhoto(bytes = it) }
            if (newPhotos.isNotEmpty()) {
                _photos.value = _photos.value + newPhotos
                _saveState.value = RoomProofSaveState.Idle
                _message.value = null
            }
        }
    }

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
                    propertyStore.createEvidenceUploadContext(
                        roomId = room.id,
                        title = room.name,
                        notes = "",
                        propertyId = property.id,
                        userId = userId,
                        proofPhase = proofPhase,
                    )
                }.also { uploadContext = it }

                var uploadedThisRun = 0
                val batchSize = toUpload.size

                toUpload.forEachIndexed { index, photo ->
                    _saveState.value = RoomProofSaveState.Uploading(index + 1, batchSize)
                    setPhotoStatus(photo.id, PhotoUploadStatus.Uploading)
                    val ok = withContext(Dispatchers.IO) {
                        propertyStore.uploadSingleEvidencePhoto(uploadCtx, photo.bytes)
                    }
                    setPhotoStatus(photo.id, if (ok) PhotoUploadStatus.Uploaded else PhotoUploadStatus.Failed)
                    if (ok) uploadedThisRun++
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
                        _saveState.value = RoomProofSaveState.Failed(RoomProofUploadMessages.FULL_FAILURE)
                        _message.value = RoomProofUploadMessages.FULL_FAILURE
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
                        )
                        receiptCache.put(payload)
                        _photos.value = emptyList()
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

    fun isUploadInProgress(): Boolean = _saveState.value.isBusy

    private fun setPhotoStatus(id: String, status: PhotoUploadStatus) {
        _photos.value = _photos.value.map { photo ->
            if (photo.id == id) photo.copy(status = status) else photo
        }
    }

    private fun buildReceiptPayload(
        room: RoomRecord,
        propertyId: UUID,
        savedCount: Int,
        attemptedCount: Int,
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
        )
    }

    private fun Uri.toJpegBytes(context: Context): ByteArray? =
        runCatching {
            context.contentResolver.openInputStream(this)?.use { stream ->
                val bitmap = BitmapFactory.decodeStream(stream) ?: return@runCatching null
                val scaled = bitmap.scaleMax(1920)
                ByteArrayOutputStream().apply {
                    scaled.compress(Bitmap.CompressFormat.JPEG, 82, this)
                    if (scaled !== bitmap) scaled.recycle()
                    bitmap.recycle()
                }.toByteArray()
            }
        }.getOrNull()

    private fun Bitmap.scaleMax(maxSide: Int): Bitmap {
        val max = maxOf(width, height)
        if (max <= maxSide) return this
        val scale = maxSide.toFloat() / max
        return Bitmap.createScaledBitmap(
            this,
            (width * scale).toInt().coerceAtLeast(1),
            (height * scale).toInt().coerceAtLeast(1),
            true,
        )
    }
}
