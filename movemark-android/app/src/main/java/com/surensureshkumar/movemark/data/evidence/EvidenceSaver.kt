package com.surensureshkumar.movemark.data.evidence

import com.surensureshkumar.movemark.data.backend.AbandonResult
import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.backend.MoveMarkUploadFailure
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import kotlinx.coroutines.CancellationException
import java.util.UUID

/*
 * MoveMark — saving evidence photos one at a time, with an honest result (iOS `MMEvidenceSaver`). A photo
 * counts as saved only once its row is committed; anything else comes back pending so the caller retries
 * exactly those photos and never re-uploads one that already made it.
 *
 * Duplicates are ruled out in two ways: each pending photo keeps one row id for every attempt (a second
 * insert of it can only conflict), and an upload whose fate is unknown — its row insert and its abandon both
 * failed — is settled by abandoning it again before anything is re-uploaded (`Kept` means the row exists:
 * the photo is saved).
 */

/** A photo that isn't confirmed saved yet. */
data class PendingEvidence(
    val source: EvidenceSource,
    /** The `evidence_files` row id used for every attempt at this photo. */
    val rowId: UUID = UUID.randomUUID(),
    /** An earlier upload of this photo that is still outstanding (its abandon didn't get through). */
    val unresolved: MoveMarkUpload? = null,
)

sealed class EvidenceSaveOutcome {
    /** [insertFailed]: its insert reported a failure, but the row turned out to be committed. */
    data class Saved(val photo: EvidencePhoto, val insertFailed: Boolean = false) : EvidenceSaveOutcome()

    /** Retry [item] (and only it). [insertFailed]: it got as far as a verified upload but not a row. */
    data class Pending(val item: PendingEvidence, val error: Throwable?, val insertFailed: Boolean = false) :
        EvidenceSaveOutcome()
}

data class EvidenceSaveResult(
    val saved: List<EvidencePhoto>,
    val pending: List<PendingEvidence>,
    val insertFailures: Int,
) {
    val isComplete: Boolean get() = pending.isEmpty()
}

/**
 * Runs the upload → row insert sequence per photo. [upload] covers ticket, PUTs and finalize (the storage
 * service releases its own half-finished tickets); [insert] writes the row with the given id; [abandon]
 * releases an upload whose row wasn't confirmed.
 */
class EvidenceSaver(
    private val upload: suspend (EvidenceSource) -> MoveMarkUpload,
    private val insert: suspend (rowId: UUID, upload: MoveMarkUpload) -> Unit,
    private val abandon: suspend (MoveMarkUpload) -> AbandonResult,
) {
    suspend fun save(items: List<PendingEvidence>): EvidenceSaveResult {
        val saved = mutableListOf<EvidencePhoto>()
        val pending = mutableListOf<PendingEvidence>()
        var insertFailures = 0
        for (item in items) {
            when (val outcome = saveOne(item)) {
                is EvidenceSaveOutcome.Saved -> {
                    saved += outcome.photo
                    if (outcome.insertFailed) insertFailures++
                }
                is EvidenceSaveOutcome.Pending -> {
                    pending += outcome.item
                    if (outcome.insertFailed) insertFailures++
                }
            }
        }
        return EvidenceSaveResult(saved, pending, insertFailures)
    }

    suspend fun saveOne(original: PendingEvidence): EvidenceSaveOutcome {
        var item = original
        item.unresolved?.let { earlier ->
            when (abandon(earlier)) {
                // Its row committed last time; only the response was lost.
                AbandonResult.Kept -> return EvidenceSaveOutcome.Saved(photo(item.rowId, earlier))
                AbandonResult.Deleted -> item = item.copy(unresolved = null)
                // Still unknown: uploading again could duplicate it.
                AbandonResult.Failed -> return EvidenceSaveOutcome.Pending(item, null)
            }
        }

        val uploaded = try {
            upload(item.source)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return EvidenceSaveOutcome.Pending(item.copy(unresolved = (e as? MoveMarkUploadFailure)?.unreleased), e)
        }

        return try {
            insert(item.rowId, uploaded)
            EvidenceSaveOutcome.Saved(photo(item.rowId, uploaded))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            when (abandon(uploaded)) {
                AbandonResult.Kept -> EvidenceSaveOutcome.Saved(photo(item.rowId, uploaded), insertFailed = true)
                AbandonResult.Deleted -> EvidenceSaveOutcome.Pending(item, e, insertFailed = true)
                AbandonResult.Failed -> EvidenceSaveOutcome.Pending(item.copy(unresolved = uploaded), e, insertFailed = true)
            }
        }
    }

    private fun photo(id: UUID, upload: MoveMarkUpload) =
        EvidencePhoto(id = id, filePath = upload.path, thumbnailPath = upload.thumbnailPath)
}
