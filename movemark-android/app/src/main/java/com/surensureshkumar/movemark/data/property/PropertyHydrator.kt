package com.surensureshkumar.movemark.data.property

import android.util.Log
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.InspectionRow
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.PropertySnapshotV2
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Builds the UI-facing [PropertyRecord] tree from one bounded `get_property_snapshot_v2` call (iOS
 * `PropertyStore+Hydration`): every room with its true per-stage totals, the newest entries per room and stage
 * with their true photo counts and first photos. What is not loaded is kept as each room's unloaded remainder
 * (see [RoomRecord.totals]); [EvidenceHistory] loads it on demand.
 *
 * Also backs the offline snapshot cache: [hydrateFromCache] is an instant, no-network read of the last
 * successfully-persisted snapshot; [hydrate] does the network fetch and, on success, replaces + re-persists
 * that cache. There's no conflict resolution or write queuing here -- "instant local read, then refresh."
 */
@Singleton
class PropertyHydrator @Inject constructor(
    private val propertyRepository: PropertyRepository,
    private val snapshotCache: PropertySnapshotCache,
    private val fileUrls: StoredFileUrls,
) {
    /** A hydrated property plus the maintenance log the same snapshot carried. */
    class Hydrated(val record: PropertyRecord, val maintenance: List<MaintenanceRecord>)

    /** Network fetch. On success, replaces + re-persists the local cache for [row]'s property. */
    suspend fun hydrate(row: PropertyRow): Hydrated {
        val propertyId = UUID.fromString(row.id)
        val rawJson = propertyRepository.fetchPropertySnapshotJson(propertyId)
        val snapshot = propertyRepository.decodeSnapshot(rawJson)
        snapshotCache.write(propertyId, rawJson)
        rememberFiles(snapshot)
        return build(propertyId, row, snapshot)
    }

    /**
     * Instant, no-network read of the last cached snapshot for [row]'s property, or null if none is cached yet
     * (first launch, or a cache written by an older snapshot format). Never throws.
     */
    suspend fun hydrateFromCache(row: PropertyRow): Hydrated? {
        val propertyId = UUID.fromString(row.id)
        val cachedJson = snapshotCache.read(propertyId) ?: return null
        return runCatching { propertyRepository.decodeSnapshot(cachedJson) }
            .onFailure { Log.e("PropertyHydrator", "Cached snapshot decode failed for $propertyId", it) }
            .getOrNull()
            ?.let { build(propertyId, row, it) }
    }

    /** Wipes the offline snapshot cache. Call on sign-out — see [PropertySnapshotCache.clearAll]. */
    suspend fun clearCache() {
        snapshotCache.clearAll()
    }

    private suspend fun rememberFiles(snapshot: PropertySnapshotV2) {
        snapshot.entries.evidenceFiles.forEach { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) }
        snapshot.documents.forEach { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) }
    }

    companion object {
        /** Pure assembly of a snapshot into the UI tree (unit-tested). */
        fun build(propertyId: UUID, row: PropertyRow, snapshot: PropertySnapshotV2): Hydrated {
            // snapshot.property is null only if RLS denies access -- shouldn't happen for a row the caller already
            // fetched, but fall back to the known row rather than blanking the screen over a transient null.
            val propertyRow = snapshot.property ?: row

            val moveInIds = inspectionIdsFor(snapshot.inspections, ProofPhase.MoveIn)
            val moveOutIds = inspectionIdsFor(snapshot.inspections, ProofPhase.MoveOut)
            val moveInItems = snapshot.inspectionItems.filter { it.inspectionId.lowercase() in moveInIds }
            val moveOutItems = snapshot.inspectionItems.filter { it.inspectionId.lowercase() in moveOutIds }
            val parts = EvidenceHistory.entryParts(snapshot.entries)

            val rooms = snapshot.rooms.map { roomRow ->
                val roomId = UUID.fromString(roomRow.id)
                val moveIn = entriesForRoom(roomRow.id, moveInItems, parts, "Move-in capture")
                val moveOut = entriesForRoom(roomRow.id, moveOutItems, parts, "Move-out capture")
                RoomRecord(
                    id = roomId,
                    name = roomRow.name,
                    moveInEvidence = moveIn,
                    moveOutEvidence = moveOut,
                    // Server totals minus what is loaded = what loads on demand.
                    moveInUnloaded = EvidenceHistory.unloaded(roomRow.stats[ProofPhase.MoveIn.key], moveIn),
                    moveOutUnloaded = EvidenceHistory.unloaded(roomRow.stats[ProofPhase.MoveOut.key], moveOut),
                )
            }

            val record = PropertyRecord(
                id = propertyId,
                title = propertyRow.title,
                addressLine1 = propertyRow.addressLine1,
                city = propertyRow.city,
                provinceState = propertyRow.provinceState,
                rooms = rooms,
                supportingRecordCount = supportingRecordCount(snapshot.documentTypes),
                documentTypes = snapshot.documentTypes,
            )
            val maintenance = snapshot.maintenanceIssues.map { issue ->
                MaintenanceRecord(
                    id = UUID.fromString(issue.id),
                    title = issue.title,
                    category = issue.category ?: "General",
                    details = issue.description ?: "",
                    status = issue.status,
                    landlordResponse = issue.landlordResponse,
                    photoCount = snapshot.maintenancePhotoCounts[issue.id.lowercase()] ?: 0,
                    createdAt = issue.createdAt,
                )
            }
            return Hydrated(record, maintenance)
        }

        private fun inspectionIdsFor(inspections: List<InspectionRow>, phase: ProofPhase): Set<String> = inspections
            .filter { normalizeInspectionType(it.inspectionType) == phase.key }
            .map { it.id.lowercase() }
            .toSet()

        private fun normalizeInspectionType(raw: String): String = when (raw.lowercase()) {
            "move-in", "move_in", "movein" -> ProofPhase.MoveIn.key
            "move-out", "move_out", "moveout" -> ProofPhase.MoveOut.key
            else -> raw.lowercase()
        }

        private fun entriesForRoom(
            roomId: String,
            items: List<InspectionItemRow>,
            parts: EvidenceHistory.EntryParts,
            defaultTitle: String,
        ): List<EvidenceRecord> = items
            .filter { it.roomId.equals(roomId, ignoreCase = true) }
            .sortedByDescending { it.createdAt.orEmpty() }
            .map { EvidenceHistory.evidenceRecord(it, parts, defaultTitle) }
            .distinctBy { it.id }

        /** Lease, deposit receipt, and listing proof. Legacy hyphenated types count. */
        private fun supportingRecordCount(documentTypes: List<String>): Int {
            val uploaded = documentTypes.toSet()
            val required = listOf(
                setOf("lease"),
                setOf("deposit_receipt", "deposit-receipt"),
                setOf("listing_screenshot", "listing-screenshot"),
            )
            return required.count { keys -> keys.any { it in uploaded } }
        }
    }
}
