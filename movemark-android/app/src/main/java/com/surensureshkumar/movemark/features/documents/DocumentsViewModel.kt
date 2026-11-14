package com.surensureshkumar.movemark.features.documents

import com.surensureshkumar.movemark.data.backend.MoveMarkStorageException
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.data.property.DocumentRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import android.content.Context
import com.surensureshkumar.movemark.data.export.ReportFileDownloader
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DocumentsViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val propertyStore: PropertyStore,
    private val documentRepository: DocumentRepository,
    private val sessionManager: SessionManager,
) : ViewModel() {
    private val _documents = MutableStateFlow<List<PropertyDocumentRow>>(emptyList())
    val documents: StateFlow<List<PropertyDocumentRow>> = _documents.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _uploading = MutableStateFlow<VaultDocumentKind?>(null)
    val uploading: StateFlow<VaultDocumentKind?> = _uploading.asStateFlow()

    /** A downloaded copy in app-private cache, to open through FileProvider (never a signed URL handed out). */
    private val _openFile = MutableSharedFlow<Pair<File, String>>(extraBufferCapacity = 1)
    val openFile: SharedFlow<Pair<File, String>> = _openFile.asSharedFlow()

    fun refresh() {
        val propertyId = propertyStore.activePropertyId.value ?: return
        viewModelScope.launch {
            runCatching { documentRepository.fetchDocuments(propertyId) }
                .onSuccess { _documents.value = it }
                .onFailure { _error.value = "Couldn't load your records." }
        }
    }

    fun upload(kind: VaultDocumentKind, bytes: ByteArray, fileName: String) {
        val propertyId = propertyStore.activePropertyId.value
        val userId = sessionManager.userId.value
        if (propertyId == null || userId == null) {
            _error.value = "No active rental found."
            return
        }
        if (bytes.size > MAX_BYTES) {
            _error.value = "That file is too large. Choose one under 20 MB."
            return
        }
        // The file picker can pop this screen as it returns. Keep the save alive so the
        // vault count still refreshes when the user lands back on Proof.
        uploadScope.launch {
            _uploading.value = kind
            _error.value = null
            val saved = runCatching {
                documentRepository.replaceDocument(
                    propertyId,
                    userId,
                    kind,
                    bytes,
                    fileName,
                )
            }
            if (saved.isFailure) {
                val failure = saved.exceptionOrNull()
                _error.value = if ((failure as? MoveMarkStorageException.Rejected)?.code == MoveMarkStorageException.TEEN_METADATA_CODE) {
                    MoveMarkStorageException.TEEN_METADATA_MESSAGE
                } else {
                    "Couldn't upload that file. Try again."
                }
                _uploading.value = null
                return@launch
            }
            runCatching { documentRepository.fetchDocuments(propertyId) }
                .onSuccess { _documents.value = it }
            propertyStore.refreshActive(userId)
            _uploading.value = null
        }
    }

    private val _deleting = MutableStateFlow<VaultDocumentKind?>(null)
    val deleting: StateFlow<VaultDocumentKind?> = _deleting.asStateFlow()

    /** Removes the document from the rental record (after the screen's confirmation). */
    fun delete(kind: VaultDocumentKind) {
        val propertyId = propertyStore.activePropertyId.value ?: return
        val userId = sessionManager.userId.value ?: return
        if (_deleting.value != null) return
        viewModelScope.launch {
            _deleting.value = kind
            _error.value = null
            runCatching { documentRepository.deleteDocuments(propertyId, kind) }
                .onFailure { _error.value = "Couldn't delete that file. Try again." }
            runCatching { documentRepository.fetchDocuments(propertyId) }.onSuccess { _documents.value = it }
            propertyStore.refreshActive(userId)
            _deleting.value = null
        }
    }

    fun view(kind: VaultDocumentKind) {
        val row = _documents.value.firstOrNull { kind.queryKeys().contains(it.documentType) } ?: return
        viewModelScope.launch {
            runCatching {
                val url = documentRepository.signedUrl(row.filePath)
                val name = row.filePath.substringAfterLast('/')
                ReportFileDownloader.downloadTo(appContext, url, "movemark_documents", name) to mimeType(name)
            }
                .onSuccess { _openFile.emit(it) }
                .onFailure { _error.value = "Couldn't open that file." }
        }
    }

    private fun mimeType(name: String): String = when {
        name.endsWith(".pdf", ignoreCase = true) -> "application/pdf"
        name.endsWith(".png", ignoreCase = true) -> "image/png"
        else -> "image/jpeg"
    }

    private companion object {
        const val MAX_BYTES = 20 * 1024 * 1024
        val uploadScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }
}
