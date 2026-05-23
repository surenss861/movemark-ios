package com.surensureshkumar.movemark.features.proof

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.surensureshkumar.movemark.core.navigation.Routes
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID
import javax.inject.Inject

data class SavedProofReceiptUiState(
    val roomName: String = "",
    val savedCount: Int = 0,
    val attemptedCount: Int = 0,
    val hadPartialFailure: Boolean = false,
    val timestampLabel: String = "",
    val isRoomDocumented: Boolean = true,
    val thumbnailJpeg: ByteArray? = null,
    val partialMessage: String? = null,
    val proofPhase: ProofPhase = ProofPhase.MoveIn,
    val headerSubtitle: String = "",
    val roomDocumentedLabel: String = "Room now documented",
    val primaryActionLabel: String = "Continue next room",
    val nextRoomName: String? = null,
)

@HiltViewModel
class SavedProofReceiptViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val receiptCache: SavedProofReceiptCache,
    private val propertyStore: PropertyStore,
) : ViewModel() {
    val roomId: UUID = UUID.fromString(checkNotNull(savedStateHandle.get<String>(Routes.RoomProofArg)))
    val proofPhase: ProofPhase = ProofPhase.fromKey(savedStateHandle.get<String>(Routes.ProofPhaseArg))

    private val _uiState = MutableStateFlow(SavedProofReceiptUiState())
    val uiState: StateFlow<SavedProofReceiptUiState> = _uiState.asStateFlow()

    init {
        val payload = receiptCache.consume(roomId)
        val room = propertyStore.currentProperty.value?.rooms?.firstOrNull { it.id == roomId }
        val roomName = payload?.roomName ?: room?.name ?: "Room"
        val phase = payload?.proofPhase ?: proofPhase
        val saved = payload?.savedCount ?: room?.let { RoomProofMetrics.photoCount(it, phase) } ?: 0
        val attempted = payload?.attemptedCount ?: saved
        val partial = payload?.hadPartialFailure == true
        val ts = payload?.timestampMillis ?: System.currentTimeMillis()
        val nextRoom = propertyStore.currentProperty.value?.let { RoomProofMetrics.nextRoom(it, phase) }
        val totalRooms = propertyStore.currentProperty.value?.rooms?.size ?: 0
        val documented = propertyStore.currentProperty.value?.let { RoomProofMetrics.documentedCount(it, phase) } ?: 0
        val phaseLabel = phase.displayName
        val photosSavedLine = when {
            partial -> "$saved of $attempted photos saved"
            saved == 1 -> "1 photo saved"
            else -> "$saved photos saved"
        }
        val headerSubtitle = "$roomName proof · $photosSavedLine · $phaseLabel"
        val primaryActionLabel = when {
            nextRoom != null -> "Continue with ${nextRoom.name}"
            documented >= totalRooms && totalRooms > 0 && phase == ProofPhase.MoveIn -> "Go to Reports"
            phase == ProofPhase.MoveOut -> "Continue next move-out room"
            else -> "Go to Reports"
        }

        _uiState.value = SavedProofReceiptUiState(
            roomName = roomName,
            savedCount = saved,
            attemptedCount = attempted,
            hadPartialFailure = partial,
            timestampLabel = formatTimestamp(ts, phase),
            isRoomDocumented = room?.let { RoomProofMetrics.isDocumented(it, phase) } == true,
            thumbnailJpeg = payload?.thumbnailJpeg,
            partialMessage = if (partial) "$saved of $attempted photos saved" else null,
            proofPhase = phase,
            headerSubtitle = headerSubtitle,
            roomDocumentedLabel = if (room?.let { RoomProofMetrics.isDocumented(it, phase) } == true) {
                "Room now documented"
            } else {
                ""
            },
            primaryActionLabel = primaryActionLabel,
            nextRoomName = nextRoom?.name,
        )
    }

    fun nextUndocumentedRoomId(): UUID? {
        val property = propertyStore.currentProperty.value ?: return null
        return RoomProofMetrics.nextRoom(property, proofPhase)?.id
    }

    private fun formatTimestamp(millis: Long, phase: ProofPhase): String {
        val formatter = DateTimeFormatter.ofPattern("MMM d · h:mm a")
            .withZone(ZoneId.systemDefault())
        return "${phase.displayName} · ${formatter.format(Instant.ofEpochMilli(millis))}"
    }
}
