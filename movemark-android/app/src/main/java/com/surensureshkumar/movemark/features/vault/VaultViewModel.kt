package com.surensureshkumar.movemark.features.vault

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceCenter
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceKey
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceRoomSummary
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.data.models.VaultSummary
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class VaultViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
    private val inspectionRepository: InspectionRepository,
    private val fileUrls: StoredFileUrls,
    subscriptionRepository: SubscriptionRepository,
    private val pendingEvidence: PendingEvidenceCenter,
) : ViewModel() {
    /** Rooms (any rental of this user) with photos not uploaded yet, newest first (iOS `pendingRooms`). */
    val pendingRooms: StateFlow<List<PendingEvidenceRoomSummary>> =
        combine(pendingEvidence.summaries, propertyStore.properties, sessionManager.userId) { rooms, rentals, userId ->
            val ids = rentals.map { it.id.lowercase() }.toSet()
            val user = userId?.toString()?.lowercase()
            rooms.filter { it.key.userId == user && it.key.propertyId in ids }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    init {
        viewModelScope.launch { pendingEvidence.refresh(sessionManager.userId.value?.toString()) }
    }

    /** Opens the room holding [summary]'s photos, switching rental first when it belongs to another one. */
    fun openPendingRoom(summary: PendingEvidenceRoomSummary, open: (UUID, ProofPhase) -> Unit) {
        val propertyId = UUID.fromString(summary.key.propertyId)
        val roomId = UUID.fromString(summary.key.roomId)
        val phase = if (summary.key.stage == PendingEvidenceKey.Stage.MoveOut) ProofPhase.MoveOut else ProofPhase.MoveIn
        val userId = sessionManager.userId.value
        if (propertyStore.currentProperty.value?.id == propertyId || userId == null) return open(roomId, phase)
        viewModelScope.launch {
            propertyStore.activateProperty(propertyId, userId)
            open(roomId, phase)
        }
    }

    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty
    val maintenanceLog = propertyStore.maintenanceLog
    val properties: StateFlow<List<PropertyRow>> = propertyStore.properties
    val loading: StateFlow<Boolean> = propertyStore.isLoading
    val error: StateFlow<String?> = propertyStore.errorMessage
    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro
    val propertyCount: StateFlow<Int> = propertyStore.properties
        .map { it.size }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)

    private val _previewImageUrl = MutableStateFlow<String?>(null)
    val previewImageUrl: StateFlow<String?> = _previewImageUrl.asStateFlow()

    // Stable storage path backing previewImageUrl -- used only to cache-key the AsyncImage request
    // (see rememberSignedImageRequest) so a re-mint of the signed URL doesn't force a re-download.
    private val _previewImagePath = MutableStateFlow<String?>(null)
    val previewImagePath: StateFlow<String?> = _previewImagePath.asStateFlow()

    /** Per-rental rooms / documented rooms / newest evidence, from one `get_vault_summaries` call. */
    private val _summaries = MutableStateFlow<Map<String, VaultSummary>>(emptyMap())
    val summaries: StateFlow<Map<String, VaultSummary>> = _summaries.asStateFlow()

    init {
        viewModelScope.launch {
            property.collect { record ->
                _summaries.value = propertyStore.vaultSummaries()
                refreshPreviewUrl(record)
            }
        }
    }

    fun activateProperty(propertyId: UUID) {
        val userId = sessionManager.userId.value ?: return
        viewModelScope.launch {
            propertyStore.activateProperty(propertyId, userId)
        }
    }

    private suspend fun refreshPreviewUrl(property: PropertyRecord?) {
        _previewImageUrl.value = null
        _previewImagePath.value = null
        if (property == null || RoomProofMetrics.documentedCount(property) <= 0) return
        // The rental's newest evidence (as on iOS), signed by its row id; else the first loaded move-in photo.
        val latest = _summaries.value[property.id.toString().lowercase()]?.latestEvidence
        latest?.let { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) }
        val path = latest?.let { it.thumbnailPath ?: it.filePath }
            ?: RoomProofMetrics.firstPreviewPhotoPath(property)
            ?: return
        runCatching {
            inspectionRepository.signedUrl(path)
        }.onSuccess { url ->
            _previewImageUrl.value = url
            _previewImagePath.value = path
        }
    }
}
