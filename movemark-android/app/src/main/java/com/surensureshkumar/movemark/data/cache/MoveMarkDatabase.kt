package com.surensureshkumar.movemark.data.cache

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [PropertySnapshotEntity::class],
    // 2: snapshot v2 payloads; the destructive fallback drops v1 snapshots rather than misreading them.
    version = 2,
    exportSchema = false,
)
abstract class MoveMarkDatabase : RoomDatabase() {
    abstract fun propertySnapshotDao(): PropertySnapshotDao
}
