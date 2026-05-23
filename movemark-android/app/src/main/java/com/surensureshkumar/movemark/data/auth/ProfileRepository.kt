package com.surensureshkumar.movemark.data.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
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
    private val client: SupabaseClient,
) {
    suspend fun ensureProfileExists(userId: UUID, email: String) {
        val existing = runCatching {
            client.from("profiles")
                .select {
                    filter { eq("id", userId.toString()) }
                    limit(1)
                }
                .decodeList<ProfileRow>()
        }.getOrNull()

        if (!existing.isNullOrEmpty()) return

        client.from("profiles")
            .insert(ProfileInsert(id = userId.toString(), email = email))
    }

    suspend fun fetchFullName(userId: UUID): String? = runCatching {
        client.from("profiles")
            .select {
                filter { eq("id", userId.toString()) }
                limit(1)
            }
            .decodeList<ProfileRow>()
            .firstOrNull()
            ?.fullName
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }.getOrNull()

    suspend fun updateFullName(userId: UUID, fullName: String) {
        val trimmed = fullName.trim()
        require(trimmed.isNotEmpty()) { "Enter your full name." }
        client.from("profiles")
            .update(ProfileNameUpdate(trimmed)) {
                filter { eq("id", userId.toString()) }
            }
    }
}
