package com.surensureshkumar.movemark.data.evidence.pending

import android.util.Log
import com.surensureshkumar.movemark.data.backend.AbandonResult
import com.surensureshkumar.movemark.data.backend.MoveMarkStorageService
import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import com.surensureshkumar.movemark.data.property.InspectionRepository
import kotlinx.coroutines.CancellationException
import java.util.UUID

/** The app's backend for [PendingEvidenceSync]: MoveMark API storage tickets + Data API rows. */
class LivePendingEvidenceBackend(
    private val repo: InspectionRepository,
    private val storage: MoveMarkStorageService,
) : PendingEvidenceBackend {

    override suspend fun ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft): Boolean {
        val inspectionId = repo.upsertInspection(
            UUID.fromString(key.propertyId),
            UUID.fromString(key.userId),
            if (key.stage == PendingEvidenceKey.Stage.MoveOut) "move_out" else "move_in",
        )
        repo.ensureInspectionItem(
            id = id,
            inspectionId = inspectionId,
            roomId = UUID.fromString(key.roomId),
            notes = "$title\n${draft.notes.trim()}",
            conditionRating = draft.conditionRating,
        )
        if (draft.tags.isEmpty()) return false
        return try {
            // Replace, so a repeated create never duplicates tag links.
            repo.deleteItemTags(id)
            repo.insertItemTags(id, draft.tags)
            false
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e("MoveMarkUpload", "tags failed after entry create (entry kept)", e)
            true
        }
    }

    override suspend fun entryPhotoIds(entryId: UUID): Set<UUID>? = repo.evidenceFileIds(entryId)

    override suspend fun deleteEntry(id: UUID) = repo.deleteInspectionItem(id)

    override suspend fun upload(
        source: EvidenceSource,
        key: PendingEvidenceKey,
        onTicket: suspend (MoveMarkUpload) -> Unit,
    ): MoveMarkUpload = storage.uploadEvidence(
        repo.prepare(source),
        key.propertyId,
        key.roomId,
        isMoveOut = key.stage == PendingEvidenceKey.Stage.MoveOut,
        onTicket = onTicket,
    )

    override suspend fun insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload) =
        repo.insertEvidenceFile(rowId, UUID.fromString(key.propertyId), entryId, null, upload)

    override suspend fun abandon(upload: MoveMarkUpload): AbandonResult = storage.abandon(upload)
}
