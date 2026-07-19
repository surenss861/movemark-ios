package com.surensureshkumar.movemark.data.cache

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [PropertySnapshotEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class MoveMarkDatabase : RoomDatabase() {
    abstract fun propertySnapshotDao(): PropertySnapshotDao
}
