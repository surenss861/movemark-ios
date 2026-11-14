package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidenceFileRow
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.RoomEntriesPage
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.models.SnapshotEntries
import com.surensureshkumar.movemark.data.models.StageStats
import com.surensureshkumar.movemark.data.models.StageTotals
import java.util.UUID

/**
 * Snapshot v2 entry assembly and keyset paging (iOS `PropertyStore+Hydration` / `PropertyStore+History`).
 * The snapshot loads each room's newest entries and each entry's first photos; the rest load through keyset
 * pages (newest-first entries, capture-order photos), so a rental with years of proof never has to come down
 * in one response — and none of it is ever hidden or capped. Pure functions, so the remainder math and
 * cursors are unit-tested without a server.
 */
object EvidenceHistory {
    /** Photos (capture order) and tags of the loaded entries, plus each entry's true photo count. */
    class EntryParts(
        val photosByItem: Map<String, List<EvidencePhoto>>,
        val tagsByItem: Map<String, List<String>>,
        val photoCountByItem: Map<String, Int>,
    )

    fun entryParts(entries: SnapshotEntries): EntryParts {
        val photos = LinkedHashMap<String, MutableList<EvidencePhoto>>()
        for (file in entries.evidenceFiles) { // already in capture order (created_at, id)
            val itemId = file.inspectionItemId?.lowercase() ?: continue
            photos.getOrPut(itemId) { mutableListOf() } += evidencePhoto(file)
        }
        val tags = LinkedHashMap<String, MutableList<String>>()
        for (tag in entries.itemTags) tags.getOrPut(tag.inspectionItemId.lowercase()) { mutableListOf() } += tag.name
        return EntryParts(photos, tags, entries.photoCounts.mapKeys { it.key.lowercase() })
    }

    fun evidencePhoto(file: EvidenceFileRow) = EvidencePhoto(
        id = UUID.fromString(file.id),
        filePath = file.filePath,
        thumbnailPath = file.thumbnailPath,
        serverCreatedAt = file.createdAt,
    )

    fun evidenceRecord(item: InspectionItemRow, parts: EntryParts, defaultTitle: String): EvidenceRecord {
        val key = item.id.lowercase()
        val photos = parts.photosByItem[key].orEmpty()
        val tags = parts.tagsByItem[key].orEmpty()
        val (title, notes) = parseNotes(item.notes, defaultTitle)
        return EvidenceRecord(
            id = UUID.fromString(item.id),
            title = title,
            notes = notes,
            // The server's count is the truth; never fewer than what is loaded.
            photoCount = maxOf(parts.photoCountByItem[key] ?: photos.size, photos.size),
            photos = photos,
            conditionRating = item.conditionRating,
            createdAt = item.createdAt,
            issueTagCount = tags.size,
            issueTags = tags,
            serverCreatedAt = item.createdAt,
        )
    }

    /** What the server counted for a room/stage beyond the loaded entries; null when everything is loaded. */
    fun unloaded(stats: StageStats?, loaded: List<EvidenceRecord>): StageTotals? {
        stats ?: return null
        val have = RoomRecord.sum(loaded, null)
        val rest = StageTotals(
            entries = maxOf(stats.entries - have.entries, 0),
            photos = maxOf(stats.photos - have.photos, 0),
            notedEntries = maxOf(stats.entriesWithNotes - have.notedEntries, 0),
            issueTags = maxOf(stats.issueTags - have.issueTags, 0),
            latestAt = null, // the newest entries are always the loaded ones
        )
        return rest.takeIf { it.entries > 0 }
    }

    /** Keyset cursor (created_at, id) for the next page of older entries. */
    data class Cursor(val createdAt: String, val id: String)

    /**
     * The oldest loaded entry, by the server's exact `created_at`. Entries saved in this session have no server
     * timestamp yet; they are the newest, never the cursor. Null when nothing loaded has a server timestamp.
     */
    fun olderEntriesCursor(loaded: List<EvidenceRecord>): Cursor? =
        loaded.mapNotNull { entry -> entry.serverCreatedAt?.let { Cursor(it, entry.id.toString().lowercase()) } }
            .minWithOrNull(compareBy<Cursor> { it.createdAt }.thenBy { it.id })

    /** Keyset cursor for the photos after the last loaded one (capture order). */
    fun photosCursor(photos: List<EvidencePhoto>): Cursor? =
        photos.lastOrNull()?.let { last -> last.serverCreatedAt?.let { Cursor(it, last.id.toString().lowercase()) } }

    /**
     * Appends a page of older entries to [room] and moves them out of its unloaded remainder, so totals stay
     * exactly what the server counted. Entries already loaded are skipped (never duplicated).
     */
    fun applyOlderEntries(room: RoomRecord, moveOut: Boolean, page: RoomEntriesPage, defaultTitle: String): RoomRecord {
        val parts = entryParts(page.entries)
        val known = room.evidence(moveOut).map { it.id }.toSet()
        val fresh = page.inspectionItems.map { evidenceRecord(it, parts, defaultTitle) }.filter { it.id !in known }
        val added = RoomRecord.sum(fresh, null)
        val rest = room.unloaded(moveOut) ?: StageTotals()
        val remaining = StageTotals(
            entries = maxOf(rest.entries - added.entries, 0),
            photos = maxOf(rest.photos - added.photos, 0),
            notedEntries = maxOf(rest.notedEntries - added.notedEntries, 0),
            issueTags = maxOf(rest.issueTags - added.issueTags, 0),
        ).takeIf { page.hasMore && it.entries > 0 }
        return if (moveOut) {
            room.copy(moveOutEvidence = room.moveOutEvidence + fresh, moveOutUnloaded = remaining)
        } else {
            room.copy(moveInEvidence = room.moveInEvidence + fresh, moveInUnloaded = remaining)
        }
    }

    /** Appends photos to an entry, skipping ones already loaded. */
    fun appendPhotos(entry: EvidenceRecord, page: List<EvidenceFileRow>): EvidenceRecord {
        val known = entry.photos.map { it.id }.toSet()
        val fresh = page.map(::evidencePhoto).filter { it.id !in known }
        val photos = entry.photos + fresh
        return entry.copy(photos = photos, photoCount = maxOf(entry.photoCount, photos.size))
    }

    /** Parses inspection item notes stored as "title\nnotes" (title first line, as on iOS). */
    fun parseNotes(raw: String?, defaultTitle: String): Pair<String, String> {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return defaultTitle to ""
        val idx = trimmed.indexOf('\n')
        return if (idx >= 0) {
            trimmed.substring(0, idx).trim().ifEmpty { defaultTitle } to trimmed.substring(idx + 1).trim()
        } else {
            trimmed to ""
        }
    }
}
