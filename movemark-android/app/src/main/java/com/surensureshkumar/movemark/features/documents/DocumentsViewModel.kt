package com.surensureshkumar.movemark.features.documents

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.BuildConfig
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.data.property.DocumentRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
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
    @ApplicationContext private val context: Context,
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

    private val _openUrl = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val openUrl: SharedFlow<String> = _openUrl.asSharedFlow()

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
                    failAfterUpload = consumeFailNextInsert(),
                )
            }
            if (saved.isFailure) {
                _error.value = "Couldn't upload that file. Try again."
                _uploading.value = null
                return@launch
            }
            runCatching { documentRepository.fetchDocuments(propertyId) }
                .onSuccess { _documents.value = it }
            propertyStore.refreshActive(userId)
            _uploading.value = null
        }
    }

    fun view(kind: VaultDocumentKind) {
        val row = _documents.value.firstOrNull { kind.queryKeys().contains(it.documentType) } ?: return
        viewModelScope.launch {
            runCatching { documentRepository.signedUrl(kind, row.filePath) }
                .onSuccess { _openUrl.emit(it) }
                .onFailure { _error.value = "Couldn't open that file." }
        }
    }

    /** Debug-only. Set `fail_next_document_insert` to exercise storage cleanup after a failed row save. */
    private fun consumeFailNextInsert(): Boolean {
        if (!BuildConfig.DEBUG) return false
        val prefs = context.getSharedPreferences(DEBUG_PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(FAIL_NEXT_INSERT, false)) return false
        prefs.edit().putBoolean(FAIL_NEXT_INSERT, false).apply()
        return true
    }

    private companion object {
        const val MAX_BYTES = 20 * 1024 * 1024
        const val DEBUG_PREFS = "movemark_debug"
        const val FAIL_NEXT_INSERT = "fail_next_document_insert"
        val uploadScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }
}
