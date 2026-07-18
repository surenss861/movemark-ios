package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidenceFileRow
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.InspectionRow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlin.time.Duration.Companion.seconds
import java.time.Instant
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InspectionRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    companion object {
        const val EVIDENCE_BUCKET = "inspection-media"
    }

    private fun normalizeInspectionType(raw: String): String = when (raw.lowercase()) {
        "move-in", "move_in", "movein" -> "move_in"
        "move-out", "move_out", "moveout" -> "move_out"
        else -> raw
    }

    private suspend fun findInspection(propertyId: UUID, userId: UUID, normalizedType: String): InspectionRow? =
        client.from("inspections")
            .select {
                filter {
                    eq("property_id", propertyId.toString())
                    eq("user_id", userId.toString())
                    eq("inspection_type", normalizedType)
                }
                limit(1)
            }
            .decodeList<InspectionRow>()
            .firstOrNull()

    suspend fun upsertInspection(propertyId: UUID, userId: UUID, type: String): UUID {
        val normalized = normalizeInspectionType(type)
        findInspection(propertyId, userId, normalized)?.let { return UUID.fromString(it.id) }

        val newId = UUID.randomUUID()
        return try {
            val inserted = client.from("inspections")
                .insert(
                    InspectionInsertRow(
                        id = newId.toString(),
                        propertyId = propertyId.toString(),
                        userId = userId.toString(),
                        inspectionType = normalized,
                    ),
                ) { select() }
                .decodeSingle<InspectionRow>()
            UUID.fromString(inserted.id)
        } catch (e: Exception) {
            // A concurrent call (second device, retried request) may have inserted the same
            // (property_id, user_id, inspection_type) row between our select and insert; the DB's
            // unique index rejects ours. Re-select the winner instead of surfacing a spurious
            // error or (worse) creating a duplicate inspections row.
            findInspection(propertyId, userId, normalized)?.let { return UUID.fromString(it.id) }
            throw e
        }
    }

    suspend fun fetchInspections(propertyId: UUID): List<InspectionRow> =
        client.from("inspections")
            .select { filter { eq("property_id", propertyId.toString()) } }
            .decodeList()

    suspend fun fetchInspectionItems(inspectionIds: List<UUID>): List<InspectionItemRow> {
        if (inspectionIds.isEmpty()) return emptyList()
        return client.from("inspection_items")
            .select {
                filter { isIn("inspection_id", inspectionIds.map { it.toString() }) }
            }
            .decodeList()
    }

    suspend fun fetchEvidenceFilesByItems(itemIds: List<UUID>): List<EvidenceFileRow> {
        if (itemIds.isEmpty()) return emptyList()
        return client.from("evidence_files")
            .select {
                filter { isIn("inspection_item_id", itemIds.map { it.toString() }) }
            }
            .decodeList()
    }

    suspend fun insertInspectionItem(
        inspectionId: UUID,
        roomId: UUID,
        notes: String,
        conditionRating: Int,
    ): UUID {
        val id = UUID.randomUUID()
        val row = InspectionItemRow(
            id = id.toString(),
            inspectionId = inspectionId.toString(),
            roomId = roomId.toString(),
            notes = notes,
            conditionRating = conditionRating,
        )
        val inserted = client.from("inspection_items").insert(row) { select() }.decodeSingle<InspectionItemRow>()
        return UUID.fromString(inserted.id)
    }

    suspend fun insertEvidenceFile(
        propertyId: UUID,
        inspectionItemId: UUID,
        filePath: String,
    ): UUID {
        val id = UUID.randomUUID()
        val row = EvidenceFileRow(
            id = id.toString(),
            propertyId = propertyId.toString(),
            inspectionItemId = inspectionItemId.toString(),
            filePath = filePath,
            fileType = "image",
            capturedAt = Instant.now().toString(),
        )
        val inserted = client.from("evidence_files").insert(row) { select() }.decodeSingle<EvidenceFileRow>()
        return UUID.fromString(inserted.id)
    }

    suspend fun uploadPhoto(data: ByteArray, path: String) {
        client.storage.from(EVIDENCE_BUCKET).upload(path, data) {
            upsert = false
            contentType = ContentType.Image.JPEG
        }
    }

    suspend fun signedUrl(path: String, expiresSeconds: Int = 3600): String {
        val trimmed = path.trim()
        require(trimmed.isNotEmpty()) { "Missing file path." }
        return client.storage.from(EVIDENCE_BUCKET).createSignedUrl(trimmed, expiresSeconds.seconds)
    }

    suspend fun removeOrphanUpload(path: String) {
        if (path.isEmpty()) return
        runCatching {
            client.storage.from(EVIDENCE_BUCKET).delete(path)
        }
    }

    suspend fun deleteInspectionItem(id: UUID) {
        val files = client.from("evidence_files")
            .select { filter { eq("inspection_item_id", id.toString()) } }
            .decodeList<EvidenceFileRow>()
        files.forEach { file ->
            runCatching { client.storage.from(EVIDENCE_BUCKET).delete(file.filePath) }
        }
        client.from("evidence_files").delete { filter { eq("inspection_item_id", id.toString()) } }
        client.from("inspection_items").delete { filter { eq("id", id.toString()) } }
    }
}
