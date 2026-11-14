package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidenceFileRow
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.InspectionItemRow
import com.surensureshkumar.movemark.data.models.ItemTagRow
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.PropertySnapshotV2
import com.surensureshkumar.movemark.data.models.RoomEntriesPage
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.models.SnapshotEntries
import com.surensureshkumar.movemark.data.models.StageStats
import com.surensureshkumar.movemark.data.models.StageTotals
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class EvidenceHistoryTest {
    private fun uuid(n: Int) = UUID.fromString("00000000-0000-4000-8000-%012d".format(n))
    private fun item(n: Int, createdAt: String, notes: String = "Entry $n") =
        InspectionItemRow(uuid(n).toString(), "insp", "room", notes, 4, createdAt)
    private fun file(n: Int, item: Int, createdAt: String) =
        EvidenceFileRow(uuid(1000 + n).toString(), "prop", uuid(item).toString(), null, "f$n.jpg", "image", null, createdAt, "f${n}_thumb.jpg")
    private fun entry(n: Int, photos: Int, serverCreatedAt: String?, notes: String = "", tags: Int = 0) = EvidenceRecord(
        id = uuid(n), title = "E$n", notes = notes, photoCount = photos,
        issueTags = List(tags) { "t$it" }, issueTagCount = tags, createdAt = serverCreatedAt, serverCreatedAt = serverCreatedAt,
    )

    @Test
    fun photoCountIsServerCountButNeverBelowLoaded() {
        val entries = SnapshotEntries(
            photoCounts = mapOf(uuid(1).toString() to 40, uuid(2).toString().uppercase() to 0),
            evidenceFiles = listOf(file(1, 1, "2026-10-22T09:00:00+00:00"), file(2, 2, "2026-10-22T09:00:01+00:00")),
            itemTags = listOf(ItemTagRow(uuid(1).toString(), "Stain")),
        )
        val parts = EvidenceHistory.entryParts(entries)
        val one = EvidenceHistory.evidenceRecord(item(1, "2026-10-22T09:00:00.123456+00:00", "Title\nNote"), parts, "Move-in capture")
        assertEquals(40, one.photoCount)
        assertEquals(1, one.photos.size)
        assertTrue(one.hasUnloadedPhotos)
        assertEquals(listOf("Stain"), one.issueTags)
        assertEquals("Title" to "Note", one.title to one.notes)
        assertEquals("2026-10-22T09:00:00.123456+00:00", one.serverCreatedAt) // raw, for cursors
        assertEquals("2026-10-22T09:00:00+00:00", one.photos.single().serverCreatedAt)

        val two = EvidenceHistory.evidenceRecord(item(2, "2026-10-22T09:00:01+00:00"), parts, "Move-in capture")
        assertEquals(1, two.photoCount) // a stale 0 never hides a loaded photo
    }

    @Test
    fun remainderIsServerTotalsMinusLoaded() {
        val loaded = listOf(entry(1, 12, "b", notes = "n", tags = 2), entry(2, 3, "a"))
        val stats = StageStats(entries = 50, photos = 400, entriesWithNotes = 10, issueTags = 7, latestAt = "z")
        val rest = EvidenceHistory.unloaded(stats, loaded)!!
        assertEquals(StageTotals(entries = 48, photos = 385, notedEntries = 9, issueTags = 5, latestAt = null), rest)

        val room = RoomRecord(uuid(9), "Kitchen", moveInEvidence = loaded, moveInUnloaded = rest)
        val totals = room.totals(moveOut = false)
        assertEquals(50, totals.entries)
        assertEquals(400, totals.photos)
        assertEquals(10, totals.notedEntries)
        assertEquals(7, totals.issueTags)
        assertEquals(400, RoomProofMetrics.photoCount(room))
        assertTrue(room.hasOlderEntries(moveOut = false))
        assertFalse(room.hasOlderEntries(moveOut = true))

        // Everything loaded: no remainder.
        assertNull(EvidenceHistory.unloaded(StageStats(entries = 2, photos = 15), loaded))
        assertNull(EvidenceHistory.unloaded(null, loaded))
    }

    @Test
    fun olderEntriesCursorIsTheOldestServerTimestampedEntry() {
        val loaded = listOf(
            entry(3, 1, null), // saved this session: never the cursor
            entry(1, 1, "2026-10-22T09:15:01.24133+00:00"),
            entry(2, 1, "2026-10-22T09:15:01.2+00:00"),
            entry(4, 1, "2026-10-22T09:15:01.2+00:00"),
        )
        val cursor = EvidenceHistory.olderEntriesCursor(loaded)!!
        assertEquals("2026-10-22T09:15:01.2+00:00", cursor.createdAt)
        assertEquals(uuid(2).toString(), cursor.id) // ties broken by id
        assertNull(EvidenceHistory.olderEntriesCursor(listOf(entry(3, 1, null))))
    }

    @Test
    fun olderPageMovesEntriesOutOfTheRemainderWithoutDuplicates() {
        val loaded = listOf(entry(1, 2, "2026-10-22T10:00:00+00:00"))
        val room = RoomRecord(
            uuid(9), "Kitchen", moveInEvidence = loaded,
            moveInUnloaded = StageTotals(entries = 3, photos = 7, notedEntries = 1, issueTags = 0),
        )
        val page = RoomEntriesPage(
            inspectionItems = listOf(
                item(1, "2026-10-22T10:00:00+00:00"), // already loaded: skipped
                item(5, "2026-10-21T10:00:00+00:00", "Old\nwith notes"),
                item(6, "2026-10-20T10:00:00+00:00"),
            ),
            entries = SnapshotEntries(photoCounts = mapOf(uuid(5).toString() to 4, uuid(6).toString() to 2)),
            hasMore = true,
        )
        val next = EvidenceHistory.applyOlderEntries(room, moveOut = false, page = page, defaultTitle = "Move-in capture")
        assertEquals(listOf(uuid(1), uuid(5), uuid(6)), next.moveInEvidence.map { it.id })
        assertEquals(StageTotals(entries = 1, photos = 1, notedEntries = 0, issueTags = 0), next.moveInUnloaded)
        // Totals never change by loading: still what the server counted.
        assertEquals(room.totals(false).entries, next.totals(false).entries)
        assertEquals(room.totals(false).photos, next.totals(false).photos)

        val last = EvidenceHistory.applyOlderEntries(
            next, moveOut = false,
            page = RoomEntriesPage(listOf(item(7, "2026-10-19T10:00:00+00:00")), SnapshotEntries(mapOf(uuid(7).toString() to 1)), hasMore = false),
            defaultTitle = "Move-in capture",
        )
        assertNull(last.moveInUnloaded)
        assertFalse(last.hasOlderEntries(moveOut = false))
    }

    @Test
    fun photosPageAppendsAfterTheLastLoadedPhoto() {
        val entry = EvidenceRecord(
            id = uuid(1), title = "E", notes = "", photoCount = 3,
            photos = listOf(EvidencePhoto(uuid(1001), "f1.jpg", serverCreatedAt = "2026-10-22T09:00:00+00:00")),
        )
        val cursor = EvidenceHistory.photosCursor(entry.photos)!!
        assertEquals("2026-10-22T09:00:00+00:00" to uuid(1001).toString(), cursor.createdAt to cursor.id)

        val more = EvidenceHistory.appendPhotos(
            entry,
            listOf(file(1, 1, "2026-10-22T09:00:00+00:00"), file(2, 1, "2026-10-22T09:00:01+00:00"), file(3, 1, "2026-10-22T09:00:02+00:00")),
        )
        assertEquals(listOf(uuid(1001), uuid(1002), uuid(1003)), more.photos.map { it.id })
        assertFalse(more.hasUnloadedPhotos)
        assertNull(EvidenceHistory.photosCursor(emptyList()))
    }

    @Test
    fun hydratorBuildsTrueTotalsFromSnapshotV2() {
        val json = """
        {"limits":{"entries_per_room":30,"photos_per_entry":12},
         "property":null,
         "rooms":[{"id":"${uuid(9)}","property_id":"prop","name":"Kitchen","sort_order":0,
                   "stats":{"move_in":{"entries":31,"photos":250,"entries_with_notes":0,"issue_tags":0,"latest_at":"2026-10-22T10:00:00+00:00"}}},
                  {"id":"${uuid(8)}","property_id":"prop","name":"Hallway","sort_order":1,"stats":{}}],
         "inspections":[{"id":"insp","property_id":"prop","user_id":"u","inspection_type":"move_in"}],
         "inspection_items":[{"id":"${uuid(1)}","inspection_id":"insp","room_id":"${uuid(9)}","notes":"Kitchen\n","condition_rating":4,"created_at":"2026-10-22T10:00:00.5+00:00"}],
         "entries":{"photo_counts":{"${uuid(1)}":20},"evidence_files":[],"item_tags":[]},
         "documents":[],"document_types":["lease","deposit-receipt"],"document_count":2,
         "maintenance_issues":[{"id":"${uuid(50)}","property_id":"prop","user_id":"u","title":"Leak","status":"open"}],
         "maintenance_count":1,"maintenance_photo_counts":{"${uuid(50)}":3}}
        """.trimIndent()
        val snapshot = Json { ignoreUnknownKeys = true }.decodeFromString(PropertySnapshotV2.serializer(), json)
        val row = PropertyRow("prop", "u", "Home", "1 Main", null, "City", "ON", "A1A", "CA")
        val hydrated = PropertyHydrator.build(uuid(100), row, snapshot)

        val kitchen = hydrated.record.rooms.first()
        assertEquals(1, kitchen.moveInEvidence.size)
        assertEquals(31, kitchen.totals(false).entries)
        assertEquals(250, kitchen.totals(false).photos)
        assertTrue(kitchen.hasOlderEntries(false))
        assertEquals(0, hydrated.record.rooms[1].totals(false).photos)
        assertEquals(2, hydrated.record.supportingRecordCount)
        assertEquals(3, hydrated.maintenance.single().photoCount)
        assertEquals(1, RoomProofMetrics.documentedCount(hydrated.record))
    }
}
