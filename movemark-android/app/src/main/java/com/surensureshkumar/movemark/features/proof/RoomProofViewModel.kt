package com.surensureshkumar.movemark.features.proof

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.RoomProofMetrics
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

@HiltViewModel
class RoomProofViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val receiptCache: SavedProofReceiptCache,
    private val cameraResultHolder: CameraCaptureResultHolder,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    val roomId: UUID = UUID.fromString(checkNotNull(savedStateHandle.get<String>("roomId")))

    val room: StateFlow<RoomRecord?> = propertyStore.currentProperty
        .map { prop -> prop?.rooms?.firstOrNull { it.id == roomId } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    private val _photos = MutableStateFlow<List<ByteArray>>(emptyList())
    val photoCount: StateFlow<Int> = _photos.map { it.size }
        .stateIn(viewModelScope, SharingStarted.Eagerly, 0)

    private val _uploading = MutableStateFlow(false)
    val uploading: StateFlow<Boolean> = _uploading.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _proofSaved = MutableSharedFlow<SavedProofReceiptPayload>(extraBufferCapacity = 1)
    val proofSaved: SharedFlow<SavedProofReceiptPayload> = _proofSaved.asSharedFlow()

    fun consumeCameraCaptures() {
        cameraResultHolder.consume(roomId)?.let { addUris(it) }
    }

    fun addUris(uris: List<Uri>) {
        viewModelScope.launch {
            val bytes = withContext(Dispatchers.IO) {
                uris.mapNotNull { uri -> uri.toJpegBytes(context) }
            }
            if (bytes.isEmpty() && uris.isNotEmpty()) {
                _message.value = "Could not read selected photos. Try different images."
                return@launch
            }
            _photos.value = _photos.value + bytes
            _message.value = null
        }
    }

    fun save() {
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
        if (_photos.value.isEmpty()) {
            _message.value = "Add at least one photo before saving."
            return
        }
        if (_uploading.value) return

        viewModelScope.launch {
            _uploading.value = true
            _message.value = null
            try {
                val photosToUpload = _photos.value
                val thumbnail = photosToUpload.firstOrNull()
                val result = withContext(Dispatchers.IO) {
                    propertyStore.addEvidence(
                        roomId = room.id,
                        title = room.name,
                        notes = "",
                        photos = photosToUpload,
                        propertyId = property.id,
                        userId = userId,
                    )
                }
                if (result.savedCount <= 0) {
                    _message.value = "Photos could not be uploaded. Check your connection and try again."
                    return@launch
                }
                _photos.value = emptyList()
                val payload = SavedProofReceiptPayload(
                    roomId = room.id,
                    roomName = room.name,
                    propertyId = property.id,
                    savedCount = result.savedCount,
                    attemptedCount = result.attemptedCount,
                    hadPartialFailure = result.hadPartialFailure,
                    timestampMillis = System.currentTimeMillis(),
                    thumbnailJpeg = thumbnail,
                )
                receiptCache.put(payload)
                if (result.hadPartialFailure) {
                    _message.value = "${result.savedCount} of ${result.attemptedCount} photos uploaded"
                } else {
                    _message.value = null
                }
                _proofSaved.tryEmit(payload)
            } catch (e: Exception) {
                _message.value = e.message ?: "Save failed."
            } finally {
                _uploading.value = false
            }
        }
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
