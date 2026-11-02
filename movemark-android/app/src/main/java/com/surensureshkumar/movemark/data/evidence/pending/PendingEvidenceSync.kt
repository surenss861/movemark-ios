package com.surensureshkumar.movemark.data.evidence.pending

import com.surensureshkumar.movemark.data.backend.AbandonResult
import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.backend.MoveMarkUploadFailure
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import kotlinx.coroutines.CancellationException
import java.io.IOException
import java.util.UUID

/*
 * MoveMark — sends a room's photos from [PendingEvidenceStore] to the server so that a kill at any moment
 * loses nothing and duplicates nothing (iOS `PendingEvidenceSync`). Everything that will exist on the server
 * is written to this phone first:
 *
 * 1. The entry id is chosen on the phone and written to the manifest before the entry is created; the create
 *    is idempotent (an existing row with that id is reused). A kill right after the create leaves the id
 *    behind, so the next attempt completes that entry, or [reconcile] removes it when it holds no photo and
 *    nothing is left to send.
 * 2. Each photo's upload ticket is written before its bytes are sent (and again once finalized). A kill
 *    mid-upload leaves the ticket behind; the next attempt releases it first (`abandon`): `Kept` means its row
 *    committed (the photo is saved), `Deleted` means it is safe to upload again.
 * 3. Each photo keeps one `evidence_files` row id for every attempt, so a second insert can only conflict.
 * 4. A photo leaves the phone only when its row is confirmed — by the insert, by `abandon` answering `Kept`,
 *    or by the entry's rows on the server listing its id.
 */

/** The server side of a sync (MoveMark API + Data API in the app; a fake in tests). */
interface PendingEvidenceBackend {
    /** Creates the entry with this id, or reuses the row if it exists. Returns true when only the tags failed. */
    suspend fun ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft): Boolean

    /** The entry's `evidence_files` row ids; null when the entry doesn't exist. Throws when the server can't be asked. */
    suspend fun entryPhotoIds(entryId: UUID): Set<UUID>?

    suspend fun deleteEntry(id: UUID)

    /** Ticket → PUTs → finalize. [onTicket] runs before any byte is sent. */
    suspend fun upload(source: EvidenceSource, key: PendingEvidenceKey, onTicket: suspend (MoveMarkUpload) -> Unit): MoveMarkUpload

    suspend fun insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload)

    suspend fun abandon(upload: MoveMarkUpload): AbandonResult
}

data class PendingEvidenceSyncResult(
    val entryId: UUID? = null,
    /** Photos confirmed by this run, in order. */
    val saved: List<EvidencePhoto> = emptyList(),
    /** Photos an earlier, interrupted attempt had in fact saved (found on the server). */
    val alreadySaved: Int = 0,
    /** What is still on this phone for the key, for the retry. */
    val pending: List<PendingEvidenceRestoredItem> = emptyList(),
    /** Entry totals across attempts (for "2 of 3 photos saved"). */
    val savedTotal: Int = 0,
    val requestedTotal: Int = 0,
    val insertFailures: Int = 0,
    val tagsFailed: Boolean = false,
    /** No photo could be saved, so the empty entry was removed again. */
    val entryRemoved: Boolean = false,
    val failure: Failure? = null,
    val priorSaved: Int = 0,
    /** The last error a photo hit, for the user-facing message. */
    val lastError: Throwable? = null,
) {
    sealed class Failure {
        /** The server couldn't be reached to create or check the entry; nothing was sent. */
        data class Unreachable(val error: Throwable) : Failure()

        /** The Add photos target no longer exists; its photos moved to the room's new-entry set. */
        data object EntryMissing : Failure()
    }

    val isComplete: Boolean get() = pending.isEmpty() && failure == null
    val confirmed: Int get() = saved.size + alreadySaved

    /** Nothing was saved and no entry holds anything of it: the photos stay in the form as they were. */
    val nothingLinked: Boolean get() = savedTotal == 0 && pending.all { it.item.unresolved == null }
}

class PendingEvidenceSync(
    private val store: PendingEvidenceStore,
    private val backend: PendingEvidenceBackend,
    private val newId: () -> String = { UUID.randomUUID().toString() },
) {
    /**
     * Sends everything pending for [key]. Safe to call again at any point (after a failure, a relaunch, a kill
     * mid-way): it settles what an earlier attempt left before sending anything new.
     */
    suspend fun sync(
        key: PendingEvidenceKey,
        onProgress: suspend (index: Int, total: Int) -> Unit = { _, _ -> },
    ): PendingEvidenceSyncResult {
        var result = PendingEvidenceSyncResult()
        store.settleInterrupted(key)
        releaseQueued(key)
        val manifest = store.manifest(key)
        if (manifest == null || manifest.items.isEmpty()) return finish(result, key)
        result = result.copy(priorSaved = manifest.savedCount)
        val hadEntry = manifest.entryId != null || key.appendTo != null
        val entryId = runCatching { store.beginEntry(key, newId) }.getOrNull()?.let(UUID::fromString)
            ?: return finish(result.copy(failure = PendingEvidenceSyncResult.Failure.Unreachable(IOException("pending store"))), key)
        result = result.copy(entryId = entryId)

        // An earlier attempt may have got further than this phone recorded.
        if (hadEntry) {
            try {
                val onServer = backend.entryPhotoIds(entryId)
                if (onServer != null) {
                    val saved = manifest.items.map { it.id }.filter { UUID.fromString(it) in onServer }
                    if (saved.isNotEmpty()) {
                        store.confirm(saved, key)
                        result = result.copy(alreadySaved = saved.size)
                    }
                } else if (key.appendTo != null) {
                    runCatching { store.rehomeToNewEntry(key) }
                    return finish(result.copy(failure = PendingEvidenceSyncResult.Failure.EntryMissing), key)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                store.markFailed(manifest.items.map { it.id }, key)
                return finish(result.copy(failure = PendingEvidenceSyncResult.Failure.Unreachable(e), lastError = e), key)
            }
        }
        val current = store.manifest(key)
        if (current == null || current.items.isEmpty()) return finish(result, key)

        if (key.appendTo == null) {
            val title = current.draft.title.trim().ifEmpty { current.roomName }
            try {
                result = result.copy(tagsFailed = backend.ensureEntry(entryId, key, title, current.draft))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                store.markFailed(current.items.map { it.id }, key)
                return finish(result.copy(failure = PendingEvidenceSyncResult.Failure.Unreachable(e), lastError = e), key)
            }
        }

        store.markUploading(current.items.map { it.id }, key)
        for ((index, item) in current.items.withIndex()) {
            onProgress(index + 1, current.items.size)
            val (photo, outcome) = send(item, entryId, key)
            result = result.copy(
                saved = if (photo != null) result.saved + photo else result.saved,
                insertFailures = result.insertFailures + if (outcome.insertFailed) 1 else 0,
                lastError = outcome.error ?: result.lastError,
            )
        }

        // Nothing of this new entry saved and nothing outstanding: remove the empty entry again (the next attempt
        // recreates it under the same id). Only when the server confirms it holds no photo.
        if (key.appendTo == null && result.saved.isEmpty() && result.alreadySaved == 0) {
            val left = store.manifest(key)
            if (left != null && left.savedCount == 0 && left.items.all { it.unresolved == null } &&
                runCatching { backend.entryPhotoIds(entryId) }.getOrNull()?.isEmpty() == true &&
                runCatching { backend.deleteEntry(entryId) }.isSuccess
            ) {
                result = result.copy(entryRemoved = true)
            }
        }
        return finish(result, key)
    }

    private data class SendOutcome(val insertFailed: Boolean = false, val error: Throwable? = null)

    /** One photo: settle an earlier upload, upload (ticket recorded first), insert, confirm. */
    private suspend fun send(item: PendingEvidenceItem, entryId: UUID, key: PendingEvidenceKey): Pair<EvidencePhoto?, SendOutcome> {
        item.unresolved?.let { earlier ->
            when (backend.abandon(earlier.toMoveMarkUpload())) {
                // Its row committed last time; only the response (or the app) was lost.
                AbandonResult.Kept -> {
                    store.confirm(listOf(item.id), key)
                    return photo(item.id, earlier.toMoveMarkUpload()) to SendOutcome()
                }
                AbandonResult.Deleted -> store.setUnresolved(null, item.id, key)
                // Still unknown: uploading again could duplicate it.
                AbandonResult.Failed -> {
                    store.markFailed(listOf(item.id), key)
                    return null to SendOutcome()
                }
            }
        }
        val source = store.source(key, item) ?: run {
            store.markFailed(listOf(item.id), key)
            return null to SendOutcome()
        }

        val upload = try {
            backend.upload(source, key) { ticket -> store.setUnresolved(PendingEvidenceUpload.of(ticket), item.id, key) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // The storage service released the ticket unless it says otherwise.
            store.setUnresolved((e as? MoveMarkUploadFailure)?.unreleased?.let(PendingEvidenceUpload::of), item.id, key)
            store.markFailed(listOf(item.id), key)
            return null to SendOutcome(error = e)
        }
        store.setUnresolved(PendingEvidenceUpload.of(upload), item.id, key)

        return try {
            backend.insertPhoto(UUID.fromString(item.id), entryId, key, upload)
            store.confirm(listOf(item.id), key)
            photo(item.id, upload) to SendOutcome()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            when (backend.abandon(upload)) {
                AbandonResult.Kept -> {
                    store.confirm(listOf(item.id), key)
                    return photo(item.id, upload) to SendOutcome(insertFailed = true)
                }
                AbandonResult.Deleted -> {
                    store.setUnresolved(null, item.id, key)
                    store.markFailed(listOf(item.id), key)
                }
                AbandonResult.Failed -> store.markFailed(listOf(item.id), key)
            }
            null to SendOutcome(insertFailed = true, error = e)
        }
    }

    private suspend fun finish(result: PendingEvidenceSyncResult, key: PendingEvidenceKey): PendingEvidenceSyncResult {
        val manifest = store.manifest(key)
        val pending = manifest?.items.orEmpty().mapNotNull { item ->
            store.source(key, item)?.let { PendingEvidenceRestoredItem(item, it) }
        }
        val savedTotal = maxOf(manifest?.savedCount ?: 0, result.priorSaved + result.alreadySaved + result.saved.size)
        return result.copy(
            pending = pending,
            savedTotal = savedTotal,
            requestedTotal = maxOf(manifest?.requestedCount ?: 0, savedTotal + pending.size),
            entryId = result.entryId ?: manifest?.entryId?.let(UUID::fromString),
        )
    }

    sealed class ReconcileOutcome {
        /** Nothing pending or to settle. */
        data object Nothing : ReconcileOutcome()

        /** The server couldn't be asked; everything stays as it was. */
        data object Unknown : ReconcileOutcome()

        /** Checked: [alreadySaved] photos were in fact saved; [remaining] still need sending. */
        data class Checked(val alreadySaved: Int, val remaining: Int) : ReconcileOutcome()

        /** The Add photos target is gone; its photos are now the room's new-entry set. */
        data object Rehomed : ReconcileOutcome()
    }

    /**
     * Settles what an earlier visit or an interrupted save left, without sending any photo: releases queued
     * uploads, confirms photos whose rows exist, removes an entry that ended up empty with nothing left to send.
     */
    suspend fun reconcile(key: PendingEvidenceKey): ReconcileOutcome {
        store.settleInterrupted(key)
        releaseQueued(key)
        val manifest = store.manifest(key) ?: return ReconcileOutcome.Nothing
        val entryId = manifest.entryId?.let(UUID::fromString)
            ?: return if (manifest.items.isEmpty()) ReconcileOutcome.Nothing else ReconcileOutcome.Checked(0, manifest.items.size)
        val onServer = try {
            backend.entryPhotoIds(entryId)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            return ReconcileOutcome.Unknown
        }
        if (onServer == null) {
            if (key.appendTo != null && manifest.items.isNotEmpty()) {
                runCatching { store.rehomeToNewEntry(key) }
                return ReconcileOutcome.Rehomed
            }
            // Never created (or emptied and removed): a later save recreates it under the same id.
            if (manifest.items.isEmpty()) store.entrySettled(key, savedOnServer = 0)
            return ReconcileOutcome.Checked(0, manifest.items.size)
        }
        val saved = manifest.items.map { it.id }.filter { UUID.fromString(it) in onServer }
        if (saved.isNotEmpty()) store.confirm(saved, key)
        val remaining = manifest.items.size - saved.size
        if (remaining == 0 && key.appendTo == null) {
            if (onServer.isEmpty()) {
                // Created, then the app stopped (or the renter discarded the photos) before any photo landed.
                if (runCatching { backend.deleteEntry(entryId) }.isFailure) return ReconcileOutcome.Unknown
            }
            store.entrySettled(key, savedOnServer = onServer.size)
        }
        return ReconcileOutcome.Checked(saved.size, remaining)
    }

    /** Reconciles every room of [userId] that has something on this phone. */
    suspend fun reconcileAll(userId: String) {
        for (manifest in store.manifests(userId)) {
            runCatching { reconcile(manifest.key) }
        }
    }

    /** Releases uploads of photos the renter dropped while their outcome was unknown. */
    private suspend fun releaseQueued(key: PendingEvidenceKey) {
        val queued = store.manifest(key)?.cleanup.orEmpty()
        for (upload in queued) {
            if (backend.abandon(upload.toMoveMarkUpload()) != AbandonResult.Failed) store.dropCleanup(upload, key)
        }
    }

    private fun photo(id: String, upload: MoveMarkUpload) =
        EvidencePhoto(id = UUID.fromString(id), filePath = upload.path, thumbnailPath = upload.thumbnailPath)
}
