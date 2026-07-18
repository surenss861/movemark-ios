package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PropertyHydrator @Inject constructor(
    private val propertyRepository: PropertyRepository,
    private val inspectionRepository: InspectionRepository,
) {
    suspend fun hydrate(row: PropertyRow): PropertyRecord {
        val propertyId = UUID.fromString(row.id)
        val rooms = propertyRepository.fetchRooms(propertyId)
        val inspections = inspectionRepository.fetchInspections(propertyId)

        val moveInIds = inspectionIdsFor(inspections, ProofPhase.MoveIn)
        val moveOutIds = inspectionIdsFor(inspections, ProofPhase.MoveOut)

        val moveInItems = inspectionRepository.fetchInspectionItems(moveInIds)
        val moveOutItems = inspectionRepository.fetchInspectionItems(moveOutIds)

        val allItemIds = (moveInItems + moveOutItems).map { UUID.fromString(it.id) }
        val allFiles = inspectionRepository.fetchEvidenceFilesByItems(allItemIds)

        val photosByItem = allFiles
            .filter { it.inspectionItemId != null }
            .groupBy { UUID.fromString(it.inspectionItemId!!) }
            .mapValues { (_, files) ->
                files.map { EvidencePhoto(UUID.fromString(it.id), it.filePath) }
            }

        val roomRecords = rooms.map { roomRow ->
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
            title = row.title,
            addressLine1 = row.addressLine1,
            city = row.city,
            provinceState = row.provinceState,
            rooms = roomRecords,
        )
    }

    private fun inspectionIdsFor(
        inspections: List<com.surensureshkumar.movemark.data.models.InspectionRow>,
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
        items: List<com.surensureshkumar.movemark.data.models.InspectionItemRow>,
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
