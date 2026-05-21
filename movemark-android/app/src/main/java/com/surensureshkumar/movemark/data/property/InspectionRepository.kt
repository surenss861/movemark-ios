package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidenceFileRow
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.InspectionRow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
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

    suspend fun upsertInspection(propertyId: UUID, userId: UUID, type: String): UUID {
        val normalized = normalizeInspectionType(type)
        val existing = client.from("inspections")
            .select {
                filter {
                    eq("property_id", propertyId.toString())
                    eq("user_id", userId.toString())
                    eq("inspection_type", normalized)
                }
                limit(1)
            }
            .decodeList<InspectionRow>()
        existing.firstOrNull()?.let { return UUID.fromString(it.id) }

        val newId = UUID.randomUUID()
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
        return UUID.fromString(inserted.id)
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
