package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

/*
 * MoveMark — one room's move-in record (the baseline) beside its move-out record, the change stated first
 * (iOS `MoveOutComparison`, Shared/MMSystem+MoveOut.swift). Record language only: never a judgement of cause
 * or fault. Notes are shown but never interpreted.
 */
data class MoveOutComparison(
    val id: UUID,
    val roomName: String,
    val state: State,
    /** All loaded photos per side, newest entry first; the first is the one shown. */
    val moveInPhotos: List<EvidencePhoto>,
    val moveOutPhotos: List<EvidencePhoto>,
    val moveInPhotoCount: Int,
    val moveOutPhotoCount: Int,
    /** 1 Poor … 5 Excellent of the newest entry per side. */
    val moveInCondition: Int?,
    val moveOutCondition: Int?,
    val moveInText: String?,
    val moveOutText: String?,
    val moveInDate: String?,
    val moveOutDate: String?,
    /** Issue tags recorded at move-out that the move-in record doesn't carry. */
    val newTags: List<String>,
) {
    enum class State(val label: String) {
        /** Move-out records an issue tag the move-in record doesn't have. */
        NewIssue("New issue"),

        /** Move-out condition is worse than move-in condition. */
        Changed("Changed"),

        /** No move-out photo yet. */
        Missing("Move-out proof needed"),

        /** Photographed at both ends, no new issue, condition not worse. */
        Unchanged("Unchanged"),

        /** Move-out photos but no move-in photos, so nothing to compare against. */
        NoBaseline("No move-in baseline"),
    }

    val moveInPhoto: EvidencePhoto? get() = moveInPhotos.firstOrNull()
    val moveOutPhoto: EvidencePhoto? get() = moveOutPhotos.firstOrNull()
    val needsAttention: Boolean get() = state == State.NewIssue || state == State.Changed

    /** What changed, in record language; null when nothing changed. */
    val headline: String?
        get() = when (state) {
            State.NewIssue -> {
                val shown = newTags.take(3).joinToString(", ")
                val more = if (newTags.size > 3) " and ${newTags.size - 3} more" else ""
                "New issue recorded: $shown$more"
            }
            State.Changed -> conditionLine
            else -> null
        }

    /** "Condition Good → Fair" when the move-out rating is lower than move-in; null otherwise. */
    val conditionLine: String?
        get() {
            val a = moveInCondition ?: return null
            val b = moveOutCondition ?: return null
            return if (b < a) "Condition ${conditionLabel(a)} → ${conditionLabel(b)}" else null
        }

    companion object {
        /**
         * The comparison state rule, applied in this order:
         *  1. No move-out photo → Missing (an entry without photos doesn't count, mirroring the server's
         *     `not_enough_move_out_proof` guard).
         *  2. No move-in photo → NoBaseline: nothing to compare against, so no change is claimed.
         *  3. A move-out issue tag no move-in entry carries (case- and space-insensitive) → NewIssue.
         *  4. The newest move-out entry's condition is lower than the newest move-in entry's → Changed.
         *  5. Otherwise → Unchanged.
         * Tags and conditions come from the loaded entries (newest first); counts use the server totals.
         */
        fun make(room: RoomRecord): MoveOutComparison {
            val moveIn = room.moveInEvidence.newestFirst()
            val moveOut = room.moveOutEvidence.newestFirst()
            val latestIn = moveIn.firstOrNull()
            val latestOut = moveOut.firstOrNull()
            val moveInTotal = room.totals(moveOut = false).photos
            val moveOutTotal = room.totals(moveOut = true).photos

            fun key(tag: String) = tag.trim().lowercase()
            val baseline = moveIn.flatMap { it.issueTags }.map(::key).toSet()
            val seen = mutableSetOf<String>()
            val newTags = moveOut.flatMap { it.issueTags }.filter { tag ->
                val k = key(tag)
                k.isNotEmpty() && k !in baseline && seen.add(k)
            }
            val a = latestIn?.conditionRating
            val b = latestOut?.conditionRating
            val state = when {
                moveOutTotal == 0 -> State.Missing
                moveInTotal == 0 -> State.NoBaseline
                newTags.isNotEmpty() -> State.NewIssue
                a != null && b != null && b < a -> State.Changed
                else -> State.Unchanged
            }
            return MoveOutComparison(
                id = room.id,
                roomName = room.name,
                state = state,
                moveInPhotos = moveIn.flatMap { it.photos },
                moveOutPhotos = moveOut.flatMap { it.photos },
                moveInPhotoCount = moveInTotal,
                moveOutPhotoCount = moveOutTotal,
                moveInCondition = a,
                moveOutCondition = b,
                moveInText = text(latestIn, room.name),
                moveOutText = text(latestOut, room.name),
                moveInDate = latestIn?.createdAt,
                moveOutDate = latestOut?.createdAt,
                newTags = newTags,
            )
        }

        /** iOS `RoomRecord.ConditionRating` wording. */
        fun conditionLabel(rating: Int): String = when (rating) {
            1 -> "Poor"
            2 -> "Below fair"
            3 -> "Fair"
            4 -> "Good"
            else -> "Excellent"
        }

        /** "Oct 24": the two ends of one tenancy read best as short dates side by side. */
        fun day(raw: String?, zone: ZoneId = ZoneId.systemDefault()): String? {
            if (raw.isNullOrBlank()) return null
            val instant = runCatching { Instant.parse(raw) }.getOrNull()
                ?: runCatching { OffsetDateTime.parse(raw).toInstant() }.getOrNull()
                ?: return null
            return DAY.withZone(zone).format(instant)
        }

        /** The renter's own words for an entry: its note, else its title — unless it only repeats the room name. */
        private fun text(entry: EvidenceRecord?, roomName: String): String? {
            entry ?: return null
            val room = roomName.trim().lowercase()
            for (candidate in listOf(entry.notes, entry.title)) {
                val t = candidate.trim()
                if (t.isNotEmpty() && t.lowercase() != room) return if (t.length > 90) t.take(88) + "…" else t
            }
            return null
        }

        /** Newest first; an entry without a server time is one just saved on this device, so it counts as newest. */
        private fun List<EvidenceRecord>.newestFirst() = sortedByDescending { it.createdAt ?: "\uFFFF" }

        private val DAY: DateTimeFormatter = DateTimeFormatter.ofPattern("MMM d", Locale.US)
    }
}

/** The screen's grouping and progress (iOS `MoveOutFoundationView`). */
data class MoveOutOverview(val rooms: List<RoomRecord>) {
    val comparisons: List<MoveOutComparison> = rooms.map(MoveOutComparison::make)

    /** New issues first, then lower condition; each keeps the rooms' own order. */
    val changed = comparisons.filter { it.state == MoveOutComparison.State.NewIssue } +
        comparisons.filter { it.state == MoveOutComparison.State.Changed }
    val missing = comparisons.filter { it.state == MoveOutComparison.State.Missing }
    val unchanged = comparisons.filter { it.state == MoveOutComparison.State.Unchanged }
    val notCompared = comparisons.filter { it.state == MoveOutComparison.State.NoBaseline }

    /** Rooms with a move-out photo (the server's report guard). */
    val roomsWithMoveOutPhotos: Int = rooms.count { it.totals(moveOut = true).photos > 0 }

    /** Move-in photos exist somewhere: without them there is no baseline to compare against. */
    val hasBaseline: Boolean = rooms.any { it.totals(moveOut = false).photos > 0 }

    /** Every room has move-out photos, so the report is the next step. */
    val isComplete: Boolean = rooms.isNotEmpty() && roomsWithMoveOutPhotos == rooms.size

    /** All rooms compared, or nearly all (at least 90% and at most one room left). */
    val isSubstantiallyCompared: Boolean
        get() {
            if (rooms.isEmpty()) return false
            val left = rooms.size - roomsWithMoveOutPhotos
            return left == 0 || (left == 1 && roomsWithMoveOutPhotos.toDouble() / rooms.size >= 0.9)
        }

    val remainingRoomsLine: String
        get() {
            val left = rooms.size - roomsWithMoveOutPhotos
            return if (left == 1) "Complete the remaining room to generate the move-out report."
            else "Complete the remaining $left rooms to generate the move-out report."
        }

    /** Room ids still without move-out photos (to notice rooms that gain them while the screen is open). */
    val missingIds: Set<UUID> = rooms.filter { it.totals(moveOut = true).photos == 0 }.map { it.id }.toSet()

    /** "Kitchen now has proof at both ends…" for rooms compared while the screen was open. */
    fun justComparedLine(justCompared: Set<UUID>): String? {
        val names = rooms.filter {
            it.id in justCompared && it.totals(moveOut = true).photos > 0 && it.totals(moveOut = false).photos > 0
        }.map { it.name }
        val first = names.firstOrNull() ?: return null
        return when (names.size) {
            1 -> "$first now has proof at both ends, compared with your move-in record."
            2 -> "$first and ${names[1]} now have proof at both ends, compared with your move-in record."
            else -> "${names.size} more rooms now have proof at both ends, compared with your move-in record."
        }
    }
}
