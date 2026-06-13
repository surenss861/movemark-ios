package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord

object RoomProofMetrics {
    fun evidenceFor(room: RoomRecord, phase: ProofPhase) = when (phase) {
        ProofPhase.MoveIn -> room.moveInEvidence
        ProofPhase.MoveOut -> room.moveOutEvidence
    }

    fun photoCount(room: RoomRecord, phase: ProofPhase = ProofPhase.MoveIn): Int =
        evidenceFor(room, phase).sumOf { it.photoCount }

    fun moveInPhotoCount(room: RoomRecord): Int = photoCount(room, ProofPhase.MoveIn)

    fun moveOutPhotoCount(room: RoomRecord): Int = photoCount(room, ProofPhase.MoveOut)

    fun isDocumented(room: RoomRecord, phase: ProofPhase = ProofPhase.MoveIn): Boolean =
        photoCount(room, phase) > 0

    fun moveInDocumented(room: RoomRecord): Boolean = isDocumented(room, ProofPhase.MoveIn)

    fun moveOutDocumented(room: RoomRecord): Boolean = isDocumented(room, ProofPhase.MoveOut)

    fun documentedCount(property: PropertyRecord, phase: ProofPhase = ProofPhase.MoveIn): Int =
        property.rooms.count { isDocumented(it, phase) }

    fun moveInDocumentedCount(property: PropertyRecord): Int = documentedCount(property, ProofPhase.MoveIn)

    fun moveOutDocumentedCount(property: PropertyRecord): Int = documentedCount(property, ProofPhase.MoveOut)

    fun totalPhotoCount(property: PropertyRecord, phase: ProofPhase = ProofPhase.MoveIn): Int =
        property.rooms.sumOf { photoCount(it, phase) }

    fun nextRoom(property: PropertyRecord, phase: ProofPhase = ProofPhase.MoveIn): RoomRecord? =
        property.rooms.firstOrNull { !isDocumented(it, phase) }

    /** First move-in evidence file path for vault/cover preview; null if no saved photos. */
    fun firstPreviewPhotoPath(property: PropertyRecord, phase: ProofPhase = ProofPhase.MoveIn): String? {
        for (room in property.rooms) {
            if (!isDocumented(room, phase)) continue
            for (evidence in evidenceFor(room, phase)) {
                val path = evidence.photos.firstOrNull()?.filePath?.trim()
                if (!path.isNullOrEmpty()) return path
            }
        }
        return null
    }

    fun firstPreviewRoom(property: PropertyRecord, phase: ProofPhase = ProofPhase.MoveIn): RoomRecord? {
        for (room in property.rooms) {
            if (!isDocumented(room, phase)) continue
            for (evidence in evidenceFor(room, phase)) {
                if (evidence.photos.any { !it.filePath.isNullOrBlank() }) return room
            }
        }
        return null
    }

    fun moveOutStatusLine(property: PropertyRecord): String {
        val total = property.rooms.size
        if (total == 0) return "Move-out not started"
        val documented = moveOutDocumentedCount(property)
        return when {
            documented == 0 -> "Move-out not started"
            documented >= total -> "Move-out proof complete"
            else -> "$documented of $total rooms captured"
        }
    }
}
