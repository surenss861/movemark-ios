package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import java.util.UUID

/*
 * MoveMark — everything the evidence packet builder shows, derived from the rental and its exports (iOS
 * `DisputePacketModel`). Choosing rooms focuses the review on this screen; the generated PDF always covers the
 * full rental record.
 */
data class DisputePacketModel(
    val title: String,
    val rooms: List<RoomRecord>,
    val selectedRoomIds: Set<UUID>,
    val records: List<Record>,
    val missing: List<Missing>,
    val moveInPhotos: Int,
    val moveOutPhotos: Int,
    val documents: Int,
    val issues: Int,
    val moveInReportIncluded: Boolean,
    val packet: Packet,
    val hasPro: Boolean,
) {
    sealed class Packet {
        data object NeedsMoveInProof : Packet()
        data object Ready : Packet()
        data object Generating : Packet()
        data class Generated(val date: String) : Packet()

        /** The newest packet failed; [lastGoodDate] is set when an earlier packet can still be opened. */
        data class Failed(val lastGoodDate: String?) : Packet()
    }

    enum class RecordKind { Report, Document, Maintenance }

    data class Record(val id: String, val title: String, val kind: RecordKind, val detail: String)

    data class Missing(val id: String, val title: String, val detail: String, val target: Target) {
        enum class Target { RentalRecord, MoveOut, Rooms, Reports }
    }

    /** Rooms with any proof can be named as involved; a room with nothing recorded adds nothing. */
    val selectableRooms: List<RoomRecord>
        get() = rooms.filter { it.totals(moveOut = false).photos > 0 || it.moveOutEvidence.isNotEmpty() || it.totals(moveOut = true).photos > 0 }

    val involved: List<MoveOutComparison>
        get() = selectableRooms.filter { it.id in selectedRoomIds }.map(MoveOutComparison::make)

    val statusLine: String
        get() = when (packet) {
            Packet.NeedsMoveInProof -> "Needs move-in proof"
            Packet.Ready, is Packet.Failed -> "Ready to generate"
            Packet.Generating -> "Generating"
            is Packet.Generated -> "Generated ${packet.date}"
        }

    val isReadyState: Boolean get() = packet == Packet.Ready || packet is Packet.Generated
    val isGenerated: Boolean get() = packet is Packet.Generated

    /** "8 move-in photos · …" — the counts the PDF states. */
    val contentLines: List<String>
        get() {
            fun n(count: Int, one: String, many: String) = "$count ${if (count == 1) one else many}"
            return listOf(
                "Full rental evidence",
                n(moveInPhotos, "move-in photo", "move-in photos"),
                n(moveOutPhotos, "move-out photo", "move-out photos"),
                n(documents, "document", "documents"),
                n(issues, "recorded issue", "recorded issues"),
                if (moveInReportIncluded) "Move-in report included" else "Move-in report not attached",
                "Dated rental timeline",
            )
        }

    companion object {
        val PACKET_TYPES = setOf("dispute_packet", "dispute_summary")

        fun isActive(row: ExportRow) = row.verification == ExportVerificationStatus.Queued ||
            row.verification == ExportVerificationStatus.Processing || row.verification == ExportVerificationStatus.Verifying

        fun isReady(row: ExportRow) = row.verification == ExportVerificationStatus.Ready
        fun isFailed(row: ExportRow) = row.verification == ExportVerificationStatus.ServerFailed

        fun make(
            property: PropertyRecord,
            maintenance: List<MaintenanceRecord>,
            exports: List<ExportRow>,
            selectedRoomIds: Set<UUID>,
            hasPro: Boolean,
            requesting: Boolean = false,
        ): DisputePacketModel {
            val rooms = property.rooms
            val moveInPhotos = rooms.sumOf { it.totals(moveOut = false).photos }
            val moveOutPhotos = rooms.sumOf { it.totals(moveOut = true).photos }

            fun latestReady(vararg types: String) = exports.filter { it.type in types && isReady(it) }.maxByOrNull { it.requestedAt.orEmpty() }
            val moveInReport = latestReady("move_in_report")
            val moveOutReport = latestReady("move_out_report")

            val records = mutableListOf<Record>()
            val missing = mutableListOf<Missing>()
            if (moveInReport != null) {
                records += Record("moveInReport", "Move-in report", RecordKind.Report, generatedDetail(moveInReport))
            } else if (moveInPhotos > 0) {
                missing += Missing("moveInReport", "Move-in report not generated", "The packet notes your move-in report and its date.", Missing.Target.Reports)
            }
            if (moveOutReport != null) {
                records += Record("moveOutReport", "Move-out report", RecordKind.Report, generatedDetail(moveOutReport))
            }
            if (moveOutPhotos == 0) {
                missing += Missing("moveOut", "Move-out proof not recorded", "Photograph each room before you return the keys.", Missing.Target.MoveOut)
            }
            var documents = 0
            val documentTypes = listOf(
                Triple(VaultDocumentKind.Lease, "Lease agreement", "Ties the packet to this rental."),
                Triple(VaultDocumentKind.DepositReceipt, "Deposit receipt", "Shows what you paid, and when."),
                Triple(VaultDocumentKind.ListingScreenshot, "Listing proof", "Shows how the rental was advertised."),
            )
            for ((kind, title, reason) in documentTypes) {
                if (VaultDocumentKind.isPresent(kind, property.documentTypes)) {
                    documents++
                    records += Record(kind.raw, title, RecordKind.Document, "On your rental record")
                } else if (kind != VaultDocumentKind.ListingScreenshot) {
                    missing += Missing(kind.raw, "$title not added", reason, Missing.Target.RentalRecord)
                }
            }
            if (maintenance.isNotEmpty()) {
                val open = maintenance.count { it.status != "resolved" }
                val cases = if (maintenance.size == 1) "1 case recorded" else "${maintenance.size} cases recorded"
                records += Record("maintenance", "Maintenance log", RecordKind.Maintenance, if (open == 0) "$cases · all resolved" else "$cases · $open open")
            }
            if (moveInPhotos == 0) {
                missing.add(0, Missing("moveInProof", "Move-in proof not recorded", "A packet starts from the condition you moved into.", Missing.Target.Rooms))
            }

            val issueTags = rooms.flatMap { r -> (r.moveInEvidence + r.moveOutEvidence).flatMap { it.issueTags } }.toSet()
            val packets = exports.filter { it.type in PACKET_TYPES }
            // Decided by the newest packet: an old failure never hides a newer packet, and a newer failure keeps the
            // last good packet openable.
            val newest = packets.maxByOrNull { it.requestedAt.orEmpty() }
            val lastGood = packets.filter(::isReady).maxByOrNull { it.requestedAt.orEmpty() }
            var packet = when {
                moveInPhotos == 0 && moveInReport == null -> Packet.NeedsMoveInProof
                packets.any(::isActive) -> Packet.Generating
                newest != null && isFailed(newest) -> Packet.Failed(lastGood?.let { MoveOutComparison.day(it.requestedAt).orEmpty() })
                lastGood != null -> Packet.Generated(MoveOutComparison.day(lastGood.requestedAt).orEmpty())
                else -> Packet.Ready
            }
            // A request in flight reads as generating.
            if (requesting && packet != Packet.NeedsMoveInProof) packet = Packet.Generating

            return DisputePacketModel(
                title = property.title.trim().ifEmpty { property.addressLine1 },
                rooms = rooms,
                selectedRoomIds = selectedRoomIds,
                records = records,
                missing = missing,
                moveInPhotos = moveInPhotos,
                moveOutPhotos = moveOutPhotos,
                documents = documents,
                issues = issueTags.size + maintenance.size,
                moveInReportIncluded = moveInReport != null,
                packet = packet,
                hasPro = hasPro,
            )
        }

        /** First open: start from what MoveMark already found — the rooms that differ at move-out. */
        fun defaultSelection(rooms: List<RoomRecord>): Set<UUID> = rooms.filter {
            val state = MoveOutComparison.make(it).state
            state == MoveOutComparison.State.Changed || state == MoveOutComparison.State.NewIssue
        }.map { it.id }.toSet()

        /** The newest openable packet. */
        fun latestPacket(exports: List<ExportRow>): ExportRow? =
            exports.filter { it.type in PACKET_TYPES && isReady(it) }.maxByOrNull { it.requestedAt.orEmpty() }

        private fun generatedDetail(row: ExportRow) =
            MoveOutComparison.day(row.requestedAt)?.let { "Generated $it · PDF" } ?: "PDF ready"
    }
}
