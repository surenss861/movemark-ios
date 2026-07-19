package com.surensureshkumar.movemark.data.property

import android.util.Log
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.InspectionRow
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.PropertySnapshot
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Builds the UI-facing [PropertyRecord] tree from a single [PropertyRepository.fetchPropertySnapshot]
 * RPC call instead of the ~11 sequential/parallel per-table round trips this used to make (rooms,
 * inspections, inspection_items, evidence_files, tags — each wave depending on the previous one's
 * IDs). All grouping/matching business logic below is unchanged from before the RPC migration;
 * only where the raw rows come from has changed.
 *
 * Also backs the offline snapshot cache (task #12): [hydrateFromCache] is an instant, no-network
 * read of the last successfully-persisted snapshot; [hydrate] does the network fetch and, on
 * success, replaces + re-persists that cache. There's no conflict resolution or write queuing here
 * -- this is "instant local read, then refresh," nothing more.
 */
@Singleton
class PropertyHydrator @Inject constructor(
    private val propertyRepository: PropertyRepository,
    private val snapshotCache: PropertySnapshotCache,
) {
    /** Network fetch. On success, replaces + re-persists the local cache for [row]'s property. */
    suspend fun hydrate(row: PropertyRow): PropertyRecord {
        val propertyId = UUID.fromString(row.id)
        val rawJson = propertyRepository.fetchPropertySnapshotJson(propertyId)
        val snapshot = propertyRepository.decodeSnapshot(rawJson)
        snapshotCache.write(propertyId, rawJson)
        return buildRecord(propertyId, row, snapshot)
    }

    /**
     * Instant, no-network read of the last cached snapshot for [row]'s property, or null if none
     * is cached yet (first launch / never successfully hydrated before). Never throws.
     */
    suspend fun hydrateFromCache(row: PropertyRow): PropertyRecord? {
        val propertyId = UUID.fromString(row.id)
        val cachedJson = snapshotCache.read(propertyId) ?: return null
        return runCatching { propertyRepository.decodeSnapshot(cachedJson) }
            .onFailure { Log.e("PropertyHydrator", "Cached snapshot decode failed for $propertyId", it) }
            .getOrNull()
            ?.let { buildRecord(propertyId, row, it) }
    }

    /** Wipes the offline snapshot cache. Call on sign-out — see [PropertySnapshotCache.clearAll]. */
    suspend fun clearCache() {
        snapshotCache.clearAll()
    }

    private fun buildRecord(propertyId: UUID, row: PropertyRow, snapshot: PropertySnapshot): PropertyRecord {
        // snapshot.property is null only if RLS denies access (caller isn't the owner) -- shouldn't
        // happen for a row the caller already fetched via fetchProperties(), but fall back to the
        // caller's already-known row rather than blanking the screen over a transient/race null.
        val propertyRow = snapshot.property ?: row

        val moveInIds = inspectionIdsFor(snapshot.inspections, ProofPhase.MoveIn).toSet()
        val moveOutIds = inspectionIdsFor(snapshot.inspections, ProofPhase.MoveOut).toSet()

        val moveInItems = snapshot.inspectionItems.filter { UUID.fromString(it.inspectionId) in moveInIds }
        val moveOutItems = snapshot.inspectionItems.filter { UUID.fromString(it.inspectionId) in moveOutIds }

        val allItemIds = (moveInItems + moveOutItems).map { UUID.fromString(it.id) }.toSet()
        val allFiles = snapshot.evidenceFiles.filter {
            it.inspectionItemId != null && UUID.fromString(it.inspectionItemId!!) in allItemIds
        }

        val photosByItem = allFiles
            .groupBy { UUID.fromString(it.inspectionItemId!!) }
            .mapValues { (_, files) ->
                files.map { EvidencePhoto(UUID.fromString(it.id), it.filePath) }
            }

        val roomRecords = snapshot.rooms.map { roomRow ->
            val roomId = UUID.fromString(roomRow.id)
            RoomRecord(
                id = roomId,
                name = roomRow.name,
                moveInEvidence = buildEvidenceForRoom(
                    roomId = roomId,
                    items = moveInItems,
                    photosByItem = photosByItem,
                    defaultTitle = "Move-in capture",
                ),
                moveOutEvidence = buildEvidenceForRoom(
                    roomId = roomId,
                    items = moveOutItems,
                    photosByItem = photosByItem,
                    defaultTitle = "Move-out capture",
                ),
            )
        }

        return PropertyRecord(
            id = propertyId,
            title = propertyRow.title,
            addressLine1 = propertyRow.addressLine1,
            city = propertyRow.city,
            provinceState = propertyRow.provinceState,
            rooms = roomRecords,
        )
    }

    private fun inspectionIdsFor(
        inspections: List<InspectionRow>,
        phase: ProofPhase,
    ): List<UUID> = inspections
        .filter { normalizeInspectionType(it.inspectionType) == phase.key }
        .map { UUID.fromString(it.id) }

    private fun normalizeInspectionType(raw: String): String = when (raw.lowercase()) {
        "move-in", "move_in", "movein" -> ProofPhase.MoveIn.key
        "move-out", "move_out", "moveout" -> ProofPhase.MoveOut.key
        else -> raw.lowercase()
    }

    private fun buildEvidenceForRoom(
        roomId: UUID,
        items: List<InspectionItemRow>,
        photosByItem: Map<UUID, List<EvidencePhoto>>,
        defaultTitle: String,
    ): List<EvidenceRecord> {
        return items
            .filter { UUID.fromString(it.roomId) == roomId }
            .sortedByDescending { it.createdAt.orEmpty() }
            .map { item ->
                val itemId = UUID.fromString(item.id)
                val photos = photosByItem[itemId].orEmpty()
                val (title, notes) = parseNotes(item.notes, defaultTitle)
                EvidenceRecord(
                    id = itemId,
                    title = title,
                    notes = notes,
                    photoCount = photos.size,
                    photos = photos,
                    conditionRating = item.conditionRating,
                )
            }
    }

    private fun parseNotes(raw: String?, defaultTitle: String): Pair<String, String> {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return defaultTitle to ""
        val idx = trimmed.indexOf('\n')
        return if (idx >= 0) {
            val title = trimmed.substring(0, idx).trim().ifEmpty { defaultTitle }
            val notes = trimmed.substring(idx + 1).trim()
            title to notes
        } else {
            trimmed to ""
        }
    }
}
