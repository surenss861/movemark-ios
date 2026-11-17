/**
 * @file The name gate's state: what the server last confirmed, kept apart from "couldn't check". A failed lookup keeps
 *       the last confirmed answer (from this session or this device's cache) and is otherwise [ProfileStatus.Unavailable],
 *       never [ProfileStatus.NeedsName]. Galaxy A14, 2026-11-17: an offline launch sent a named renter to onboarding.
 * @domain onboarding-auth
 * @status wip
 * @see [[StartupRouter.kt]]
 * @tested-by [[ProfileGateTest.kt]]
 */
package com.surensureshkumar.movemark.data.auth

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.surensureshkumar.movemark.core.startup.ProfileStatus
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject
import javax.inject.Singleton

data class ProfileState(
    val status: ProfileStatus = ProfileStatus.Unknown,
    val fullName: String? = null,
    /** True once the server itself answered during this session (cached answers are re-checked). */
    val verified: Boolean = false,
)

object ProfileGate {
    /** A lookup that hasn't answered by then counts as failed; it keeps retrying on reconnect and on return. */
    const val LOOKUP_TIMEOUT_MS = 8_000L

    /** At sign-in, before any network: this account's last confirmed name, if this device has one. */
    fun restore(cachedName: String?): ProfileState =
        cachedName?.takeIf { it.isNotBlank() }?.let { ProfileState(ProfileStatus.HasName, it, verified = false) }
            ?: ProfileState()

    fun apply(current: ProfileState, lookup: ProfileLookup): ProfileState = when (lookup) {
        is ProfileLookup.Found -> ProfileState(ProfileStatus.HasName, lookup.fullName, verified = true)
        ProfileLookup.Missing -> ProfileState(ProfileStatus.NeedsName, null, verified = true)
        is ProfileLookup.Failed -> when (current.status) {
            // Keep the last confirmed answer; a failure says nothing new.
            ProfileStatus.HasName, ProfileStatus.NeedsName -> current
            ProfileStatus.Unknown, ProfileStatus.Unavailable -> ProfileState(ProfileStatus.Unavailable, null, verified = false)
        }
    }

    /** Runs [lookup], turning a slow answer into [ProfileLookup.Failed] instead of an endless wait. */
    suspend fun lookupWithin(timeoutMs: Long = LOOKUP_TIMEOUT_MS, lookup: suspend () -> ProfileLookup): ProfileLookup =
        withTimeoutOrNull(timeoutMs) { lookup() } ?: ProfileLookup.Failed(null)
}

private val Context.profileCacheStore by preferencesDataStore("movemark_profile_cache")

/** The last server-confirmed name per account, so an offline launch knows the name step is done. */
@Singleton
class VerifiedProfileCache @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private fun key(userId: String) = stringPreferencesKey("verified_name_${userId.lowercase()}")

    suspend fun read(userId: String): String? =
        runCatching { context.profileCacheStore.data.first()[key(userId)] }.getOrNull()

    suspend fun write(userId: String, fullName: String) {
        runCatching { context.profileCacheStore.edit { it[key(userId)] = fullName } }
    }

    suspend fun remove(userId: String) {
        runCatching { context.profileCacheStore.edit { it.remove(key(userId)) } }
    }

    suspend fun clearAll() {
        runCatching { context.profileCacheStore.edit { it.clear() } }
    }
}
