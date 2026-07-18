package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.MaintenanceIssueRow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.time.Duration.Companion.seconds
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
private data class MaintenanceFollowUpUpdate(
    @SerialName("landlord_response") val landlordResponse: String,
    @SerialName("follow_up_date") val followUpDate: String,
)

@Serializable
private data class MaintenanceStatusUpdate(
    val status: String,
)

@Singleton
class MaintenanceRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    companion object {
        const val MAINTENANCE_BUCKET = "maintenance-media"
    }

    suspend fun fetchIssues(propertyId: UUID): List<MaintenanceIssueRow> =
        client.from("maintenance_issues")
            .select {
                filter { eq("property_id", propertyId.toString()) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList()

    suspend fun insertIssue(
        propertyId: UUID,
        userId: UUID,
        title: String,
        category: String,
        description: String,
    ): MaintenanceIssueRow {
        val id = UUID.randomUUID()
        val row = MaintenanceInsertRow(
            id = id.toString(),
            propertyId = propertyId.toString(),
            userId = userId.toString(),
            title = title.trim(),
            category = category.trim(),
            description = description.trim(),
        )
        return client.from("maintenance_issues")
            .insert(row) { select() }
            .decodeSingle()
    }

    suspend fun updateFollowUp(issueId: UUID, note: String) {
        val now = java.time.Instant.now().toString()
        client.from("maintenance_issues")
            .update(MaintenanceFollowUpUpdate(landlordResponse = note.trim(), followUpDate = now)) {
                filter { eq("id", issueId.toString()) }
            }
    }

    suspend fun markResolved(issueId: UUID) {
        client.from("maintenance_issues")
            .update(MaintenanceStatusUpdate(status = "resolved")) {
                filter { eq("id", issueId.toString()) }
            }
    }

    suspend fun uploadAttachment(data: ByteArray, path: String) {
        client.storage.from(MAINTENANCE_BUCKET).upload(path, data) {
            upsert = false
            contentType = ContentType.Image.JPEG
        }
    }

    suspend fun removeOrphanAttachment(path: String) {
        if (path.isEmpty()) return
        runCatching {
            client.storage.from(MAINTENANCE_BUCKET).delete(path)
        }
    }

    suspend fun signedUrl(path: String, expiresSeconds: Int = 3600): String =
        client.storage.from(MAINTENANCE_BUCKET).createSignedUrl(path, expiresSeconds.seconds)
}
