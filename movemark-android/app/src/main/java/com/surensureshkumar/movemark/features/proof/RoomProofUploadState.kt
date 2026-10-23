package com.surensureshkumar.movemark.features.proof

import com.surensureshkumar.movemark.data.backend.MoveMarkStorageException
import com.surensureshkumar.movemark.data.backend.MoveMarkUploadFailure
import com.surensureshkumar.movemark.data.evidence.EvidenceImportException
import com.surensureshkumar.movemark.data.evidence.PendingEvidence
import java.util.UUID

enum class PhotoUploadStatus {
    Pending,
    Uploading,
    Uploaded,
    Failed,
}

data class PendingPhoto(
    val id: String = UUID.randomUUID().toString(),
    /** Upright preview JPEG for the grid (the evidence thumbnail) — display only, never uploaded. */
    val bytes: ByteArray,
    val status: PhotoUploadStatus = PhotoUploadStatus.Pending,
    /** The untouched source and its stable row id; carries an unresolved upload between attempts. */
    val evidence: PendingEvidence? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is PendingPhoto) return false
        return id == other.id && bytes.contentEquals(other.bytes) && status == other.status && evidence == other.evidence
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + bytes.contentHashCode()
        result = 31 * result + status.hashCode()
        return result
    }
}

sealed class RoomProofSaveState {
    data object Idle : RoomProofSaveState()
    data object Preparing : RoomProofSaveState()
    data class Uploading(val currentIndex: Int, val total: Int) : RoomProofSaveState()
    data class PartialSuccess(val uploadedCount: Int, val failedCount: Int) : RoomProofSaveState()
    data class Success(val uploadedCount: Int) : RoomProofSaveState()
    data class Failed(val message: String) : RoomProofSaveState()

    val isBusy: Boolean
        get() = this is Preparing || this is Uploading
}

fun RoomProofSaveState.saveButtonLabel(): String = when (this) {
    is RoomProofSaveState.Uploading -> "Uploading ${currentIndex} of $total…"
    is RoomProofSaveState.Preparing -> "Preparing…"
    else -> "Save proof"
}

object RoomProofUploadMessages {
    const val FULL_FAILURE = "Photos couldn't upload. Check your connection and try again."
    const val RETRY_LABEL = "Retry upload"

    fun partial(uploaded: Int, total: Int) = "$uploaded of $total photos saved."

    /** A failure the user can act on (too large, unsupported, rate limited) keeps its own words. */
    fun failure(error: Throwable?): String {
        val cause = (error as? MoveMarkUploadFailure)?.underlying ?: error
        return when (cause) {
            is MoveMarkStorageException.Rejected, is EvidenceImportException -> cause.message ?: FULL_FAILURE
            else -> FULL_FAILURE
        }
    }
}
