package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.models.RoomRow
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
        val moveInIds = inspections
            .filter {
                val t = it.inspectionType.lowercase()
                t == "move_in" || t == "move-in" || t == "movein"
            }
            .map { UUID.fromString(it.id) }

        val moveInItems = inspectionRepository.fetchInspectionItems(moveInIds)
        val moveInFiles = inspectionRepository.fetchEvidenceFilesByItems(moveInItems.map { UUID.fromString(it.id) })

        val photosByItem = moveInFiles
            .filter { it.inspectionItemId != null }
            .groupBy { UUID.fromString(it.inspectionItemId!!) }
            .mapValues { (_, files) ->
                files.map { EvidencePhoto(UUID.fromString(it.id), it.filePath) }
            }

        val roomRecords = rooms.map { roomRow ->
            val roomId = UUID.fromString(roomRow.id)
            val items = moveInItems.filter { UUID.fromString(it.roomId) == roomId }
                .sortedByDescending { it.createdAt.orEmpty() }
            val evidence = items.map { item ->
                val itemId = UUID.fromString(item.id)
                val photos = photosByItem[itemId].orEmpty()
                val (title, notes) = parseNotes(item.notes, "Move-in capture")
                EvidenceRecord(
                    id = itemId,
                    title = title,
                    notes = notes,
                    photoCount = photos.size,
                    photos = photos,
                )
            }
            RoomRecord(id = roomId, name = roomRow.name, evidence = evidence)
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
