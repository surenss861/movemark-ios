/**
 * @file The rental gate's state after a load: only the server's empty listing means "no rental yet". A failed listing
 *       falls back to this device's copy of the last successful one (and the snapshot cache), otherwise it is
 *       [RentalStatus.Unavailable], never [RentalStatus.NoRental].
 * @domain property
 * @status wip
 * @see [[PropertyStore.kt]]
 * @tested-by [[RentalGateTest.kt]]
 */
package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.core.startup.RentalStatus
import com.surensureshkumar.movemark.data.models.PropertyRow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

object RentalGate {
    /**
     * [listedEmpty]: the server's listing answered with no rentals. [hasProperty]: a rental is loaded (from the server
     * or the cache). Anything else (a failed listing with nothing cached, or rentals listed but none loadable) is
     * [RentalStatus.Unavailable].
     */
    fun status(listedEmpty: Boolean, hasProperty: Boolean): RentalStatus = when {
        hasProperty -> RentalStatus.HasRental
        listedEmpty -> RentalStatus.NoRental
        else -> RentalStatus.Unavailable
    }

    @Serializable
    private data class CachedListing(val userId: String, val rows: List<PropertyRow>)

    private val json = Json { ignoreUnknownKeys = true }

    fun encodeListing(userId: String, rows: List<PropertyRow>): String =
        json.encodeToString(CachedListing.serializer(), CachedListing(userId.lowercase(), rows))

    /** The cached listing for [userId] only; another account's copy, or an unreadable one, is null. */
    fun decodeListing(userId: String, raw: String?): List<PropertyRow>? {
        if (raw.isNullOrBlank()) return null
        val cached = runCatching { json.decodeFromString(CachedListing.serializer(), raw) }.getOrNull() ?: return null
        return cached.rows.takeIf { cached.userId.equals(userId, ignoreCase = true) }
    }
}
