package com.surensureshkumar.movemark.data.property

import android.util.Log
import com.surensureshkumar.movemark.data.cache.PropertySnapshotDao
import com.surensureshkumar.movemark.data.cache.PropertySnapshotEntity
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Local (Room-backed) cache of the raw `get_property_snapshot` RPC response, keyed by property id.
 * Lets [PropertyHydrator] serve an instant, no-network read on property switch/launch while the
 * fresh network fetch runs in the background. Read/write failures are swallowed (logged only) --
 * this is a best-effort local cache, not a source of truth, so it should never be the reason
 * hydration fails.
 */
@Singleton
class PropertySnapshotCache @Inject constructor(
    private val dao: PropertySnapshotDao,
) {
    suspend fun read(propertyId: UUID): String? = runCatching {
        dao.find(propertyId.toString())?.snapshotJson
    }.onFailure { Log.e(TAG, "Cache read failed for $propertyId", it) }.getOrNull()

    suspend fun write(propertyId: UUID, snapshotJson: String) {
        runCatching {
            dao.upsert(
                PropertySnapshotEntity(
                    propertyId = propertyId.toString(),
                    snapshotJson = snapshotJson,
                    cachedAtMillis = System.currentTimeMillis(),
                ),
            )
        }.onFailure { Log.e(TAG, "Cache write failed for $propertyId", it) }
    }

    /** Wipes every cached snapshot. Call on sign-out so a different user on the same device never gets a cache hit of someone else's property data. */
    suspend fun clearAll() {
        runCatching { dao.clearAll() }.onFailure { Log.e(TAG, "Cache clearAll failed", it) }
    }

    private companion object {
        const val TAG = "PropertySnapshotCache"
    }
}
