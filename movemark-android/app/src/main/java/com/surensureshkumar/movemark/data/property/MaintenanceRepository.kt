package com.surensureshkumar.movemark.data.property

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
}
