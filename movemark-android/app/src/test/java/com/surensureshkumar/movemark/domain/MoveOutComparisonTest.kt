package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.models.StageTotals
import com.surensureshkumar.movemark.domain.MoveOutComparison.State
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneOffset
import java.util.UUID

class MoveOutComparisonTest {
    private fun entry(
        photos: Int = 1,
        condition: Int? = 4,
        tags: List<String> = emptyList(),
        at: String = "2026-04-14T10:00:00Z",
        notes: String = "",
        title: String = "Kitchen",
    ) = EvidenceRecord(
        id = UUID.randomUUID(),
        title = title,
        notes = notes,
        photoCount = photos,
        photos = List(photos) { EvidencePhoto(UUID.randomUUID(), "p$it.jpg") },
        conditionRating = condition,
        createdAt = at,
        issueTags = tags,
    )

    private fun room(
        moveIn: List<EvidenceRecord> = emptyList(),
        moveOut: List<EvidenceRecord> = emptyList(),
        name: String = "Kitchen",
        moveOutUnloaded: StageTotals? = null,
    ) = RoomRecord(UUID.randomUUID(), name, moveIn, moveOut, moveOutUnloaded = moveOutUnloaded)

    @Test
    fun noMoveOutPhotoIsMissingEvenWithAnEmptyEntry() {
        assertEquals(State.Missing, MoveOutComparison.make(room(listOf(entry()), listOf(entry(photos = 0)))).state)
    }

    @Test
    fun serverTotalsCountPhotosNotYetLoaded() {
        val r = room(listOf(entry()), moveOutUnloaded = StageTotals(entries = 1, photos = 3))
        assertEquals(State.Unchanged, MoveOutComparison.make(r).state)
        assertEquals(3, MoveOutComparison.make(r).moveOutPhotoCount)
    }

    @Test
    fun noMoveInPhotoIsNoBaselineAndClaimsNoChange() {
        val c = MoveOutComparison.make(room(moveOut = listOf(entry(condition = 1, tags = listOf("Stain")))))
        assertEquals(State.NoBaseline, c.state)
        assertNull(c.headline)
    }

    @Test
    fun aNewTagIsANewIssueCaseAndSpaceInsensitive() {
        val c = MoveOutComparison.make(
            room(
                moveIn = listOf(entry(tags = listOf("Scratch"))),
                moveOut = listOf(entry(tags = listOf(" scratch ", "Stain", "STAIN", "Water damage", "Chipped paint", "Cracked tile"))),
            ),
        )
        assertEquals(State.NewIssue, c.state)
        assertEquals(listOf("Stain", "Water damage", "Chipped paint", "Cracked tile"), c.newTags)
        assertEquals("New issue recorded: Stain, Water damage, Chipped paint and 1 more", c.headline)
    }

    @Test
    fun aLowerNewestConditionIsChanged() {
        val c = MoveOutComparison.make(
            room(
                moveIn = listOf(entry(condition = 2, at = "2026-04-01T00:00:00Z"), entry(condition = 4, at = "2026-04-14T00:00:00Z")),
                moveOut = listOf(entry(condition = 3, at = "2027-03-30T00:00:00Z")),
            ),
        )
        assertEquals(State.Changed, c.state)
        assertEquals("Condition Good → Fair", c.headline)
    }

    @Test
    fun sameOrBetterIsUnchanged() {
        val c = MoveOutComparison.make(room(listOf(entry(condition = 3)), listOf(entry(condition = 5))))
        assertEquals(State.Unchanged, c.state)
        assertNull(c.conditionLine)
    }

    @Test
    fun theRentersWordsSkipARepeatOfTheRoomNameAndAreShortened() {
        val long = "x".repeat(120)
        val c = MoveOutComparison.make(room(listOf(entry(notes = "", title = " kitchen ")), listOf(entry(notes = long))))
        assertNull(c.moveInText)
        assertEquals(89, c.moveOutText!!.length)
        assertTrue(c.moveOutText!!.endsWith("…"))
    }

    @Test
    fun shortDay() {
        assertEquals("Oct 24", MoveOutComparison.day("2026-10-24T15:00:00Z", ZoneOffset.UTC))
        assertEquals("Oct 24", MoveOutComparison.day("2026-10-24T15:00:00.123456+00:00", ZoneOffset.UTC))
        assertNull(MoveOutComparison.day("garbage"))
    }

    @Test
    fun overviewGroupsInIosOrderAndTracksProgress() {
        val rooms = listOf(
            room(listOf(entry(condition = 4)), listOf(entry(condition = 3)), "Changed room"),
            room(listOf(entry()), emptyList(), "Missing room"),
            room(listOf(entry(tags = emptyList())), listOf(entry(tags = listOf("Stain"))), "New issue room"),
            room(listOf(entry()), listOf(entry()), "Same room"),
            room(emptyList(), listOf(entry()), "No baseline room"),
        )
        val o = MoveOutOverview(rooms)
        assertEquals(listOf("New issue room", "Changed room"), o.changed.map { it.roomName })
        assertEquals(listOf("Missing room"), o.missing.map { it.roomName })
        assertEquals(listOf("Same room"), o.unchanged.map { it.roomName })
        assertEquals(listOf("No baseline room"), o.notCompared.map { it.roomName })
        assertEquals(4, o.roomsWithMoveOutPhotos)
        assertTrue(o.hasBaseline)
        assertFalse(o.isComplete)
        assertFalse("4 of 5 is under 90%", o.isSubstantiallyCompared)
        assertEquals("Complete the remaining room to generate the move-out report.", o.remainingRoomsLine)
        assertEquals(setOf(rooms[1].id), o.missingIds)
    }

    @Test
    fun substantiallyComparedAtNineOfTen() {
        val rooms = List(9) { room(listOf(entry()), listOf(entry())) } + room(listOf(entry()))
        assertTrue(MoveOutOverview(rooms).isSubstantiallyCompared)
    }

    @Test
    fun justComparedLineNamesOnlyRoomsWithBothEnds() {
        val a = room(listOf(entry()), listOf(entry()), "Kitchen")
        val b = room(listOf(entry()), listOf(entry()), "Bath")
        val c = room(emptyList(), listOf(entry()), "Hall")
        val o = MoveOutOverview(listOf(a, b, c))
        assertEquals("Kitchen now has proof at both ends, compared with your move-in record.", o.justComparedLine(setOf(a.id, c.id)))
        assertEquals(
            "Kitchen and Bath now have proof at both ends, compared with your move-in record.",
            o.justComparedLine(setOf(a.id, b.id)),
        )
        assertNull(o.justComparedLine(setOf(c.id)))
    }
}
