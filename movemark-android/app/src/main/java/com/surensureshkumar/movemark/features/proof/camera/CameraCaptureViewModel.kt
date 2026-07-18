package com.surensureshkumar.movemark.features.proof.camera

import android.content.Context
import android.net.Uri
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.property.PropertyStore
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
    propertyStore: PropertyStore,
    private val resultHolder: CameraCaptureResultHolder,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {
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
                }.let { uri ->
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

    fun addGalleryUris(uris: List<Uri>) {
        if (uris.isEmpty()) return
        val existing = _capturedUris.value.map { it.toString() }.toSet()
        val merged = _capturedUris.value + uris.filter { it.toString() !in existing }
        setCapturedUris(merged)
        _errorMessage.value = null
    }

    /** Delivers captured URIs to [resultHolder] and invokes [onResult] with whether there was anything to deliver. */
    fun finishAndDeliver(onResult: (Boolean) -> Unit) {
        val uris = _capturedUris.value
        if (uris.isEmpty()) {
            onResult(false)
            return
        }
        viewModelScope.launch {
            resultHolder.deliver(roomId, uris)
            onResult(true)
        }
    }

    fun discardPending() {
        setCapturedUris(emptyList())
    }

    fun hasCaptures(): Boolean = _capturedUris.value.isNotEmpty()

    private companion object {
        const val CAPTURED_URIS_KEY = "captured_uris"

        fun restoreCapturedUris(savedStateHandle: SavedStateHandle): List<Uri> =
            savedStateHandle.get<List<String>>(CAPTURED_URIS_KEY)?.map(Uri::parse) ?: emptyList()
    }
}
