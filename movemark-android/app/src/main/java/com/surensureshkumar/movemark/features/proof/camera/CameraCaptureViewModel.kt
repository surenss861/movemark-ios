package com.surensureshkumar.movemark.features.proof.camera

import android.content.Context
import android.net.Uri
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.navigation.Routes
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceImport
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceCenter
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceInput
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceKey
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.ProofPhase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.UUID
import javax.inject.Inject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@HiltViewModel
class CameraCaptureViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val propertyStore: PropertyStore,
    private val resultHolder: CameraCaptureResultHolder,
    private val sessionManager: SessionManager,
    private val pendingCenter: PendingEvidenceCenter,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val moveOut = ProofPhase.fromKey(savedStateHandle.get<String>(Routes.ProofPhaseArg)) == ProofPhase.MoveOut

    /** Shots already written to the room's pending set (by id); they need no hand-off. */
    private var admittedIds: List<String>
        get() = savedStateHandle.get<List<String>>(ADMITTED_IDS_KEY).orEmpty()
        set(value) { savedStateHandle[ADMITTED_IDS_KEY] = value }
    private var admittedUris: Set<String>
        get() = savedStateHandle.get<List<String>>(ADMITTED_URIS_KEY).orEmpty().toSet()
        set(value) { savedStateHandle[ADMITTED_URIS_KEY] = value.toList() }

    private fun pendingKey(): PendingEvidenceKey? {
        val userId = sessionManager.userId.value ?: return null
        val propertyId = propertyStore.currentProperty.value?.id ?: return null
        return PendingEvidenceKey.of(userId, propertyId, roomId, moveOut)
    }

    /**
     * Writes a shot to the room's pending set at once (iOS `admitCapture`), so a process kill while the camera is
     * open loses nothing. Returns the stored file's uri, or null when it couldn't be kept there (the cache copy
     * is then handed off on Done, as before).
     */
    private suspend fun admitCapture(file: java.io.File): Uri? {
        val key = pendingKey() ?: return null
        return try {
            val source = withContext(Dispatchers.IO) { EvidenceImport.source(file.readBytes(), EvidenceCaptureSource.Camera) }
            val id = UUID.randomUUID()
            pendingCenter.admit(listOf(PendingEvidenceInput(id, source)), key, roomName.value)
            val stored = java.io.File(pendingCenter.store.roomFolder(key), "${id.toString().lowercase()}.${source.fileExtension}")
            withContext(Dispatchers.IO) { file.delete() }
            admittedIds = admittedIds + id.toString().lowercase()
            Uri.fromFile(stored).also { admittedUris = admittedUris + it.toString() }
        } catch (e: Exception) {
            android.util.Log.e("MoveMarkCamera", "Couldn't keep the shot in the pending set; handing off on Done", e)
            null
        }
    }
    val roomId: UUID = UUID.fromString(
        checkNotNull(savedStateHandle.get<String>(com.surensureshkumar.movemark.core.navigation.Routes.RoomProofArg)),
    )

    val roomName: StateFlow<String> = propertyStore.currentProperty
        .map { prop -> prop?.rooms?.firstOrNull { it.id == roomId }?.name ?: "Room proof" }
        .stateIn(viewModelScope, kotlinx.coroutines.flow.SharingStarted.WhileSubscribed(5_000), "Room proof")

    // Backed by SavedStateHandle (not a plain field) so in-progress captures survive process
    // death while this screen is backgrounded, not just configuration changes.
    private val _capturedUris = MutableStateFlow(restoreCapturedUris(savedStateHandle))
    val capturedUris: StateFlow<List<Uri>> = _capturedUris.asStateFlow()

    private fun setCapturedUris(uris: List<Uri>) {
        _capturedUris.value = uris
        savedStateHandle[CAPTURED_URIS_KEY] = uris.map { it.toString() }
    }

    val capturedCount: StateFlow<Int> = _capturedUris
        .map { it.size }
        .stateIn(viewModelScope, kotlinx.coroutines.flow.SharingStarted.Eagerly, 0)

    private val _isCapturing = MutableStateFlow(false)
    val isCapturing: StateFlow<Boolean> = _isCapturing.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun capture(imageCapture: ImageCapture) {
        if (_isCapturing.value) return
        viewModelScope.launch {
            _isCapturing.value = true
            _errorMessage.value = null
            try {
                val file = CameraPhotoStorage.newCaptureFile(context, roomId)
                val output = ImageCapture.OutputFileOptions.Builder(file).build()
                suspendCancellableCoroutine { cont ->
                    imageCapture.takePicture(
                        output,
                        androidx.core.content.ContextCompat.getMainExecutor(context),
                        object : ImageCapture.OnImageSavedCallback {
                            override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                                cont.resume(outputFileResults.savedUri ?: Uri.fromFile(file))
                            }

                            override fun onError(exception: ImageCaptureException) {
                                cont.resumeWithException(exception)
                            }
                        },
                    )
                }.let { captured ->
                    val uri = admitCapture(file) ?: captured
                    if (_capturedUris.value.none { it.toString() == uri.toString() }) {
                        setCapturedUris(_capturedUris.value + uri)
                    }
                }
            } catch (_: Exception) {
                _errorMessage.value = "Photo couldn't be captured. Try again."
            } finally {
                _isCapturing.value = false
            }
        }
    }

    /** The camera couldn't start on this device: say so; the photo library stays available. */
    fun cameraUnavailable() {
        _errorMessage.value = CAMERA_UNAVAILABLE
    }

    fun addGalleryUris(uris: List<Uri>) {
        if (uris.isEmpty()) return
        val existing = _capturedUris.value.map { it.toString() }.toSet()
        val merged = _capturedUris.value + uris.filter { it.toString() !in existing }
        setCapturedUris(merged)
        _errorMessage.value = null
    }

    /** Delivers captured URIs to [resultHolder] and invokes [onResult] with whether there was anything to deliver. */
    fun finishAndDeliver(onResult: (Boolean) -> Unit) {
        val all = _capturedUris.value
        if (all.isEmpty()) {
            onResult(false)
            return
        }
        // Shots already in the pending set show up in the room by themselves; hand off only the rest.
        val handOff = all.filter { it.toString() !in admittedUris }
        viewModelScope.launch {
            if (handOff.isNotEmpty()) resultHolder.deliver(roomId, handOff)
            onResult(true)
        }
    }

    /** The renter chose Discard: the shots taken here leave the phone too. */
    fun discardPending() {
        val ids = admittedIds
        val key = pendingKey()
        setCapturedUris(emptyList())
        admittedIds = emptyList()
        admittedUris = emptySet()
        if (ids.isNotEmpty() && key != null) viewModelScope.launch { pendingCenter.remove(ids, key) }
    }

    fun hasCaptures(): Boolean = _capturedUris.value.isNotEmpty()

    private companion object {
        const val CAMERA_UNAVAILABLE = "The camera couldn’t start on this phone. Add photos from your library instead."
        const val CAPTURED_URIS_KEY = "captured_uris"
        const val ADMITTED_IDS_KEY = "admitted_ids"
        const val ADMITTED_URIS_KEY = "admitted_uris"

        fun restoreCapturedUris(savedStateHandle: SavedStateHandle): List<Uri> =
            savedStateHandle.get<List<String>>(CAPTURED_URIS_KEY)?.map(Uri::parse) ?: emptyList()
    }
}
