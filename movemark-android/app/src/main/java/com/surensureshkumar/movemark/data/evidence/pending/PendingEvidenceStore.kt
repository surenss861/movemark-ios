package com.surensureshkumar.movemark.data.evidence.pending

import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceFormats
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/*
 * MoveMark — evidence photos that exist only on this phone so far (iOS `PendingEvidenceStore`). Every photo
 * shot or picked for a room is written here at once (its original bytes, untouched) so a crash, a process
 * kill or a lost upload never loses it. An item leaves only once the server has confirmed its
 * `evidence_files` row (or the renter explicitly removes it, signs out after a warning, or deletes the
 * account).
 *
 * Layout (app-private `filesDir`, never cleared by the system like `cacheDir`, excluded from backups):
 *
 *     PendingEvidence/v1/<userId>/<propertyId>/<roomId>-<move-in|move-out>[-add-<entryId>]/
 *         manifest.json      what is pending, its status, the entry draft
 *         <itemId>.<ext>     the source file exactly as the camera / picker supplied it
 *
 * A photo file is written (and synced) before the manifest names it, and the manifest drops an item before
 * its file is deleted, so the manifest never points at a missing file; files it doesn't name are swept on
 * restore. Manifests are replaced atomically (temp file + fsync + rename).
 *
 * What reaches the server is recorded before it is sent (see [PendingEvidenceSync]): the entry id is chosen
 * and written here before the entry is created, and each upload's ticket before its bytes are sent.
 */
class PendingEvidenceStore(
    val root: File,
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val lock = Mutex()

    private suspend fun <T> locked(block: () -> T): T = lock.withLock { withContext(io) { block() } }

    // ---- Paths ----

    fun userFolder(userId: String): File = File(root, userId.lowercase())

    fun roomFolder(key: PendingEvidenceKey): File {
        var name = "${key.roomId.lowercase()}-${key.stage.folderName}"
        key.appendTo?.let { name += "-add-${it.lowercase()}" }
        return File(File(userFolder(key.userId), key.propertyId.lowercase()), name)
    }

    fun fileFor(key: PendingEvidenceKey, item: PendingEvidenceItem): File = File(roomFolder(key), item.fileName)

    private fun manifestFile(key: PendingEvidenceKey) = File(roomFolder(key), MANIFEST)

    // ---- Reads ----

    suspend fun manifest(key: PendingEvidenceKey): PendingEvidenceManifest? = locked { readManifest(key) }

    /**
     * The room's pending photos with their source bytes. Items whose file is missing or no longer matches its
     * recorded hash are dropped from the manifest (never shown as if intact); files the manifest doesn't name
     * are swept.
     */
    suspend fun restore(key: PendingEvidenceKey): PendingEvidenceRestore? = locked {
        var manifest = readManifest(key) ?: return@locked null
        val restored = mutableListOf<PendingEvidenceRestoredItem>()
        val kept = mutableListOf<PendingEvidenceItem>()
        for (item in manifest.items) {
            val source = readSource(key, item) ?: continue
            kept += item
            restored += PendingEvidenceRestoredItem(item, source)
        }
        if (kept.size != manifest.items.size) {
            manifest = manifest.copy(items = kept)
            runCatching { writeManifest(manifest) }
        }
        sweepOrphans(key, manifest)
        if (manifest.items.isEmpty()) {
            if (!manifest.needsServerCleanup) removeFolder(key)
            return@locked null
        }
        PendingEvidenceRestore(manifest, restored)
    }

    /** The item's source evidence from its file, or null when the file is missing or no longer matches its hash. */
    suspend fun source(key: PendingEvidenceKey, item: PendingEvidenceItem): EvidenceSource? = locked { readSource(key, item) }

    /** Every manifest of [userId] on this phone, including rooms waiting only for server cleanup. */
    suspend fun manifests(userId: String): List<PendingEvidenceManifest> = locked { readManifests(userId) }

    /** Every room of [userId] with photos still on this phone, newest first. */
    suspend fun summaries(userId: String): List<PendingEvidenceRoomSummary> = locked {
        readManifests(userId)
            .filter { it.items.isNotEmpty() }
            .map { PendingEvidenceRoomSummary(it.key, it.roomName, it.items.size, it.failedCount, it.updatedAt) }
            .sortedByDescending { it.updatedAt }
    }

    suspend fun pendingCount(userId: String): Int = summaries(userId).sumOf { it.count }

    // ---- Writes ----

    /** Writes each photo's original bytes, then records it. Photos already in the room (same id) are skipped. */
    suspend fun add(
        inputs: List<PendingEvidenceInput>,
        key: PendingEvidenceKey,
        roomName: String,
        draft: PendingEvidenceDraft? = null,
    ) = locked {
        if (inputs.isEmpty()) return@locked
        var manifest = readManifest(key) ?: PendingEvidenceManifest(key = key, roomName = roomName)
        manifest = manifest.copy(roomName = roomName, draft = draft ?: manifest.draft)
        ensureFolder(key)
        val known = manifest.items.map { it.id }.toMutableSet()
        val added = mutableListOf<PendingEvidenceItem>()
        for (input in inputs) {
            val id = input.id.toString().lowercase()
            if (!known.add(id)) continue
            val source = input.source
            val item = PendingEvidenceItem(
                id = id,
                fileName = "$id.${source.fileExtension}",
                mimeType = source.mimeType,
                fileExtension = source.fileExtension,
                byteCount = source.data.size,
                sha256Hex = source.sha256Hex,
                pixelWidth = source.pixelWidth,
                pixelHeight = source.pixelHeight,
                capturedAt = source.capturedAt,
                addedAt = clock(),
                captureSource = source.captureSource.raw,
            )
            atomicWrite(fileFor(key, item), source.data)
            added += item
        }
        writeManifest(manifest.copy(items = manifest.items + added))
    }

    /** The renter removed these photos before they were saved. An unknown upload of theirs is queued for release. */
    suspend fun remove(ids: Collection<String>, key: PendingEvidenceKey) = locked { drop(ids.lower(), key, confirmed = false) }

    /** The server confirmed these photos' rows: they leave this phone and count as saved. */
    suspend fun confirm(ids: Collection<String>, key: PendingEvidenceKey) = locked { drop(ids.lower(), key, confirmed = true) }

    /** Records the upload a photo is in the middle of (before its bytes are sent), or clears it once settled. */
    suspend fun setUnresolved(upload: PendingEvidenceUpload?, id: String, key: PendingEvidenceKey) = locked {
        val manifest = readManifest(key) ?: return@locked
        val index = manifest.items.indexOfFirst { it.id == id.lowercase() }
        if (index < 0 || manifest.items[index].unresolved == upload) return@locked
        writeManifest(manifest.copy(items = manifest.items.replaced(index) { it.copy(unresolved = upload) }))
    }

    /**
     * The entry this room's photos go to: the Add photos target, the one an earlier attempt chose, or a new
     * id — written to disk here, before the entry is created, so a kill right after the create still leaves
     * its id behind. Null when nothing is pending for [key].
     */
    suspend fun beginEntry(key: PendingEvidenceKey, newId: () -> String): String? = locked {
        val manifest = readManifest(key) ?: return@locked null
        manifest.entryId?.let { return@locked it }
        val id = key.appendTo ?: newId().lowercase()
        writeManifest(manifest.copy(entryId = id))
        id
    }

    /** A queued upload was released (or turned out to be referenced by a row). */
    suspend fun dropCleanup(upload: PendingEvidenceUpload, key: PendingEvidenceKey) = locked {
        val manifest = readManifest(key) ?: return@locked
        if (upload !in manifest.cleanup) return@locked
        finishOrWrite(manifest.copy(cleanup = manifest.cleanup - upload))
    }

    /** The room's entry was checked: nothing about it is left to settle. */
    suspend fun entrySettled(key: PendingEvidenceKey, savedOnServer: Int) = locked {
        var manifest = readManifest(key) ?: return@locked
        manifest = manifest.copy(savedCount = maxOf(manifest.savedCount, savedOnServer))
        if (manifest.items.isEmpty() && manifest.savedCount == 0) manifest = manifest.copy(entryId = null)
        finishOrWrite(manifest)
    }

    /** The entry an Add photos set was meant for is gone: its photos become the room's new-entry set. Files are moved. */
    suspend fun rehomeToNewEntry(key: PendingEvidenceKey) = locked {
        if (key.appendTo == null) return@locked
        val manifest = readManifest(key) ?: return@locked
        val target = key.base
        var destination = readManifest(target) ?: PendingEvidenceManifest(key = target, roomName = manifest.roomName)
        ensureFolder(target)
        val known = destination.items.map { it.id }.toSet()
        val moved = mutableListOf<PendingEvidenceItem>()
        for (item in manifest.items) {
            if (item.id in known) continue
            val from = fileFor(key, item)
            val to = fileFor(target, item)
            if (!to.exists() && !from.renameTo(to)) {
                from.copyTo(to, overwrite = false)
            }
            moved += item.copy(status = PendingEvidenceItem.Status.Failed, unresolved = null)
        }
        destination = destination.copy(
            items = destination.items + moved,
            cleanup = destination.cleanup + manifest.cleanup + manifest.items.mapNotNull { it.unresolved },
        )
        writeManifest(destination)
        removeFolder(key)
    }

    suspend fun updateDraft(draft: PendingEvidenceDraft, key: PendingEvidenceKey) = locked {
        val manifest = readManifest(key) ?: return@locked
        if (manifest.draft != draft) runCatching { writeManifest(manifest.copy(draft = draft)) }
    }

    /** A save is starting for these photos. */
    suspend fun markUploading(ids: Collection<String>, key: PendingEvidenceKey) = locked {
        val manifest = readManifest(key) ?: return@locked
        val set = ids.lower()
        writeManifest(
            manifest.copy(
                items = manifest.items.map { if (it.id in set) it.copy(status = PendingEvidenceItem.Status.Uploading) else it },
                requestedCount = maxOf(manifest.requestedCount, manifest.savedCount + manifest.items.size),
            ),
        )
    }

    /** These photos weren't confirmed. [unresolved] records uploads whose fate is unknown; an existing record is kept. */
    suspend fun markFailed(
        ids: Collection<String>,
        key: PendingEvidenceKey,
        unresolved: Map<String, PendingEvidenceUpload> = emptyMap(),
    ) = locked {
        val manifest = readManifest(key) ?: return@locked
        val set = ids.lower()
        writeManifest(
            manifest.copy(
                items = manifest.items.map {
                    if (it.id in set) it.copy(status = PendingEvidenceItem.Status.Failed, unresolved = unresolved[it.id] ?: it.unresolved)
                    else it
                },
            ),
        )
    }

    /** Photos the app was sending when it stopped (found `uploading`) become `failed`. */
    suspend fun settleInterrupted(key: PendingEvidenceKey) = locked {
        val manifest = readManifest(key) ?: return@locked
        if (manifest.items.none { it.status == PendingEvidenceItem.Status.Uploading }) return@locked
        writeManifest(
            manifest.copy(
                items = manifest.items.map {
                    if (it.status == PendingEvidenceItem.Status.Uploading) it.copy(status = PendingEvidenceItem.Status.Failed) else it
                },
            ),
        )
    }

    /** The renter discarded the room's unsaved photos. What may remain on the server stays recorded until reconciled. */
    suspend fun clearRoom(key: PendingEvidenceKey) = locked {
        val manifest = readManifest(key) ?: return@locked removeFolder(key)
        drop(manifest.items.map { it.id }.toSet(), key, confirmed = false)
    }

    /** Sign-out (after its warning) and account deletion: everything this user had pending on this phone. */
    suspend fun clearUser(userId: String) = locked { userFolder(userId).deleteRecursively(); Unit }

    // ---- Internals (call with the lock held) ----

    private fun drop(ids: Set<String>, key: PendingEvidenceKey, confirmed: Boolean) {
        val manifest = readManifest(key) ?: return
        val removed = manifest.items.filter { it.id in ids }
        if (removed.isEmpty()) return
        val next = manifest.copy(
            items = manifest.items.filterNot { it.id in ids },
            savedCount = if (confirmed) manifest.savedCount + removed.size else manifest.savedCount,
            cleanup = if (confirmed) manifest.cleanup else manifest.cleanup + removed.mapNotNull { it.unresolved },
        )
        if (next.items.isEmpty() && !next.needsServerCleanup) {
            removeFolder(key)
            return
        }
        writeManifest(next)
        removed.forEach { fileFor(key, it).delete() }
    }

    private fun readManifest(key: PendingEvidenceKey): PendingEvidenceManifest? = decode(manifestFile(key))

    private fun decode(file: File): PendingEvidenceManifest? {
        if (!file.isFile) return null
        return runCatching { json.decodeFromString(PendingEvidenceManifest.serializer(), file.readText()) }
            .getOrNull()
            ?.takeIf { it.version <= PendingEvidenceManifest.CURRENT_VERSION }
    }

    private fun readManifests(userId: String): List<PendingEvidenceManifest> {
        val out = mutableListOf<PendingEvidenceManifest>()
        val properties = userFolder(userId).listFiles() ?: return out
        for (property in properties) {
            for (room in property.listFiles() ?: continue) {
                val manifest = decode(File(room, MANIFEST)) ?: continue
                if (manifest.key.userId.equals(userId, ignoreCase = true)) out += manifest
            }
        }
        return out
    }

    private fun readSource(key: PendingEvidenceKey, item: PendingEvidenceItem): EvidenceSource? {
        val file = fileFor(key, item)
        if (!file.isFile) return null
        val data = runCatching { file.readBytes() }.getOrNull() ?: return null
        if (data.size != item.byteCount || EvidenceFormats.sha256Hex(data) != item.sha256Hex) return null
        return EvidenceSource(
            data = data,
            mimeType = item.mimeType,
            fileExtension = item.fileExtension,
            pixelWidth = item.pixelWidth,
            pixelHeight = item.pixelHeight,
            sha256Hex = item.sha256Hex,
            capturedAt = item.capturedAt,
            captureSource = EvidenceCaptureSource.entries.firstOrNull { it.raw == item.captureSource }
                ?: EvidenceCaptureSource.Library,
        )
    }

    private fun finishOrWrite(manifest: PendingEvidenceManifest) {
        if (manifest.items.isEmpty() && !manifest.needsServerCleanup) removeFolder(manifest.key) else writeManifest(manifest)
    }

    private fun writeManifest(manifest: PendingEvidenceManifest) {
        ensureFolder(manifest.key)
        val text = json.encodeToString(PendingEvidenceManifest.serializer(), manifest.copy(updatedAt = clock()))
        atomicWrite(manifestFile(manifest.key), text.toByteArray())
    }

    private fun ensureFolder(key: PendingEvidenceKey) {
        val folder = roomFolder(key)
        if (!folder.isDirectory && !folder.mkdirs()) throw IOException("Couldn't create the pending evidence folder.")
    }

    private fun removeFolder(key: PendingEvidenceKey) {
        val folder = roomFolder(key)
        folder.deleteRecursively()
        // Leave no empty property / user folders behind.
        val property = folder.parentFile ?: return
        if (property.list()?.isEmpty() == true) {
            property.delete()
            val user = property.parentFile ?: return
            if (user.list()?.isEmpty() == true) user.delete()
        }
    }

    private fun sweepOrphans(key: PendingEvidenceKey, manifest: PendingEvidenceManifest) {
        val named = manifest.items.map { it.fileName }.toSet() + MANIFEST
        roomFolder(key).listFiles()?.forEach { file ->
            if (file.name !in named && !file.name.startsWith(".")) file.deleteRecursively()
        }
    }

    private fun Collection<String>.lower(): Set<String> = mapTo(mutableSetOf()) { it.lowercase() }

    private inline fun <T> List<T>.replaced(index: Int, transform: (T) -> T): List<T> =
        mapIndexed { i, value -> if (i == index) transform(value) else value }

    companion object {
        private const val MANIFEST = "manifest.json"
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

        fun defaultRoot(filesDir: File): File = File(filesDir, "PendingEvidence/v1")

        /** Writes [data] to a temp file beside [target], syncs it to disk, then renames it into place. */
        internal fun atomicWrite(target: File, data: ByteArray) {
            val temp = File(target.parentFile, ".${target.name}.tmp")
            FileOutputStream(temp).use { out ->
                out.write(data)
                out.flush()
                out.fd.sync()
            }
            if (!temp.renameTo(target)) {
                target.delete()
                if (!temp.renameTo(target)) {
                    temp.delete()
                    throw IOException("Couldn't save ${target.name}.")
                }
            }
        }
    }
}
