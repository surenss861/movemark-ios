package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.remote.ExportJobStatus
import com.surensureshkumar.movemark.domain.DisputePacketModel.Missing.Target
import com.surensureshkumar.movemark.domain.DisputePacketModel.Packet
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class DisputePacketModelTest {
    private fun entry(condition: Int = 4, tags: List<String> = emptyList(), photos: Int = 2) = EvidenceRecord(
        UUID.randomUUID(), "Entry", "", photos, List(photos) { EvidencePhoto(UUID.randomUUID(), "p.jpg") },
        conditionRating = condition, createdAt = "2026-04-14T10:00:00Z", issueTags = tags,
    )

    private fun property(rooms: List<RoomRecord>, docs: List<String> = emptyList()) =
        PropertyRecord(UUID.randomUUID(), "12 Elm St", "12 Elm St", "Toronto", "ON", rooms, documentTypes = docs)

    private fun export(type: String, status: ExportVerificationStatus, at: String) = ExportRow(
        UUID.randomUUID(), type, ExportJobStatus.Completed, status, at, if (status == ExportVerificationStatus.Ready) "f.pdf" else null,
    )

    private val kitchen = RoomRecord(UUID.randomUUID(), "Kitchen", listOf(entry(tags = listOf("Scratch"))), listOf(entry(condition = 2, tags = listOf("Stain"))))
    private val bath = RoomRecord(UUID.randomUUID(), "Bath", listOf(entry()), emptyList())
    private val empty = RoomRecord(UUID.randomUUID(), "Closet")

    @Test
    fun withoutMoveInProofItAsksForItFirst() {
        val m = DisputePacketModel.make(property(listOf(empty)), emptyList(), emptyList(), emptySet(), hasPro = true)
        assertEquals(Packet.NeedsMoveInProof, m.packet)
        assertEquals("moveInProof", m.missing.first().id)
        assertEquals(Target.Rooms, m.missing.first().target)
        assertTrue(m.selectableRooms.isEmpty())
    }

    @Test
    fun recordsMissingAndCountsMatchIos() {
        val maintenance = listOf(
            MaintenanceRecord(UUID.randomUUID(), "Leak", "Plumbing", "", "open", null, 0, null),
            MaintenanceRecord(UUID.randomUUID(), "Heat", "HVAC", "", "resolved", null, 0, null),
        )
        val exports = listOf(export("move_in_report", ExportVerificationStatus.Ready, "2026-04-20T10:00:00Z"))
        val m = DisputePacketModel.make(property(listOf(kitchen, bath, empty), docs = listOf("lease", "listing-screenshot")), maintenance, exports, emptySet(), hasPro = false)
        assertEquals(listOf("moveInReport", "lease", "listing_screenshot", "maintenance"), m.records.map { it.id })
        assertEquals("Generated Apr 20 · PDF", m.records.first().detail)
        assertEquals("2 cases recorded · 1 open", m.records.last().detail)
        assertEquals(listOf("deposit_receipt"), m.missing.map { it.id })
        assertEquals(4, m.moveInPhotos)
        assertEquals(2, m.moveOutPhotos)
        assertEquals(2, m.documents)
        assertEquals("2 tags + 2 cases", 4, m.issues)
        assertEquals(Packet.Ready, m.packet)
        assertEquals(
            listOf("Full rental evidence", "4 move-in photos", "2 move-out photos", "2 documents", "4 recorded issues", "Move-in report included", "Dated rental timeline"),
            m.contentLines,
        )
        assertEquals(listOf("Kitchen", "Bath"), m.selectableRooms.map { it.name })
    }

    @Test
    fun theNewestPacketDecidesTheState() {
        val good = export("dispute_packet", ExportVerificationStatus.Ready, "2026-05-01T10:00:00Z")
        val failedLater = export("dispute_packet", ExportVerificationStatus.ServerFailed, "2026-05-03T10:00:00Z")
        val p = property(listOf(kitchen))
        assertEquals(Packet.Generated("May 1"), DisputePacketModel.make(p, emptyList(), listOf(good), emptySet(), true).packet)
        assertEquals(Packet.Failed("May 1"), DisputePacketModel.make(p, emptyList(), listOf(good, failedLater), emptySet(), true).packet)
        val olderFailure = failedLater.copy(requestedAt = "2026-04-01T10:00:00Z")
        assertEquals(Packet.Generated("May 1"), DisputePacketModel.make(p, emptyList(), listOf(good, olderFailure), emptySet(), true).packet)
        val active = export("dispute_summary", ExportVerificationStatus.Processing, "2026-05-04T10:00:00Z")
        assertEquals(Packet.Generating, DisputePacketModel.make(p, emptyList(), listOf(good, active), emptySet(), true).packet)
        assertEquals(Packet.Generating, DisputePacketModel.make(p, emptyList(), emptyList(), emptySet(), true, requesting = true).packet)
        assertEquals(good.id, DisputePacketModel.latestPacket(listOf(good, failedLater))?.id)
    }

    @Test
    fun involvedRoomsAndTheDefaultSelection() {
        val rooms = listOf(kitchen, bath, empty)
        assertEquals(setOf(kitchen.id), DisputePacketModel.defaultSelection(rooms))
        val m = DisputePacketModel.make(property(rooms), emptyList(), emptyList(), setOf(kitchen.id, bath.id, empty.id), true)
        assertEquals(listOf(MoveOutComparison.State.NewIssue, MoveOutComparison.State.Missing), m.involved.map { it.state })
    }
}
