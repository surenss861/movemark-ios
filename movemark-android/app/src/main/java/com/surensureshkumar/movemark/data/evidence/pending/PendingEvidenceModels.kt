package com.surensureshkumar.movemark.data.evidence.pending

import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/*
 * MoveMark — the on-device pending set's data (iOS `PendingEvidenceStore.swift` types). Ids are stored as
 * lowercase UUID strings so manifests are plain JSON and compatible across versions.
 */

/** One room's pending set: per user, per rental, per room, per phase (and per entry for Add photos). */
@Serializable
data class PendingEvidenceKey(
    val userId: String,
    val propertyId: String,
    val roomId: String,
    val stage: Stage,
    /** Photos for an entry that already exists (Add photos); null for the room's new entry. */
    val appendTo: String? = null,
) {
    @Serializable
    enum class Stage {
        @SerialName("move-in") MoveIn,
        @SerialName("move-out") MoveOut,
        ;

        val folderName: String get() = if (this == MoveIn) "move-in" else "move-out"
    }

    /** The room's new-entry set this key belongs to. */
    val base: PendingEvidenceKey get() = copy(appendTo = null)

    companion object {
        fun of(userId: UUID, propertyId: UUID, roomId: UUID, moveOut: Boolean, appendTo: UUID? = null) =
            PendingEvidenceKey(
                userId = userId.toString().lowercase(),
                propertyId = propertyId.toString().lowercase(),
                roomId = roomId.toString().lowercase(),
                stage = if (moveOut) Stage.MoveOut else Stage.MoveIn,
                appendTo = appendTo?.toString()?.lowercase(),
            )
    }
}

/** The new-entry fields typed before saving; restored with the photos. */
@Serializable
data class PendingEvidenceDraft(
    val title: String = "",
    val notes: String = "",
    val tags: List<String> = emptyList(),
    /** 1 Poor … 5 Excellent (default Good, as on iOS). */
    val conditionRating: Int = 4,
)

/** An upload whose fate was unknown when a save ended; settled before the photo is uploaded again. */
@Serializable
data class PendingEvidenceUpload(
    val ticketId: String,
    val bucket: String,
    val path: String,
    val thumbnailPath: String? = null,
    val sourcePath: String? = null,
    val capturedAt: String? = null,
) {
    fun toMoveMarkUpload() = MoveMarkUpload(ticketId, bucket, path, thumbnailPath, sourcePath, capturedAt)

    companion object {
        fun of(upload: MoveMarkUpload) = PendingEvidenceUpload(
            upload.ticketId, upload.bucket, upload.path, upload.thumbnailPath, upload.sourcePath, upload.capturedAt,
        )
    }
}

@Serializable
data class PendingEvidenceItem(
    /** Also the `evidence_files` row id used for every attempt at this photo. */
    val id: String,
    /** The source file's name inside the room folder. */
    val fileName: String,
    val mimeType: String,
    val fileExtension: String,
    val byteCount: Int,
    val sha256Hex: String,
    val pixelWidth: Int,
    val pixelHeight: Int,
    /** The file's own (EXIF) capture time, when it declares one. */
    val capturedAt: String? = null,
    /** Epoch millis when it joined the pending set on this phone. */
    val addedAt: Long,
    /** `camera` / `library`. */
    val captureSource: String,
    val status: Status = Status.Pending,
    val unresolved: PendingEvidenceUpload? = null,
) {
    @Serializable
    enum class Status {
        /** On this phone, not sent yet. */
        @SerialName("pending") Pending,

        /** A save was sending it. Found in this state at launch, the app was stopped mid-save. */
        @SerialName("uploading") Uploading,

        /** The last attempt didn't confirm it; it needs a retry. */
        @SerialName("failed") Failed,
    }
}

@Serializable
data class PendingEvidenceManifest(
    val version: Int = CURRENT_VERSION,
    val key: PendingEvidenceKey,
    val roomName: String,
    val draft: PendingEvidenceDraft = PendingEvidenceDraft(),
    /** Set once a save chose the entry id: the remaining photos join it (a partial save's retry). */
    val entryId: String? = null,
    val savedCount: Int = 0,
    val requestedCount: Int = 0,
    val items: List<PendingEvidenceItem> = emptyList(),
    val updatedAt: Long = 0,
    /** Uploads of photos dropped while their outcome was unknown: released by the next reconcile. */
    val cleanup: List<PendingEvidenceUpload> = emptyList(),
) {
    val failedCount: Int get() = items.count { it.status != PendingEvidenceItem.Status.Pending }

    /** No photos left, but the server may still hold something of this room to settle. */
    val needsServerCleanup: Boolean
        get() = items.isEmpty() && (cleanup.isNotEmpty() || (key.appendTo == null && entryId != null && savedCount == 0))

    companion object {
        const val CURRENT_VERSION = 1
    }
}

/** What the Proof home needs to point at a room with photos still on the phone. */
data class PendingEvidenceRoomSummary(
    val key: PendingEvidenceKey,
    val roomName: String,
    val count: Int,
    val failedCount: Int,
    val updatedAt: Long,
)

/** A photo to add: its row id for every attempt, and its source evidence. */
data class PendingEvidenceInput(val id: UUID, val source: EvidenceSource)

data class PendingEvidenceRestoredItem(val item: PendingEvidenceItem, val source: EvidenceSource)

data class PendingEvidenceRestore(val manifest: PendingEvidenceManifest, val items: List<PendingEvidenceRestoredItem>)
