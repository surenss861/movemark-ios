package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.AbandonResult
import com.surensureshkumar.movemark.data.backend.MoveMarkStorageService
import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.evidence.EvidenceImport
import com.surensureshkumar.movemark.data.evidence.EvidenceImportException
import com.surensureshkumar.movemark.data.evidence.EvidenceSaver
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import com.surensureshkumar.movemark.data.models.EvidenceFileRow
import com.surensureshkumar.movemark.data.models.InspectionItemPatch
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.InspectionItemTagLink
import com.surensureshkumar.movemark.data.models.InspectionRow
import com.surensureshkumar.movemark.data.models.IssueTagRow
import android.content.Context
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/*
 * Inspection, evidence and photo data access. Evidence files live in `inspection-media` under keys the MoveMark
 * API builds (`{userId}/{propertyId}/move-in|move-out/{roomId}/{uuid}.jpg`, lowercase); the app records the
 * returned paths in `evidence_files` and never chooses or deletes keys itself.
 */
class InspectionRepository(
    private val context: Context,
    private val postgrest: PostgrestClient,
    private val storage: MoveMarkStorageService,
    private val fileUrls: StoredFileUrls,
) {
    companion object {
        private const val MAX_EVIDENCE_FILES_PER_MAINTENANCE_ISSUE = 200
        private const val ID_PAGE = 1000
    }

    @Serializable
    private data class IdRow(val id: String)

    @Serializable
    private data class MaintenanceCountRow(
        @SerialName("maintenance_issue_id") val maintenanceIssueId: String,
        val count: Int,
    )

    private fun normalizeInspectionType(raw: String): String = when (raw.lowercase()) {
        "move-in", "move_in", "movein" -> "move_in"
        "move-out", "move_out", "moveout" -> "move_out"
        else -> raw
    }

    private suspend fun findInspection(propertyId: UUID, userId: UUID, normalizedType: String): InspectionRow? =
        postgrest.select<InspectionRow>("inspections") {
            eq("property_id", propertyId.toString())
            eq("user_id", userId.toString())
            eq("inspection_type", normalizedType)
            order("id")
            limit(1)
        }.firstOrNull()

    /**
     * The stable `inspections.id` for (property_id, user_id, inspection_type). Select-then-insert avoids
     * upserting a new random id onto an existing row, which would break `inspection_items` foreign keys.
     */
    suspend fun upsertInspection(propertyId: UUID, userId: UUID, type: String): UUID {
        val normalized = normalizeInspectionType(type)
        findInspection(propertyId, userId, normalized)?.let { return UUID.fromString(it.id) }

        val newId = UUID.randomUUID()
        return try {
            val inserted = postgrest.insertReturning<InspectionInsertRow, InspectionRow>(
                "inspections",
                InspectionInsertRow(
                    id = newId.toString(),
                    propertyId = propertyId.toString(),
                    userId = userId.toString(),
                    inspectionType = normalized,
                ),
            ).single()
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

    suspend fun insertInspectionItem(
        inspectionId: UUID,
        roomId: UUID,
        notes: String,
        conditionRating: Int,
    ): UUID {
        val row = InspectionItemRow(
            id = UUID.randomUUID().toString(),
            inspectionId = inspectionId.toString(),
            roomId = roomId.toString(),
            notes = notes,
            conditionRating = conditionRating,
        )
        val inserted = postgrest.insertReturning<InspectionItemRow, InspectionItemRow>("inspection_items", row).single()
        return UUID.fromString(inserted.id)
    }

    /** Inserts the `evidence_files` row for a finalized upload, under the photo's stable row id. */
    suspend fun insertEvidenceFile(
        rowId: UUID,
        propertyId: UUID,
        inspectionItemId: UUID?,
        maintenanceIssueId: UUID?,
        upload: MoveMarkUpload,
    ) {
        val row = EvidenceFileRow(
            id = rowId.toString(),
            propertyId = propertyId.toString(),
            inspectionItemId = inspectionItemId?.toString(),
            maintenanceIssueId = maintenanceIssueId?.toString(),
            filePath = upload.path,
            fileType = "image",
            // From the source's own metadata when it has any (declared, not verified); else upload time.
            capturedAt = upload.capturedAt ?: Instant.now().toString(),
            thumbnailPath = upload.thumbnailPath,
            sourcePath = upload.sourcePath,
        )
        postgrest.insert("evidence_files", row)
        fileUrls.remember(rowId.toString(), upload.path, upload.thumbnailPath)
    }

    /** Builds the working derivative and thumbnail for [source]; throws when the photo can't be rendered. */
    fun prepare(source: EvidenceSource) =
        EvidenceImport.prepare(context, source) ?: throw EvidenceImportException.Unreadable()

    /** Upload → row pipeline for photos of one inspection item (new entry or add photos). See [EvidenceSaver]. */
    fun evidenceSaver(inspectionItemId: UUID, roomId: UUID, propertyId: UUID, isMoveOut: Boolean) = EvidenceSaver(
        upload = { source ->
            storage.uploadEvidence(prepare(source), propertyId.toString(), roomId.toString(), isMoveOut)
        },
        insert = { rowId, upload -> insertEvidenceFile(rowId, propertyId, inspectionItemId, null, upload) },
        abandon = { storage.abandon(it) },
    )

    /** Same pipeline for maintenance attachments (`maintenance-media`, row linked to the issue). */
    fun maintenanceSaver(issueId: UUID, propertyId: UUID) = EvidenceSaver(
        upload = { source -> storage.uploadMaintenanceEvidence(prepare(source), propertyId.toString(), issueId.toString()) },
        insert = { rowId, upload -> insertEvidenceFile(rowId, propertyId, null, issueId, upload) },
        abandon = { storage.abandon(it) },
    )

    suspend fun abandonUpload(upload: MoveMarkUpload): AbandonResult = storage.abandon(upload)

    suspend fun fetchEvidenceFilesByMaintenanceIssue(issueId: UUID): List<EvidenceFileRow> =
        postgrest.select<EvidenceFileRow>("evidence_files") {
            eq("maintenance_issue_id", issueId.toString())
            order("created_at")
            order("id")
            // A single issue shouldn't realistically accumulate more than this many attachments;
            // caps the LazyRow rather than letting it fetch/render an unbounded list.
            limit(MAX_EVIDENCE_FILES_PER_MAINTENANCE_ISSUE)
        }.also { files -> files.forEach { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) } }

    /** Photo count per maintenance issue of a property, grouped by the server; the photo rows are not downloaded. */
    suspend fun fetchMaintenancePhotoCounts(propertyId: UUID): Map<UUID, Int> =
        postgrest.select<MaintenanceCountRow>("evidence_files") {
            select("maintenance_issue_id,count()")
            eq("property_id", propertyId.toString())
            notNull("maintenance_issue_id")
            order("maintenance_issue_id")
            limit(1000)
        }.associate { UUID.fromString(it.maintenanceIssueId) to it.count }

    /** Temporary download URL for a stored evidence path (original or thumbnail). */
    suspend fun signedUrl(path: String): String {
        val trimmed = path.trim()
        require(trimmed.isNotEmpty()) { "Missing file path." }
        return fileUrls.evidenceUrl(trimmed)
    }

    /** Links tag names to an item via `issue_tags` ids (unknown names are skipped, as on iOS). */
    suspend fun insertItemTags(inspectionItemId: UUID, tagNames: List<String>) {
        if (tagNames.isEmpty()) return
        val tags = postgrest.select<IssueTagRow>("issue_tags") {
            isIn("name", tagNames)
            order("name")
            order("id")
            limit(tagNames.size * 2)
        }
        val links = tags.map { InspectionItemTagLink(inspectionItemId.toString(), it.id) }
        if (links.isNotEmpty()) postgrest.insert("inspection_item_tags", links)
    }

    suspend fun deleteItemTags(inspectionItemId: UUID) {
        postgrest.delete("inspection_item_tags") { eq("inspection_item_id", inspectionItemId.toString()) }
    }

    suspend fun updateInspectionItem(id: UUID, notes: String, conditionRating: Int) {
        postgrest.update("inspection_items", InspectionItemPatch(notes, conditionRating)) { eq("id", id.toString()) }
    }

    /** Every photo row id of an entry, in id-keyset pages (an entry's photos are not capped). */
    private suspend fun evidenceIdsForItem(itemId: UUID): List<String> {
        val ids = mutableListOf<String>()
        while (true) {
            val after = ids.lastOrNull()
            val page = postgrest.select<IdRow>("evidence_files") {
                select("id")
                eq("inspection_item_id", itemId.toString())
                if (after != null) gt("id", after)
                order("id")
                limit(ID_PAGE)
            }
            ids += page.map { it.id }
            if (page.size < ID_PAGE) return ids
        }
    }

    /** Same order as iOS: files and their rows (server-side, by row id), then tag links, then the item. */
    suspend fun deleteInspectionItem(id: UUID) {
        storage.deleteEvidence(evidenceIdsForItem(id))
        deleteItemTags(id)
        postgrest.delete("inspection_items") { eq("id", id.toString()) }
    }
}
