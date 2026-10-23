package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.MoveMarkStorageService
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.evidence.EvidenceFormats
import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/*
 * Property documents. Files go through the MoveMark API, which picks the bucket from the document type and
 * builds the key (`{userId}/{propertyId}/{documentType}/{uuid}.{pdf|jpg|png}`); the app records the returned path.
 */
class DocumentRepository(
    private val postgrest: PostgrestClient,
    private val storage: MoveMarkStorageService,
    private val fileUrls: StoredFileUrls,
    private val saveFaults: DocumentSaveFaults,
) {
    suspend fun fetchDocuments(propertyId: UUID): List<PropertyDocumentRow> =
        postgrest.select<PropertyDocumentRow>("property_documents") {
            eq("property_id", propertyId.toString())
            order("uploaded_at", ascending = false)
            order("id", ascending = false)
            limit(300)
        }.also { rows -> rows.forEach { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) } }

    /**
     * Saves a new copy of this document type, then retires the old one.
     *
     * The existing copy is never touched until the new file and its row are both saved: if the upload or
     * insert fails, the old document stays exactly as it was. A failed insert abandons the upload; the API
     * keeps the file if the row committed after all.
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
        val upload = storage.uploadDocument(
            data = bytes,
            contentType = contentType(safeName, bytes),
            thumbnail = null,
            propertyId = propertyId.toString(),
            documentType = kind.raw,
        )
        try {
            if (saveFaults.failNextInsert()) {
                throw IllegalStateException("Document record was not saved.")
            }
            val row = DocumentInsert(
                id = UUID.randomUUID().toString(),
                propertyId = propertyId.toString(),
                userId = userId.toString(),
                documentType = kind.raw,
                filePath = upload.path,
                fileName = safeName,
                uploadedAt = Instant.now().toString(),
            )
            postgrest.insert("property_documents", row)
            fileUrls.remember(row.id, upload.path, null)
        } catch (error: Throwable) {
            // The insert can be cancelled after the row already committed, and a failed insert must not leave
            // the object behind with no row: abandon settles it either way.
            withContext(NonCancellable) { storage.abandon(upload) }
            throw error
        }
        // The new copy is saved. Retiring the old one is best-effort: a failure here leaves an extra row
        // (the newest is shown), never a missing document.
        withContext(NonCancellable) {
            if (previous.isNotEmpty()) runCatching { storage.deleteDocuments(previous.map { it.id }) }
        }
    }

    /** Temporary download URL for a stored document path. */
    suspend fun signedUrl(path: String): String = fileUrls.documentUrl(path)

    private suspend fun existingDocuments(propertyId: UUID, kind: VaultDocumentKind): List<PropertyDocumentRow> =
        fetchDocuments(propertyId).filter { row -> kind.queryKeys().contains(row.documentType) }

    /** The API accepts PDF, JPEG and PNG documents; a name without a known extension is typed by its bytes. */
    private fun contentType(fileName: String, bytes: ByteArray): String {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".pdf") -> "application/pdf"
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> "image/jpeg"
            bytes.size >= 4 && String(bytes, 0, 4, Charsets.ISO_8859_1) == "%PDF" -> "application/pdf"
            else -> EvidenceFormats.detect(bytes)?.mimeType?.takeIf { it == "image/jpeg" || it == "image/png" }
                ?: "application/octet-stream"
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
