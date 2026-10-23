package com.surensureshkumar.movemark.data.backend

import android.util.Log
import com.surensureshkumar.movemark.data.evidence.PreparedEvidence
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/*
 * MoveMark — evidence, maintenance and document files through the MoveMark API (iOS `MoveMarkStorageService`).
 *
 * The app never chooses a bucket or object key and never deletes an object directly:
 * - evidence upload: ask the API for a ticket (it checks ownership and builds the keys) → PUT the immutable
 *   source (its SHA-256 is signed; storage enforces it), the working derivative and the thumbnail → finalize
 *   (the API verifies the stored source) → the caller records the returned paths in its row.
 * - document upload: ticket → PUT → the caller records the returned path.
 *   If that row insert fails, the caller abandons the ticket; the API deletes the objects only when no row
 *   references them, so a row that committed behind a lost response keeps its file.
 * - download: short-lived presigned URLs, requested by row id. A URL is transport, never a file's identity.
 * - delete: by row id; the API removes the objects and the rows together.
 */

/** One uploaded object as the API named it. `path`/`thumbnailPath`/`sourcePath` go into the row. */
data class MoveMarkUpload(
    val ticketId: String,
    val bucket: String,
    /** Working derivative (evidence) or the file itself (documents) — the row's `file_path`. */
    val path: String,
    /** Null when no thumbnail was requested or its (best-effort) upload failed. */
    val thumbnailPath: String?,
    /** The immutable source object, for the row's `source_path`; null for documents. */
    val sourcePath: String? = null,
    /** The source's own capture time, for the row's `captured_at`. */
    val capturedAt: String? = null,
)

/** What [MoveMarkStorageService.abandon] established about an upload. */
enum class AbandonResult {
    /** No row references it; its objects are gone. */
    Deleted,

    /** A row references it: the insert committed even though the app didn't see the response. */
    Kept,

    /** The request didn't get through; the outcome is still unknown. Abandon again later. */
    Failed,
}

/** An evidence upload that failed after its ticket was issued; [unreleased] must be abandoned later. */
class MoveMarkUploadFailure(val underlying: Throwable, val unreleased: MoveMarkUpload?) :
    Exception(underlying.message, underlying)

data class MoveMarkDownloadUrls(val url: String, val thumbnailUrl: String?)

sealed class MoveMarkStorageException(message: String) : Exception(message) {
    class NotConfigured : MoveMarkStorageException("This build is not configured to reach MoveMark’s servers.")
    class NotFound : MoveMarkStorageException("That file isn’t available.")
    class Rejected(val status: Int, val code: String?, serverMessage: String) :
        MoveMarkStorageException(userMessage(status, code, serverMessage))
    class UploadFailed(val status: Int) :
        MoveMarkStorageException("Couldn’t upload the file. Check your connection and try again.")
    class InvalidResponse : MoveMarkStorageException("Couldn’t reach MoveMark. Try again.")

    companion object {
        fun userMessage(status: Int, code: String?, message: String): String = when {
            status == 413 || code == "too_large" -> "This file is too large to upload."
            status == 429 -> "That’s a lot at once. Wait a minute, then try again."
            code == "unsupported_type" -> "This file type isn’t supported."
            else -> message.ifEmpty { "Couldn’t save the file. Try again." }
        }
    }
}

class MoveMarkStorageService(
    private val apiBaseUrl: HttpUrl?,
    private val transport: AuthenticatedTransport,
    /** For presigned URLs: no cookies, no auth header — they carry their own signature. */
    private val objectHttp: OkHttpClient,
) {
    enum class DownloadKind(val raw: String) { Evidence("evidence"), Document("document") }

    private val json = Json { ignoreUnknownKeys = true }

    @Serializable
    private data class Part(val path: String, val url: String, val headers: Map<String, String> = emptyMap())

    @Serializable
    private data class Ticket(
        val uploadTicketId: String,
        val bucket: String,
        val path: String,
        val url: String,
        val headers: Map<String, String> = emptyMap(),
        val thumbnail: Part? = null,
        val source: Part? = null,
        val finalizeRequired: Boolean? = null,
    )

    @Serializable
    private data class Finalized(val status: String, val thumbnail: Boolean? = null)

    // ---- Upload ----

    /** Room evidence: immutable source + working derivative + thumbnail, verified and finalized. */
    suspend fun uploadEvidence(prepared: PreparedEvidence, propertyId: String, roomId: String, isMoveOut: Boolean): MoveMarkUpload =
        uploadSourced(
            prepared,
            mapOf(
                "kind" to "evidence",
                "propertyId" to propertyId.lowercase(),
                "roomId" to roomId.lowercase(),
                "phase" to if (isMoveOut) "move_out" else "move_in",
            ),
        )

    /** Maintenance evidence, same three objects as room evidence. */
    suspend fun uploadMaintenanceEvidence(prepared: PreparedEvidence, propertyId: String, issueId: String): MoveMarkUpload =
        uploadSourced(
            prepared,
            mapOf("kind" to "maintenance", "propertyId" to propertyId.lowercase(), "issueId" to issueId.lowercase()),
        )

    suspend fun uploadDocument(
        data: ByteArray,
        contentType: String,
        thumbnail: ByteArray?,
        propertyId: String,
        documentType: String,
    ): MoveMarkUpload {
        val body = buildJsonObject {
            put("kind", "document")
            put("propertyId", propertyId.lowercase())
            put("documentType", documentType)
            put("contentType", contentType)
            put("size", data.size)
            if (thumbnail != null) put("thumbnailSize", thumbnail.size)
        }
        val ticket = json.decodeOrInvalid(Ticket.serializer(), api("POST", "api/storage/uploads", body))
        try {
            put(data, ticket.url, ticket.headers)
        } catch (e: Throwable) {
            // Nothing references a half-finished upload yet; release the ticket so no orphan stays behind.
            abandon(MoveMarkUpload(ticket.uploadTicketId, ticket.bucket, ticket.path, null))
            throw e
        }
        // The thumbnail is best-effort: grids fall back to the full file when it's missing.
        var thumbnailPath: String? = null
        val part = ticket.thumbnail
        if (thumbnail != null && part != null) {
            try {
                put(thumbnail, part.url, part.headers)
                thumbnailPath = part.path
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "thumbnail PUT failed: ${e.message}")
            }
        }
        return MoveMarkUpload(ticket.uploadTicketId, ticket.bucket, ticket.path, thumbnailPath)
    }

    private suspend fun uploadSourced(prepared: PreparedEvidence, fields: Map<String, String>): MoveMarkUpload {
        val source = prepared.source
        val body = buildJsonObject {
            fields.forEach { (key, value) -> put(key, value) }
            put("contentType", "image/jpeg")
            put("size", prepared.derivative.size)
            prepared.thumbnail?.let { put("thumbnailSize", it.size) }
            put(
                "source",
                buildJsonObject {
                    put("contentType", source.mimeType)
                    put("size", source.data.size)
                    put("sha256", source.sha256Hex)
                    put("width", source.pixelWidth)
                    put("height", source.pixelHeight)
                    put("captureSource", source.captureSource.raw)
                },
            )
        }
        val ticket = json.decodeOrInvalid(Ticket.serializer(), api("POST", "api/storage/uploads", body))
        val sourcePart = ticket.source ?: throw MoveMarkStorageException.InvalidResponse()
        val released = MoveMarkUpload(ticket.uploadTicketId, ticket.bucket, ticket.path, null)

        try {
            put(source.data, sourcePart.url, sourcePart.headers)
            put(prepared.derivative, ticket.url, ticket.headers)
        } catch (e: Throwable) {
            throw release(released, e) // nothing references a half-finished upload yet
        }
        // The thumbnail is best-effort: grids fall back to the derivative when it's missing.
        val thumbPart = ticket.thumbnail
        if (prepared.thumbnail != null && thumbPart != null) {
            try {
                put(prepared.thumbnail, thumbPart.url, thumbPart.headers)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "thumbnail PUT failed: ${e.message}")
            }
        }

        var thumbnailStored = false
        if (ticket.finalizeRequired ?: true) {
            try {
                val finalized = json.decodeOrInvalid(
                    Finalized.serializer(),
                    api("POST", "api/storage/uploads/${ticket.uploadTicketId}/finalize", null),
                )
                thumbnailStored = finalized.thumbnail == true
            } catch (e: Throwable) {
                throw release(released, e)
            }
        }
        return MoveMarkUpload(
            ticketId = ticket.uploadTicketId,
            bucket = ticket.bucket,
            path = ticket.path,
            thumbnailPath = if (thumbnailStored) thumbPart?.path else null,
            sourcePath = sourcePart.path,
            capturedAt = source.capturedAt,
        )
    }

    /** PUT exactly the bytes and headers the ticket signed — no auth header, nothing else. */
    private suspend fun put(data: ByteArray, url: String, headers: Map<String, String>) {
        val builder = Request.Builder().url(url)
        headers.forEach { (name, value) -> builder.header(name, value) }
        val contentType = headers.entries.firstOrNull { it.key.equals("Content-Type", ignoreCase = true) }?.value
        builder.put(data.toRequestBody(contentType?.toMediaType()))
        val response = try {
            objectHttp.send(builder.build())
        } catch (e: IllegalArgumentException) {
            throw MoveMarkStorageException.InvalidResponse()
        }
        if (!response.isSuccessful) throw MoveMarkStorageException.UploadFailed(response.code)
    }

    /**
     * Call when the row insert for [upload] failed. Safe to call when unsure whether it committed: the API keeps
     * any object a row references ([AbandonResult.Kept]). Idempotent, so a [AbandonResult.Failed] abandon can be
     * repeated later (within the ticket's 24 h lifetime) to settle the upload either way.
     */
    suspend fun abandon(upload: MoveMarkUpload): AbandonResult = try {
        val body = api("POST", "api/storage/uploads/${upload.ticketId}/abandon", null)
        val status = json.parseToJsonElement(body).jsonObject["status"]?.jsonPrimitive?.contentOrNull
        Log.i(TAG, "abandoned upload ticket status=$status")
        if (status == "kept") AbandonResult.Kept else AbandonResult.Deleted
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.e(TAG, "abandon failed: ${e.message}")
        AbandonResult.Failed
    }

    /** Releases a half-finished evidence upload; the error says whether its ticket is still outstanding. */
    private suspend fun release(upload: MoveMarkUpload, error: Throwable): MoveMarkUploadFailure {
        if (error is CancellationException) throw error
        val result = abandon(upload)
        return MoveMarkUploadFailure(error, unreleased = if (result == AbandonResult.Failed) upload else null)
    }

    // ---- Download ----

    /**
     * Fresh presigned URLs for rows the caller owns, keyed by lowercase row id. A row the caller can't see makes
     * the whole request fail ([MoveMarkStorageException.NotFound]).
     */
    suspend fun downloadUrls(kind: DownloadKind, ids: List<String>): Map<String, MoveMarkDownloadUrls> {
        val result = mutableMapOf<String, MoveMarkDownloadUrls>()
        for (batch in ids.map { it.lowercase() }.distinct().chunked(BATCH)) {
            val body = buildJsonObject {
                put("kind", kind.raw)
                put("ids", JsonArray(batch.map(::JsonPrimitive)))
            }
            val items = runCatching {
                json.parseToJsonElement(api("POST", "api/storage/downloads", body)).jsonObject["items"] as JsonArray
            }.getOrElse { if (it is MoveMarkStorageException) throw it else throw MoveMarkStorageException.InvalidResponse() }
            for (item in items) {
                val obj = item.jsonObject
                val id = obj["id"]?.jsonPrimitive?.contentOrNull?.lowercase() ?: continue
                val url = obj["url"]?.jsonPrimitive?.contentOrNull ?: continue
                result[id] = MoveMarkDownloadUrls(url, obj["thumbnailUrl"]?.jsonPrimitive?.contentOrNull)
            }
        }
        return result
    }

    // ---- Delete ----

    /** Deletes rows and their files server-side. Rows already gone are not an error, so a retry is safe. */
    suspend fun deleteEvidence(ids: List<String>) = delete("api/storage/evidence", ids)

    suspend fun deleteDocuments(ids: List<String>) = delete("api/storage/documents", ids)

    private suspend fun delete(path: String, ids: List<String>) {
        for (batch in ids.map { it.lowercase() }.distinct().chunked(BATCH)) {
            try {
                api("DELETE", path, idsBody(batch))
            } catch (e: MoveMarkStorageException.NotFound) {
                if (batch.size == 1) continue
                // The API is all-or-nothing per request; one already-deleted row hides the rest. Go one by one.
                for (id in batch) {
                    try {
                        api("DELETE", path, idsBody(listOf(id)))
                    } catch (_: MoveMarkStorageException.NotFound) {
                        continue
                    }
                }
            }
        }
    }

    private fun idsBody(ids: List<String>) = buildJsonObject { put("ids", JsonArray(ids.map(::JsonPrimitive))) }

    // ---- HTTP ----

    private suspend fun api(method: String, path: String, body: JsonObject?): String {
        val base = apiBaseUrl ?: throw MoveMarkStorageException.NotConfigured()
        val requestBody = body?.toString()?.toRequestBody(JSON_MEDIA)
        val request = Request.Builder()
            .url(base.resolvePath(path))
            .method(method, requestBody ?: if (method == "POST") ByteArray(0).toRequestBody(null) else null)
            .build()
        val response = transport.execute(request)
        if (response.code == 404) throw MoveMarkStorageException.NotFound()
        if (!response.isSuccessful) {
            val err = runCatching { json.parseToJsonElement(response.bodyString()).jsonObject }.getOrNull()
            throw MoveMarkStorageException.Rejected(
                status = response.code,
                code = err?.get("code")?.jsonPrimitive?.contentOrNull,
                serverMessage = err?.get("error")?.jsonPrimitive?.contentOrNull.orEmpty(),
            )
        }
        return response.bodyString()
    }

    private fun <T> Json.decodeOrInvalid(deserializer: kotlinx.serialization.DeserializationStrategy<T>, body: String): T =
        try {
            decodeFromString(deserializer, body)
        } catch (_: Exception) {
            throw MoveMarkStorageException.InvalidResponse()
        }

    private companion object {
        const val TAG = "MoveMarkStorage"
        const val BATCH = 100
        val JSON_MEDIA = "application/json".toMediaType()
    }
}
