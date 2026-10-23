package com.surensureshkumar.movemark.data.backend

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Temporary download URLs for files the UI knows by their stored path (iOS `MoveMarkStoredFileURLs` +
 * `MoveMarkSignedURLCache`). The API signs by exact row id after checking the caller owns that row. Rows the
 * app has loaded are [remember]ed, so their paths sign with no lookup; only an unknown path falls back to
 * resolving it to its row (an exact, RLS-scoped match on an indexed column). The URL is transport only —
 * the row stays the file's identity.
 */
class StoredFileUrls(
    private val postgrest: PostgrestClient,
    private val storage: MoveMarkStorageService,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    @Serializable
    private data class FileRef(
        val id: String,
        @SerialName("file_path") val filePath: String? = null,
        @SerialName("thumbnail_path") val thumbnailPath: String? = null,
    )

    private class Cached(val url: String, val expiresAtMillis: Long)

    private val lock = Mutex()
    private val knownRows = HashMap<String, FileRef>()
    private val cache = HashMap<String, Cached>()

    /** A row the app loaded (hydration, history pages, vault summary, maintenance, documents). */
    suspend fun remember(rowId: String, filePath: String?, thumbnailPath: String?) = lock.withLock {
        val ref = FileRef(rowId.lowercase(), filePath, thumbnailPath)
        filePath?.let { knownRows[it] = ref }
        thumbnailPath?.let { knownRows[it] = ref }
    }

    /** `inspection-media` / `maintenance-media` path from an `evidence_files` row (original or thumbnail). */
    suspend fun evidenceUrl(path: String): String =
        url("evidence_files", MoveMarkStorageService.DownloadKind.Evidence, path)

    /** Path from a `property_documents` row (original or thumbnail). */
    suspend fun documentUrl(path: String): String =
        url("property_documents", MoveMarkStorageService.DownloadKind.Document, path)

    /** Drops cached URLs, e.g. on sign-out. */
    suspend fun clear() = lock.withLock {
        knownRows.clear()
        cache.clear()
    }

    private suspend fun url(table: String, kind: MoveMarkStorageService.DownloadKind, path: String): String {
        val trimmed = path.trim()
        if (trimmed.isEmpty()) throw MoveMarkStorageException.NotFound()
        lock.withLock { cache[trimmed]?.takeIf { it.expiresAtMillis > nowMillis() }?.let { return it.url } }

        val ref = lock.withLock { knownRows[trimmed] } ?: postgrest.select(table, FileRef.serializer()) {
            select("id,file_path,thumbnail_path")
            val quoted = PostgrestQuery.quote(trimmed)
            or("file_path.eq.$quoted,thumbnail_path.eq.$quoted")
            order("id")
            limit(1)
        }.firstOrNull() ?: throw MoveMarkStorageException.NotFound()

        val urls = storage.downloadUrls(kind, listOf(ref.id))[ref.id.lowercase()]
            ?: throw MoveMarkStorageException.NotFound()
        // One request signs both; keep the sibling so the grid and the full-size viewer share it.
        val expires = nowMillis() + CACHE_MILLIS
        lock.withLock {
            ref.filePath?.let { cache[it] = Cached(urls.url, expires) }
            if (ref.thumbnailPath != null && urls.thumbnailUrl != null) cache[ref.thumbnailPath] = Cached(urls.thumbnailUrl, expires)
        }
        return if (ref.thumbnailPath == trimmed && urls.thumbnailUrl != null) urls.thumbnailUrl else urls.url
    }

    private companion object {
        /** Signed for an hour by the API; reuse for well under that so a URL never expires mid-download. */
        const val CACHE_MILLIS = 45 * 60 * 1000L
    }
}
