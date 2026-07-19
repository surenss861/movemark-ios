package com.surensureshkumar.movemark.data.cache

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface PropertySnapshotDao {
    @Query("SELECT * FROM property_snapshots WHERE propertyId = :propertyId LIMIT 1")
    suspend fun find(propertyId: String): PropertySnapshotEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: PropertySnapshotEntity)

    @Query("DELETE FROM property_snapshots")
    suspend fun clearAll()
}
