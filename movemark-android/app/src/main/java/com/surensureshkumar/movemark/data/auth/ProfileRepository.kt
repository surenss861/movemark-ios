package com.surensureshkumar.movemark.data.auth

import com.surensureshkumar.movemark.data.backend.PostgrestClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
private data class ProfileRow(
    val id: String,
    val email: String? = null,
    @SerialName("full_name") val fullName: String? = null,
)

@Serializable
private data class ProfileInsert(
    val id: String,
    val email: String,
    @SerialName("full_name") val fullName: String = "",
)

@Serializable
private data class ProfileNameUpdate(
    @SerialName("full_name") val fullName: String,
)

@Singleton
class ProfileRepository @Inject constructor(
    private val postgrest: PostgrestClient,
) {
    /**
     * Ensures a `profiles` row exists for the user (required for `properties.user_id`). Idempotent in one round
     * trip: an existing row is left untouched, so this never blanks a saved name (iOS does the same).
     */
    suspend fun ensureProfileExists(userId: UUID, email: String) {
        postgrest.insertIgnoringDuplicates(
            "profiles",
            ProfileInsert(id = userId.toString(), email = email),
            onConflict = "id",
        )
    }

    suspend fun fetchFullName(userId: UUID): String? = runCatching {
        postgrest.select<ProfileRow>("profiles") {
            eq("id", userId.toString())
            order("id")
            limit(1)
        }
            .firstOrNull()
            ?.fullName
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }.getOrNull()

    suspend fun updateFullName(userId: UUID, fullName: String) {
        val trimmed = fullName.trim()
        require(trimmed.isNotEmpty()) { "Enter your full name." }
        postgrest.update("profiles", ProfileNameUpdate(trimmed)) { eq("id", userId.toString()) }
    }
}
