package com.surensureshkumar.movemark.features.maintenance

import com.surensureshkumar.movemark.data.models.MaintenanceIssueRow
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.property.MaintenanceFollowUpLog
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

/*
 * The maintenance case vocabulary shared by the log, the new-issue sheet and the case file (iOS
 * `MaintenanceCategory`, `MaintenanceRecord.Status`, `MMCaseDate`, and the case timeline in
 * `MaintenanceIssueDetailView`). Pure logic, unit tested.
 */

/**
 * The fixed issue categories. [raw] is exactly what iOS stores in `maintenance_issues.category`
 * (iOS `MaintenanceCategory.rawValue`), so both clients read each other's cases.
 */
enum class MaintenanceCategory(val raw: String) {
    WaterDamage("Water damage"),
    HeatingCooling("Heating / cooling"),
    Pest("Pest"),
    Appliance("Appliance"),
    Structural("Structural"),
    Plumbing("Plumbing"),
    Electrical("Electrical"),
    Other("Other"),
    ;

    companion object {
        /** iOS `selectedCategory` starts at `.other`. */
        val Default = Other

        /**
         * Earlier Android builds stored their own spellings ("General", "HVAC", "Pests"); they read as the
         * matching category. Matching ignores case and surrounding spaces.
         */
        private val legacy = mapOf(
            "general" to Other,
            "hvac" to HeatingCooling,
            "heating" to HeatingCooling,
            "cooling" to HeatingCooling,
            "heating/cooling" to HeatingCooling,
            "pests" to Pest,
            "water" to WaterDamage,
        )

        /** The category a stored value means, or null for a value no client offers (shown as written). */
        fun fromStored(stored: String?): MaintenanceCategory? {
            val key = stored?.trim()?.lowercase(Locale.ROOT).orEmpty()
            if (key.isEmpty()) return null
            return entries.firstOrNull { it.raw.lowercase(Locale.ROOT) == key } ?: legacy[key]
        }

        /**
         * The label shown for a stored category: the category's label when it is one we know (legacy Android
         * spellings included), otherwise the stored text itself; a missing category reads as "Other".
         */
        fun label(stored: String?): String {
            val trimmed = stored?.trim().orEmpty()
            if (trimmed.isEmpty()) return Other.raw
            return fromStored(trimmed)?.raw ?: trimmed
        }
    }
}

/** iOS `MaintenanceRecord.Status`: the server writes `open` / `resolved`; `follow_up` is read as Follow-up. */
enum class MaintenanceCaseStatus(val label: String) {
    Open("Open"),
    FollowUp("Follow-up"),
    Resolved("Resolved"),
    ;

    val isResolved: Boolean get() = this == Resolved

    companion object {
        fun fromStored(raw: String?): MaintenanceCaseStatus =
            when (raw?.trim()?.lowercase(Locale.ROOT)?.replace('-', '_')?.replace(' ', '_')) {
                "resolved" -> Resolved
                "follow_up", "followup" -> FollowUp
                else -> Open
            }
    }
}

/** iOS `MMCaseDate`: case dates as stored (ISO timestamps, sometimes date-only), shown as "Oct 26 · 8:42 AM". */
object MaintenanceCaseDate {
    data class Value(val dateTime: ZonedDateTime, val hasTime: Boolean)

    fun parse(raw: String?, zone: ZoneId = ZoneId.systemDefault()): Value? {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return null
        runCatching { return Value(OffsetDateTime.parse(text).atZoneSameInstant(zone), true) }
        runCatching { return Value(Instant.parse(text).atZone(zone), true) }
        // Postgres may send a space between date and time.
        if (text.length > 10 && text[10] == ' ') {
            runCatching { return Value(OffsetDateTime.parse(text.replaceFirst(' ', 'T')).atZoneSameInstant(zone), true) }
        }
        return runCatching { Value(LocalDate.parse(text.take(10)).atStartOfDay(zone), false) }.getOrNull()
    }

    fun text(value: Value, time: Boolean = value.hasTime, locale: Locale = Locale.getDefault()): String {
        val day = DateTimeFormatter.ofPattern("MMM d", locale).format(value.dateTime)
        if (!time) return day
        return "$day · ${DateTimeFormatter.ofPattern("h:mm a", locale).format(value.dateTime)}"
    }

    fun text(raw: String?, time: Boolean? = null, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String? =
        parse(raw, zone)?.let { text(it, time ?: it.hasTime, locale) }
}

/** Everything the case file reads, from the full row or (until it loads) the log's record. */
data class MaintenanceCase(
    val id: UUID,
    val title: String,
    val category: String?,
    val details: String,
    val status: String,
    val landlordResponse: String?,
    val dateDiscovered: String? = null,
    val dateReported: String? = null,
    val followUpDate: String? = null,
    val updatedAt: String? = null,
    val reportMethod: String? = null,
    val createdAt: String? = null,
) {
    val caseStatus: MaintenanceCaseStatus get() = MaintenanceCaseStatus.fromStored(status)
    val categoryLabel: String get() = MaintenanceCategory.label(category)

    /** iOS header: `dateReported ?? dateDiscovered`; Android-made cases carry neither, so `created_at` follows. */
    fun reportedText(zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String? =
        MaintenanceCaseDate.text(dateReported ?: dateDiscovered ?: createdAt, zone = zone, locale = locale)

    companion object {
        fun from(row: MaintenanceIssueRow) = MaintenanceCase(
            id = UUID.fromString(row.id),
            title = row.title,
            category = row.category,
            details = row.description.orEmpty(),
            status = row.status,
            landlordResponse = row.landlordResponse,
            dateDiscovered = row.dateDiscovered,
            dateReported = row.dateReported,
            followUpDate = row.followUpDate,
            updatedAt = row.updatedAt,
            reportMethod = row.reportMethod,
            createdAt = row.createdAt,
        )

        fun from(record: MaintenanceRecord) = MaintenanceCase(
            id = record.id,
            title = record.title,
            category = record.category,
            details = record.details,
            status = record.status,
            landlordResponse = record.landlordResponse,
            createdAt = record.createdAt,
        )
    }
}

/** One step of the case chronology (iOS `CaseEvent`). */
data class MaintenanceCaseEvent(
    val id: String,
    val title: String,
    val dateText: String?,
    val detail: String? = null,
    val isPending: Boolean = false,
)

/**
 * iOS `MaintenanceIssueDetailView.events`: discovered (when earlier than the report), recorded (with the report
 * method), each landlord follow-up entry in the order written (the latest carries the stored follow-up time),
 * then "Repair completed" (resolved, dated by `updated_at`) or a quiet "Repair pending". Nothing else.
 */
object MaintenanceCaseTimeline {
    fun events(
        case: MaintenanceCase,
        zone: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): List<MaintenanceCaseEvent> {
        data class Dated(val event: MaintenanceCaseEvent, val at: ZonedDateTime)

        fun text(v: MaintenanceCaseDate.Value) = MaintenanceCaseDate.text(v, v.hasTime, locale)

        val dated = mutableListOf<Dated>()
        val reported = MaintenanceCaseDate.parse(case.dateReported, zone)
        val discovered = MaintenanceCaseDate.parse(case.dateDiscovered, zone)
        if (discovered != null && reported != null && discovered.dateTime.isBefore(reported.dateTime)) {
            dated += Dated(MaintenanceCaseEvent("discovered", "Issue discovered", text(discovered)), discovered.dateTime)
        }
        // Android-made cases have no report/discovery dates: the row's creation is when it was recorded.
        val recorded = reported ?: discovered ?: MaintenanceCaseDate.parse(case.createdAt, zone)
        if (recorded != null) {
            val method = case.reportMethod?.trim().orEmpty()
            dated += Dated(
                MaintenanceCaseEvent(
                    "recorded", "Case recorded", text(recorded),
                    detail = if (method.isEmpty()) null else "Reported to landlord by ${method.lowercase(locale)}",
                ),
                recorded.dateTime,
            )
        }
        val result = dated.sortedBy { it.at.toInstant() }.map { it.event }.toMutableList()

        val entries = MaintenanceFollowUpLog.entries(case.landlordResponse)
        val followUp = MaintenanceCaseDate.parse(case.followUpDate, zone)
        if (entries.isEmpty() && followUp != null) {
            result += MaintenanceCaseEvent("followup", "Landlord follow-up", text(followUp))
        }
        entries.forEachIndexed { index, entry ->
            val isLatest = index == entries.lastIndex
            val dateText = if (isLatest) followUp?.let(::text) ?: entry.day else entry.day
            result += MaintenanceCaseEvent(
                "followup-$index",
                if (dateText == null) "Landlord response" else "Landlord follow-up",
                dateText,
                detail = entry.text,
            )
        }

        if (case.caseStatus.isResolved) {
            val resolved = MaintenanceCaseDate.parse(case.updatedAt, zone)
            result += MaintenanceCaseEvent("resolved", "Repair completed", resolved?.let(::text))
        } else {
            result += MaintenanceCaseEvent("pending", "Repair pending", null, isPending = true)
        }
        return result
    }
}

/** "No photos" / "1 photo" / "3 photos" (iOS `MMCaseRow`). */
internal fun maintenancePhotoCountText(count: Int): String = when (count) {
    0 -> "No photos"
    1 -> "1 photo"
    else -> "$count photos"
}

/** "1 photo recorded" / "3 photos recorded" (iOS case file evidence line). */
internal fun maintenancePhotosRecordedText(count: Int): String =
    if (count == 1) "1 photo recorded" else "$count photos recorded"
