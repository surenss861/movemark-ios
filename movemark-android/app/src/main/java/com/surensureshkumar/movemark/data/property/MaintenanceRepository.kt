package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.MaintenanceIssueRow
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
private data class MaintenanceInsertRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    val title: String,
    val category: String,
    val description: String,
    val status: String = "open",
    /** `date` columns: the renter's local calendar day, as iOS (`MMCaseDate.dayString`). */
    @SerialName("date_discovered") val dateDiscovered: String? = null,
    @SerialName("date_reported") val dateReported: String? = null,
)

@Serializable
private data class MaintenanceCoverRow(
    val id: String,
    @SerialName("maintenance_issue_id") val maintenanceIssueId: String,
    @SerialName("file_path") val filePath: String,
    @SerialName("thumbnail_path") val thumbnailPath: String? = null,
)

@Serializable
private data class MaintenanceFollowUpWithTimestamp(
    @SerialName("landlord_response") val landlordResponse: String,
    @SerialName("follow_up_date") val followUpDate: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
private data class MaintenanceStatusWithTimestamp(
    val status: String,
    @SerialName("updated_at") val updatedAt: String,
)

/** Maintenance issue rows. Attachments go through [InspectionRepository.maintenanceSaver] (keys built by the API). */
@Singleton
class MaintenanceRepository @Inject constructor(
    private val postgrest: PostgrestClient,
) {
    companion object {
        private const val MAX_ISSUES = 200
        private const val MAX_COVER_ROWS = 400
    }

    /** Single-row lookup by id (iOS `fetchIssue`): the case file reads every column the timeline needs. */
    suspend fun fetchIssue(issueId: UUID): MaintenanceIssueRow? =
        postgrest.select<MaintenanceIssueRow>("maintenance_issues") {
            eq("id", issueId.toString())
            order("id")
            limit(1)
        }.firstOrNull()

    /**
     * Newest photo per maintenance case of a property, for the log's row thumbnails (iOS
     * `maintenanceCoverPhotos`). Best effort: callers treat a failure as "no thumbnails".
     */
    suspend fun fetchCoverPhotos(propertyId: UUID): Map<UUID, EvidencePhoto> {
        val rows = postgrest.select<MaintenanceCoverRow>("evidence_files") {
            select("id,maintenance_issue_id,file_path,thumbnail_path")
            eq("property_id", propertyId.toString())
            notNull("maintenance_issue_id")
            order("created_at", ascending = false)
            order("id", ascending = false)
            limit(MAX_COVER_ROWS)
        }
        val covers = LinkedHashMap<UUID, EvidencePhoto>()
        for (row in rows) {
            val issueId = runCatching { UUID.fromString(row.maintenanceIssueId) }.getOrNull() ?: continue
            if (covers.containsKey(issueId)) continue
            val photoId = runCatching { UUID.fromString(row.id) }.getOrNull() ?: continue
            covers[issueId] = EvidencePhoto(photoId, row.filePath, row.thumbnailPath)
        }
        return covers
    }

    suspend fun fetchIssues(propertyId: UUID): List<MaintenanceIssueRow> =
        postgrest.select("maintenance_issues") {
            eq("property_id", propertyId.toString())
            // Truncate to the most recent N rather than letting a long-term tenant's issue
            // log grow unbounded; ordering keeps this "most recent first", not an arbitrary cut.
            order("date_reported", ascending = false)
            order("created_at", ascending = false)
            order("id", ascending = false)
            limit(MAX_ISSUES)
        }

    suspend fun insertIssue(
        propertyId: UUID,
        userId: UUID,
        title: String,
        category: String,
        description: String,
    ): MaintenanceIssueRow {
        val row = MaintenanceInsertRow(
            id = UUID.randomUUID().toString(),
            propertyId = propertyId.toString(),
            userId = userId.toString(),
            title = title.trim(),
            category = category.trim(),
            description = description.trim(),
            dateDiscovered = java.time.LocalDate.now().toString(),
            dateReported = java.time.LocalDate.now().toString(),
        )
        return postgrest.insertReturning<MaintenanceInsertRow, MaintenanceIssueRow>("maintenance_issues", row).single()
    }

    /**
     * Appends a dated follow-up to `landlord_response` (one text column), read fresh so an earlier entry is never
     * overwritten (iOS `updateFollowUp`). Returns the stored response.
     */
    suspend fun updateFollowUp(issueId: UUID, note: String, fallbackExisting: String? = null): String {
        val now = java.time.Instant.now()
        val current = postgrest.select<MaintenanceIssueRow>("maintenance_issues") {
            eq("id", issueId.toString())
            order("id")
            limit(1)
        }.firstOrNull()
        val existing = if (current != null) current.landlordResponse else fallbackExisting
        val response = MaintenanceFollowUpLog.appending(note, now, existing)
        postgrest.update(
            "maintenance_issues",
            MaintenanceFollowUpWithTimestamp(landlordResponse = response, followUpDate = now.toString(), updatedAt = now.toString()),
        ) { eq("id", issueId.toString()) }
        return response
    }

    suspend fun markResolved(issueId: UUID) {
        val now = java.time.Instant.now().toString()
        postgrest.update("maintenance_issues", MaintenanceStatusWithTimestamp(status = "resolved", updatedAt = now)) {
            eq("id", issueId.toString())
        }
    }
}

/** iOS `MaintenanceFollowUpLog.Entry`: one follow-up paragraph, with its "Oct 27" day when it was dated. */
data class MaintenanceFollowUpEntry(val day: String?, val text: String)

/**
 * `landlord_response` as a log (iOS `MaintenanceFollowUpLog`): entries separated by a blank line, each new one
 * prefixed "Oct 27: ". Older free text reads as one undated entry.
 */
object MaintenanceFollowUpLog {
    private val dayFormatter = java.time.format.DateTimeFormatter.ofPattern("MMM d", java.util.Locale.US)

    fun appending(
        note: String,
        at: java.time.Instant,
        existing: String?,
        zone: java.time.ZoneId = java.time.ZoneId.systemDefault(),
    ): String {
        val entry = "${dayFormatter.format(at.atZone(zone))}: ${note.trim()}"
        val previous = existing?.trim().orEmpty()
        return if (previous.isEmpty()) entry else "$previous\n\n$entry"
    }

    private val dayPrefix = Regex("^([A-Z][a-z]{2} \\d{1,2}): ")

    /**
     * iOS `MaintenanceFollowUpLog.entries`: splits on blank lines; a paragraph without a day prefix belongs to the
     * entry before it (or, first of all, is one undated entry).
     */
    fun entries(response: String?): List<MaintenanceFollowUpEntry> {
        val raw = response?.trim().orEmpty()
        if (raw.isEmpty()) return emptyList()
        val result = mutableListOf<MaintenanceFollowUpEntry>()
        for (block in raw.split("\n\n")) {
            val trimmed = block.trim()
            if (trimmed.isEmpty()) continue
            val match = dayPrefix.find(trimmed)
            if (match != null) {
                result += MaintenanceFollowUpEntry(
                    match.groupValues[1],
                    trimmed.substring(match.range.last + 1),
                )
            } else if (result.isNotEmpty()) {
                val last = result.removeAt(result.lastIndex)
                result += last.copy(text = "${last.text}\n\n$trimmed")
            } else {
                result += MaintenanceFollowUpEntry(null, trimmed)
            }
        }
        return result
    }
}
