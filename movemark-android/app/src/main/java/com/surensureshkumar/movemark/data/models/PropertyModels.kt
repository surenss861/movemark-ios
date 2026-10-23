package com.surensureshkumar.movemark.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class PropertyRow(
    val id: String,
    @SerialName("user_id") val userId: String,
    var title: String,
    @SerialName("address_line_1") var addressLine1: String,
    @SerialName("address_line_2") var addressLine2: String? = null,
    var city: String,
    @SerialName("province_state") var provinceState: String,
    @SerialName("postal_code") var postalCode: String,
    var country: String,
    @SerialName("landlord_name") var landlordName: String? = null,
    @SerialName("landlord_email") var landlordEmail: String? = null,
    @SerialName("landlord_phone") var landlordPhone: String? = null,
    @SerialName("deposit_amount") var depositAmount: Double? = null,
    @SerialName("rent_amount") var rentAmount: Double? = null,
    @SerialName("move_in_date") var moveInDate: String? = null,
    @SerialName("lease_start") var leaseStart: String? = null,
    @SerialName("lease_end") var leaseEnd: String? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class RoomRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    var name: String,
    @SerialName("sort_order") var sortOrder: Int,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class InspectionRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("inspection_type") var inspectionType: String,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class InspectionItemRow(
    val id: String,
    @SerialName("inspection_id") val inspectionId: String,
    @SerialName("room_id") val roomId: String,
    var notes: String? = null,
    @SerialName("condition_rating") var conditionRating: Int? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class EvidenceFileRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("inspection_item_id") var inspectionItemId: String? = null,
    @SerialName("maintenance_issue_id") var maintenanceIssueId: String? = null,
    @SerialName("file_path") var filePath: String,
    @SerialName("file_type") var fileType: String,
    @SerialName("captured_at") var capturedAt: String? = null,
    @SerialName("created_at") var createdAt: String? = null,
    /** ~320px longest-side JPEG uploaded alongside the full-size capture; null for rows captured before thumbnails existed. */
    @SerialName("thumbnail_path") var thumbnailPath: String? = null,
    /** The immutable source object; its hash, size and type are filled in by the database from the finalized upload ticket. */
    @SerialName("source_path") var sourcePath: String? = null,
)

/** Flattened `inspection_item_tags` + `issue_tags` join, as returned in the snapshot's `entries.item_tags`. */
@Serializable
data class ItemTagRow(
    @SerialName("inspection_item_id") val inspectionItemId: String,
    val name: String,
)

/** `issue_tags` row — the fixed damage vocabulary (see iOS `fixedIssueTags`). */
@Serializable
data class IssueTagRow(
    val id: String,
    val name: String,
)

/** `inspection_item_tags` link row. */
@Serializable
data class InspectionItemTagLink(
    @SerialName("inspection_item_id") val inspectionItemId: String,
    @SerialName("issue_tag_id") val issueTagId: String,
)

/** Patch for `inspection_items` (title is encoded as the first line of `notes`, as on iOS). */
@Serializable
data class InspectionItemPatch(
    val notes: String,
    @SerialName("condition_rating") val conditionRating: Int,
)

/** Mirrors `property_documents` columns (see iOS `DocumentRepository.PropertyDocumentRow` for the same schema). */
@Serializable
data class PropertyDocumentRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("document_type") var documentType: String,
    @SerialName("file_path") var filePath: String,
    @SerialName("file_name") var fileName: String,
    @SerialName("uploaded_at") var uploadedAt: String? = null,
    var metadata: Map<String, String>? = null,
    @SerialName("thumbnail_path") var thumbnailPath: String? = null,
)

/** Per-stage totals the server counted for one room (`stats` in `get_property_snapshot_v2`). */
@Serializable
data class StageStats(
    val entries: Int = 0,
    val photos: Int = 0,
    @SerialName("entries_with_notes") val entriesWithNotes: Int = 0,
    @SerialName("issue_tags") val issueTags: Int = 0,
    @SerialName("latest_at") val latestAt: String? = null,
)

/** A `rooms` row plus its `stats` object, keyed by inspection type (`move_in` / `move_out`). */
@Serializable
data class SnapshotRoomRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    val name: String,
    @SerialName("sort_order") val sortOrder: Int,
    @SerialName("created_at") val createdAt: String? = null,
    val stats: Map<String, StageStats> = emptyMap(),
)

/** The entries payload shared by the snapshot and `get_room_entries_page`. */
@Serializable
data class SnapshotEntries(
    /** True photo count per entry, keyed by lowercase `inspection_items.id`. */
    @SerialName("photo_counts") val photoCounts: Map<String, Int> = emptyMap(),
    /** The first photos of each entry, in capture order (created_at, id). */
    @SerialName("evidence_files") val evidenceFiles: List<EvidenceFileRow> = emptyList(),
    @SerialName("item_tags") val itemTags: List<ItemTagRow> = emptyList(),
)

/**
 * Decoded shape of `public.get_property_snapshot_v2` (neon/migrations/0990_bounded_snapshot_v2.sql): all rooms
 * with true per-stage totals, the newest entries per room and stage with their true photo counts and first
 * photos, newest documents and maintenance with totals. Older entries and remaining photos load through
 * `get_room_entries_page` / `get_entry_photos_page`. `property` is null only when RLS hides the property.
 */
@Serializable
data class PropertySnapshotV2(
    val property: PropertyRow? = null,
    val rooms: List<SnapshotRoomRow> = emptyList(),
    val inspections: List<InspectionRow> = emptyList(),
    @SerialName("inspection_items") val inspectionItems: List<InspectionItemRow> = emptyList(),
    val entries: SnapshotEntries = SnapshotEntries(),
    val documents: List<PropertyDocumentRow> = emptyList(),
    /** Every document type present (the document rows themselves are bounded to the newest 100). */
    @SerialName("document_types") val documentTypes: List<String> = emptyList(),
    @SerialName("maintenance_issues") val maintenanceIssues: List<MaintenanceIssueRow> = emptyList(),
    @SerialName("maintenance_photo_counts") val maintenancePhotoCounts: Map<String, Int> = emptyMap(),
)

/** One page of `get_room_entries_page` (older entries, newest first). */
@Serializable
data class RoomEntriesPage(
    @SerialName("inspection_items") val inspectionItems: List<InspectionItemRow> = emptyList(),
    val entries: SnapshotEntries = SnapshotEntries(),
    @SerialName("has_more") val hasMore: Boolean = false,
)

/** One page of `get_entry_photos_page` (an entry's remaining photos, capture order). */
@Serializable
data class EntryPhotosPage(
    @SerialName("evidence_files") val evidenceFiles: List<EvidenceFileRow> = emptyList(),
    @SerialName("has_more") val hasMore: Boolean = false,
)

/** One row of `get_vault_summaries()`. */
@Serializable
data class VaultSummary(
    @SerialName("property_id") val propertyId: String,
    @SerialName("rooms_total") val roomsTotal: Int = 0,
    @SerialName("rooms_documented") val roomsDocumented: Int = 0,
    @SerialName("latest_evidence") val latestEvidence: LatestEvidence? = null,
) {
    @Serializable
    data class LatestEvidence(
        val id: String,
        @SerialName("file_path") val filePath: String,
        @SerialName("thumbnail_path") val thumbnailPath: String? = null,
        @SerialName("maintenance_issue_id") val maintenanceIssueId: String? = null,
    )
}

data class EvidencePhoto(
    val id: UUID,
    val filePath: String,
    /** ~320px JPEG for grids; null on rows captured before thumbnails existed (fall back to filePath). */
    val thumbnailPath: String? = null,
    /**
     * The row's `created_at` exactly as the server sent it — the keyset cursor for the next photo page
     * (a parsed time loses the microseconds the ordering depends on).
     */
    val serverCreatedAt: String? = null,
)

data class EvidenceRecord(
    val id: UUID,
    val title: String,
    val notes: String,
    /**
     * The entry's true number of photos. [photos] may hold only the first ones (snapshot v2 loads a bounded
     * number per entry; the rest load on demand), so never derive the count from [photos].
     */
    val photoCount: Int,
    val photos: List<EvidencePhoto> = emptyList(),
    /** 1 (poor) .. 5 (excellent); matches InspectionItemRow.conditionRating. Null if never set. */
    val conditionRating: Int? = null,
    val createdAt: String? = null,
    val issueTagCount: Int = 0,
    /** Issue tag names (`issue_tags.name`) linked to this entry — same set iOS shows and edits. */
    val issueTags: List<String> = emptyList(),
    /** `created_at` exactly as the server sent it — the keyset cursor for loading older entries. */
    val serverCreatedAt: String? = null,
) {
    /** Photos exist on the server that aren't loaded yet. */
    val hasUnloadedPhotos: Boolean get() = photoCount > photos.size
}

/** Entries, photos, noted entries and issue tags for one room and stage. */
data class StageTotals(
    val entries: Int = 0,
    val photos: Int = 0,
    val notedEntries: Int = 0,
    val issueTags: Int = 0,
    val latestAt: String? = null,
)

data class RoomRecord(
    val id: UUID,
    val name: String,
    /** Loaded move-in entries. Large rooms load their newest entries first; older ones load on demand. */
    val moveInEvidence: List<EvidenceRecord> = emptyList(),
    /** Move-out inspection evidence only — never mixed with move-in. */
    val moveOutEvidence: List<EvidenceRecord> = emptyList(),
    /**
     * What the server counted beyond the loaded entries (null = nothing unloaded). Totals are loaded entries
     * plus this remainder, so edits to loaded entries keep the totals right without bookkeeping.
     */
    val moveInUnloaded: StageTotals? = null,
    val moveOutUnloaded: StageTotals? = null,
) {
    fun evidence(moveOut: Boolean): List<EvidenceRecord> = if (moveOut) moveOutEvidence else moveInEvidence

    fun unloaded(moveOut: Boolean): StageTotals? = if (moveOut) moveOutUnloaded else moveInUnloaded

    /** Loaded entries plus the unloaded remainder: what the server holds for this room and stage. */
    fun totals(moveOut: Boolean): StageTotals = sum(evidence(moveOut), unloaded(moveOut))

    /** Older entries exist that are not loaded yet. */
    fun hasOlderEntries(moveOut: Boolean): Boolean = (unloaded(moveOut)?.entries ?: 0) > 0

    companion object {
        fun sum(entries: List<EvidenceRecord>, rest: StageTotals?): StageTotals = StageTotals(
            entries = entries.size + (rest?.entries ?: 0),
            photos = entries.sumOf { it.photoCount } + (rest?.photos ?: 0),
            notedEntries = entries.count { it.notes.isNotBlank() } + (rest?.notedEntries ?: 0),
            issueTags = entries.sumOf { it.issueTags.size } + (rest?.issueTags ?: 0),
            latestAt = listOfNotNull(entries.mapNotNull { it.createdAt }.maxOrNull(), rest?.latestAt).maxOrNull(),
        )
    }
}

data class PropertyRecord(
    val id: UUID,
    val title: String,
    val addressLine1: String,
    val city: String,
    val provinceState: String,
    val rooms: List<RoomRecord>,
    /** How many of lease, deposit receipt, and listing proof are on file. */
    val supportingRecordCount: Int = 0,
    /** Raw `property_documents.document_type` values, including legacy spellings. */
    val documentTypes: List<String> = emptyList(),
)

@Serializable
data class MaintenanceIssueRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    var title: String,
    var category: String? = null,
    var description: String? = null,
    var status: String = "open",
    @SerialName("landlord_response") var landlordResponse: String? = null,
    @SerialName("date_discovered") var dateDiscovered: String? = null,
    @SerialName("date_reported") var dateReported: String? = null,
    @SerialName("follow_up_date") var followUpDate: String? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

data class MaintenanceRecord(
    val id: UUID,
    val title: String,
    val category: String,
    val details: String,
    val status: String,
    val landlordResponse: String?,
    val photoCount: Int,
    val createdAt: String?,
)

data class CreatePropertyInput(
    val title: String,
    val addressLine1: String,
    val unit: String = "",
    val city: String,
    val region: String,
    val postalCode: String,
    val country: String = "CA",
    val landlordName: String = "",
    val landlordEmail: String = "",
    val landlordPhone: String = "",
    val depositAmount: String = "",
    val rentAmount: String = "",
) {
    val titleValue: String
        get() = title.trim().ifEmpty { addressLine1.trim().ifEmpty { "My rental" } }
}
