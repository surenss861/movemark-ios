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

/** One read of the renter's name. */
sealed interface ProfileLookup {
    data class Found(val fullName: String) : ProfileLookup
    /** The server answered: no row, or a blank name. */
    data object Missing : ProfileLookup
    /** No answer (offline, timeout, server error). Says nothing about the name. */
    data class Failed(val cause: Throwable?) : ProfileLookup
}

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

    /**
     * The renter's name, keeping a failed read apart from "no name yet": only [ProfileLookup.Missing] means the
     * server answered without one. A network or server failure is [ProfileLookup.Failed], never a missing name.
     */
    suspend fun lookupFullName(userId: UUID): ProfileLookup = try {
        val rows = postgrest.select<ProfileRow>("profiles") {
            eq("id", userId.toString())
            order("id")
            limit(1)
        }
        rows.firstOrNull()?.fullName?.trim()?.takeIf { it.isNotEmpty() }
            ?.let { ProfileLookup.Found(it) }
            ?: ProfileLookup.Missing
    } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
    } catch (e: Exception) {
        ProfileLookup.Failed(e)
    }

    suspend fun updateFullName(userId: UUID, fullName: String) {
        val trimmed = fullName.trim()
        require(trimmed.isNotEmpty()) { "Enter your full name." }
        postgrest.update("profiles", ProfileNameUpdate(trimmed)) { eq("id", userId.toString()) }
    }
}
