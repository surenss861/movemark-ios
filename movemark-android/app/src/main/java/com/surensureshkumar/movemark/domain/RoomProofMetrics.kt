package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord

object RoomProofMetrics {
    fun photoCount(room: RoomRecord): Int =
        room.evidence.sumOf { it.photoCount }

    fun isDocumented(room: RoomRecord): Boolean = photoCount(room) > 0

    fun documentedCount(property: PropertyRecord): Int =
        property.rooms.count { isDocumented(it) }

    fun totalPhotoCount(property: PropertyRecord): Int =
        property.rooms.sumOf { photoCount(it) }

    fun nextRoom(property: PropertyRecord): RoomRecord? =
        property.rooms.firstOrNull { !isDocumented(it) }
}
