package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

sealed class LifecycleNudge {
    abstract val title: String
    abstract val reason: String

    data class FinishRoomsBeforeUnpacking(val remaining: Int) : LifecycleNudge() {
        override val title =
            if (remaining == 1) "Finish 1 more room" else "Finish $remaining more rooms"
        override val reason =
            "Document rooms before you fully unpack — while damage is still visible."
    }

    data object AddLeaseAndDepositDocs : LifecycleNudge() {
        override val title = "Add lease & deposit receipt"
        override val reason =
            "Lease and deposit records strengthen your proof if money is disputed."
    }

    data object MakeMoveInReport : LifecycleNudge() {
        override val title = "Make your move-in report"
        override val reason = "Your room proof is ready — export a PDF before you need it."
    }

    data class MidLeaseMaintenance(val issueCount: Int) : LifecycleNudge() {
        override val title =
            if (issueCount == 1) "Log 1 maintenance issue" else "Review $issueCount open issues"
        override val reason = "Timestamp repairs and issues while you still live there."
    }

    data class MoveOutProofReminder(val daysUntilEnd: Int?) : LifecycleNudge() {
        override val title = "Start move-out proof"
        override val reason: String
            get() = daysUntilEnd?.let { days ->
                if (days > 0) "Lease ends in $days days — re-capture rooms before you return keys."
                else "Re-capture each room before move-out so you have before-and-after proof."
            } ?: "Re-capture each room before move-out so you have before-and-after proof."
    }

    companion object {
        private val dbDate = DateTimeFormatter.ISO_LOCAL_DATE

        fun forProperty(
            row: PropertyRow,
            record: PropertyRecord,
            openIssueCount: Int = 0,
        ): LifecycleNudge? {
            val today = LocalDate.now()
            val moveIn = row.moveInDate?.let { runCatching { LocalDate.parse(it, dbDate) }.getOrNull() }
                ?: today
            val daysSinceMoveIn = ChronoUnit.DAYS.between(moveIn, today).coerceAtLeast(0)

            val total = record.rooms.size
            val documented = RoomProofMetrics.documentedCount(record)

            if (total > 0 && documented < total && daysSinceMoveIn <= 5) {
                return FinishRoomsBeforeUnpacking(total - documented)
            }

            if (daysSinceMoveIn in 7..21 && documented > 0) {
                return AddLeaseAndDepositDocs
            }

            if (documented == total && total > 0) {
                return MakeMoveInReport
            }

            if (openIssueCount > 0 && daysSinceMoveIn >= 14) {
                return MidLeaseMaintenance(openIssueCount)
            }

            val leaseEnd = row.leaseEnd?.let { runCatching { LocalDate.parse(it, dbDate) }.getOrNull() }
            if (leaseEnd != null) {
                val daysUntil = ChronoUnit.DAYS.between(today, leaseEnd)
                if (daysUntil in 0..45) {
                    return MoveOutProofReminder(daysUntil.toInt())
                }
            } else if (daysSinceMoveIn >= 330 && documented > 0) {
                return MoveOutProofReminder(null)
            }

            return null
        }
    }
}
