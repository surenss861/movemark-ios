package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.time.Duration.Companion.seconds
import java.time.Instant
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DocumentRepository @Inject constructor(
    private val client: SupabaseClient,
    private val saveFaults: DocumentSaveFaults,
) {
    suspend fun fetchDocuments(propertyId: UUID): List<PropertyDocumentRow> =
        client.from("property_documents").select {
            filter { eq("property_id", propertyId.toString()) }
            order("uploaded_at", Order.DESCENDING)
            limit(300)
        }.decodeList()

    /**
     * Saves a new copy of this document type, then retires the old one.
     * Storage path matches iOS: `{userId}/{propertyId}/{type}/{file}`.
     *
     * The existing copy is never touched until the new file and its row are both saved: if
     * the upload or insert fails, the old document stays exactly as it was.
     */
    suspend fun replaceDocument(
        propertyId: UUID,
        userId: UUID,
        kind: VaultDocumentKind,
        bytes: ByteArray,
        fileName: String,
    ) {
        val previous = existingDocuments(propertyId, kind)
        val safeName = fileName.substringAfterLast('/').ifBlank { "document" }
        val path = "$userId/$propertyId/${kind.raw}/${UUID.randomUUID()}-$safeName"
        try {
            upload(kind, path, bytes, contentType(safeName))
            if (saveFaults.failNextInsert()) {
                throw IllegalStateException("Document record was not saved.")
            }
            val row = DocumentInsert(
                id = UUID.randomUUID().toString(),
                propertyId = propertyId.toString(),
                userId = userId.toString(),
                documentType = kind.raw,
                filePath = path,
                fileName = safeName,
                uploadedAt = Instant.now().toString(),
            )
            client.from("property_documents").insert(row)
        } catch (error: Throwable) {
            // The storage call can be cancelled after the object already exists, and a failed
            // insert must not leave that object behind with no property_documents row.
            withContext(NonCancellable) { removeStale(kind, path) }
            throw error
        }
        // The new copy is saved. Retiring the old one is best-effort: a failure here leaves
        // an extra row (the newest is shown), never a missing document.
        withContext(NonCancellable) { removeDocuments(kind, previous) }
    }

    suspend fun signedUrl(kind: VaultDocumentKind, path: String): String {
        val buckets = if (kind.storageBucket() == "documents") {
            listOf("documents")
        } else {
            listOf(kind.storageBucket(), "documents")
        }
        var last: Exception? = null
        for (bucket in buckets) {
            try {
                return client.storage.from(bucket).createSignedUrl(path, 3600.seconds)
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Couldn't open that file.")
    }

    private suspend fun existingDocuments(propertyId: UUID, kind: VaultDocumentKind): List<PropertyDocumentRow> =
        fetchDocuments(propertyId).filter { row -> kind.queryKeys().contains(row.documentType) }

    private suspend fun removeDocuments(kind: VaultDocumentKind, rows: List<PropertyDocumentRow>) {
        rows.forEach { row ->
            runCatching {
                client.from("property_documents").delete { filter { eq("id", row.id) } }
            }.onSuccess {
                removeStale(kind, row.filePath)
            }
        }
    }

    private suspend fun upload(kind: VaultDocumentKind, path: String, bytes: ByteArray, type: ContentType): String {
        val buckets = if (kind.storageBucket() == "documents") listOf("documents") else listOf(kind.storageBucket(), "documents")
        var last: Exception? = null
        for (bucket in buckets) {
            try {
                client.storage.from(bucket).upload(path, bytes) {
                    upsert = false
                    contentType = type
                }
                return bucket
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Couldn't upload that file.")
    }

    private suspend fun removeStale(kind: VaultDocumentKind, path: String) {
        val buckets = if (kind.storageBucket() == "documents") {
            listOf("documents")
        } else {
            listOf(kind.storageBucket(), "documents")
        }
        buckets.forEach { bucket ->
            runCatching { client.storage.from(bucket).delete(path) }
        }
    }

    private fun contentType(fileName: String): ContentType {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".pdf") -> ContentType.parse("application/pdf")
            lower.endsWith(".png") -> ContentType.Image.PNG
            lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> ContentType.Image.JPEG
            else -> ContentType.Application.OctetStream
        }
    }
}

@Serializable
private data class DocumentInsert(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("document_type") val documentType: String,
    @SerialName("file_path") val filePath: String,
    @SerialName("file_name") val fileName: String,
    @SerialName("uploaded_at") val uploadedAt: String,
)
