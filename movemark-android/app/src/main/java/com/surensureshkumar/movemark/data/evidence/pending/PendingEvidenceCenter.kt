package com.surensureshkumar.movemark.data.evidence.pending

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/*
 * MoveMark — the app-wide face of [PendingEvidenceStore] (iOS `PendingEvidenceCenter`): screens call it, it
 * serialises sends per process, and keeps an observable per-user summary for the Proof home's
 * "N photos not uploaded yet" row.
 *
 * Sends and reconciles run in [appScope] (not a screen's scope), so leaving the room mid-save doesn't cancel
 * the save; if the process dies anyway, the photos are still on disk (marked uploading → failed on the next
 * open) and retryable.
 */
/** Schedules the background upload of photos a save couldn't finish (WorkManager in the app; a fake in tests). */
interface PendingUploadScheduler {
    fun schedule(userId: String)
    fun cancel(userId: String)

    object None : PendingUploadScheduler {
        override fun schedule(userId: String) = Unit
        override fun cancel(userId: String) = Unit
    }
}

/** What one background pass left. */
data class PendingUploadReport(val attemptedRooms: Int, val confirmed: Int, val remaining: Int)

class PendingEvidenceCenter(
    val store: PendingEvidenceStore,
    backend: PendingEvidenceBackend,
    private val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val scheduler: PendingUploadScheduler = PendingUploadScheduler.None,
) {
    val sync = PendingEvidenceSync(store, backend)

    /** One send / reconcile at a time: two concurrent syncs of one key could both upload a photo. */
    private val syncLock = Mutex()

    private val _summaries = MutableStateFlow<List<PendingEvidenceRoomSummary>>(emptyList())
    private var summaryUserId: String? = null

    /** Rooms of the signed-in user with photos still only on this phone, newest first. */
    val summaries: StateFlow<List<PendingEvidenceRoomSummary>> = _summaries.asStateFlow()

    suspend fun refresh(userId: String?) {
        if (userId == null) {
            summaryUserId = null
            _summaries.value = emptyList()
            return
        }
        val fresh = store.summaries(userId)
        summaryUserId = userId.lowercase()
        _summaries.value = fresh
    }

    /**
     * Writes new photos to this phone and returns only once they are on disk. A photo is shown as taken only
     * after this returns; if it throws, nothing was kept and the caller shows an error instead.
     */
    suspend fun admit(
        inputs: List<PendingEvidenceInput>,
        key: PendingEvidenceKey,
        roomName: String,
        draft: PendingEvidenceDraft? = null,
    ) = withContext(NonCancellable) {
        store.add(inputs, key, roomName, draft)
        refresh(key.userId)
    }

    suspend fun remove(ids: Collection<String>, key: PendingEvidenceKey) = withContext(NonCancellable) {
        store.remove(ids, key)
        refresh(key.userId)
    }

    suspend fun updateDraft(draft: PendingEvidenceDraft, key: PendingEvidenceKey) = store.updateDraft(draft, key)

    /** Discards the room's unsaved photos, then settles server leftovers in the background. */
    suspend fun discard(key: PendingEvidenceKey) {
        withContext(NonCancellable) { store.clearRoom(key) }
        refresh(key.userId)
        appScope.launch { reconcile(key) }
    }

    /** Sends [key]'s photos in the app scope (survives the screen), then refreshes the summary. */
    suspend fun send(
        key: PendingEvidenceKey,
        onProgress: suspend (index: Int, total: Int) -> Unit = { _, _ -> },
    ): PendingEvidenceSyncResult {
        return appScope.async {
            syncLock.withLock { withContext(io) { sync.sync(key, onProgress) } }.also {
                refresh(key.userId)
                scheduleIfAwaiting(key.userId)
            }
        }.await()
    }

    /**
     * The background pass (PendingUploadWorker): sends every room of [userId] whose save couldn't finish, one at a
     * time under the same lock as on-screen saves. Each send is idempotent (see PendingEvidenceSync), so a pass
     * repeated after a kill or overlapping a screen's retry can't save a photo twice.
     */
    suspend fun sendAwaiting(userId: String): PendingUploadReport {
        val keys = store.manifests(userId).filter(PendingUploadPolicy::awaitingUpload).map { it.key }
        var confirmed = 0
        for (key in keys) {
            val result = syncLock.withLock { withContext(io) { sync.sync(key) } }
            confirmed += result.confirmed
        }
        refresh(userId)
        return PendingUploadReport(attemptedRooms = keys.size, confirmed = confirmed, remaining = awaitingCount(userId))
    }

    /** Photos of [userId] a save asked for that are still only on this phone. */
    suspend fun awaitingCount(userId: String): Int =
        store.manifests(userId).filter(PendingUploadPolicy::awaitingUpload).sumOf { it.items.size }

    private suspend fun scheduleIfAwaiting(userId: String) {
        if (awaitingCount(userId) > 0) scheduler.schedule(userId.lowercase())
    }

    suspend fun reconcile(key: PendingEvidenceKey): PendingEvidenceSync.ReconcileOutcome {
        return appScope.async {
            syncLock.withLock { withContext(io) { sync.reconcile(key) } }.also { refresh(key.userId) }
        }.await()
    }

    /** At launch / sign-in: settles leftovers of every room (interrupted saves, empty entries, uploads to release). */
    fun reconcileAll(userId: String?) {
        appScope.launch {
            if (userId == null) return@launch refresh(null)
            syncLock.withLock { withContext(io) { sync.reconcileAll(userId) } }
            refresh(userId)
            // A save interrupted earlier (offline, or the app stopped mid-upload) finishes in the background.
            scheduleIfAwaiting(userId)
        }
    }

    suspend fun pendingCount(userId: String): Int = store.pendingCount(userId)

    /** Sign-out (after its warning) and account deletion. */
    suspend fun clearUser(userId: String) = withContext(NonCancellable) {
        scheduler.cancel(userId.lowercase())
        syncLock.withLock { store.clearUser(userId) }
        refresh(null)
    }
}
