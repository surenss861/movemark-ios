package com.surensureshkumar.movemark.features.vault

import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class RecentEvidenceTest {
    private fun entry(at: String, vararg paths: Pair<String, String?>) = EvidenceRecord(
        id = UUID.randomUUID(), title = "t", notes = "", photoCount = paths.size, createdAt = at,
        photos = paths.map { (file, thumb) -> EvidencePhoto(id = UUID.randomUUID(), filePath = file, thumbnailPath = thumb) },
    )

    @Test
    fun newestPhotoPerRoomNewestRoomFirstPreferringThumbnails() {
        val kitchen = RoomRecord(id = UUID.randomUUID(), name = "Kitchen", moveInEvidence = listOf(entry("2026-10-23T10:00:00Z", "k.jpg" to null)))
        val living = RoomRecord(
            id = UUID.randomUUID(), name = "Living Room",
            moveInEvidence = listOf(entry("2026-10-20T10:00:00Z", "old.jpg" to null), entry("2026-10-26T04:24:00Z", "l.jpg" to "l_thumb.jpg", "l2.jpg" to null)),
        )
        val empty = RoomRecord(id = UUID.randomUUID(), name = "Bedroom")
        val property = PropertyRecord(UUID.randomUUID(), "My apartment", "", "Toronto", "Unknown", listOf(kitchen, living, empty))

        val recent = recentEvidence(property)

        assertEquals(listOf("Living Room", "Kitchen"), recent.map { it.roomName })
        assertEquals("l_thumb.jpg", recent[0].path)
        assertEquals(3, recent[0].photoCount)
        assertEquals("k.jpg", recent[1].path)
    }
}
