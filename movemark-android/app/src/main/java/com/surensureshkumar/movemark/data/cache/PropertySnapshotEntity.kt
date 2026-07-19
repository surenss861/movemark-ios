package com.surensureshkumar.movemark.data.cache

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Local cache of the last successfully-hydrated [com.surensureshkumar.movemark.data.models.PropertySnapshot]
 * for a property, stored as the raw RPC JSON string (decoded back into the existing row/record types
 * on read -- see `PropertySnapshotCache`). Deliberately not a full relational Room schema: this is an
 * "instant local read, then refresh" cache, not an offline-write/sync store.
 */
@Entity(tableName = "property_snapshots")
data class PropertySnapshotEntity(
    @PrimaryKey val propertyId: String,
    val snapshotJson: String,
    val cachedAtMillis: Long,
)
