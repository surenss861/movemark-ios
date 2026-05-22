package com.surensureshkumar.movemark.features.proof

import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class SavedProofReceiptPayload(
    val roomId: UUID,
    val roomName: String,
    val propertyId: UUID,
    val savedCount: Int,
    val attemptedCount: Int,
    val hadPartialFailure: Boolean,
    val timestampMillis: Long,
    val thumbnailJpeg: ByteArray?,
)

@Singleton
class SavedProofReceiptCache @Inject constructor() {
    @Volatile
    var lastReceipt: SavedProofReceiptPayload? = null

    fun put(payload: SavedProofReceiptPayload) {
        lastReceipt = payload
    }

    fun consume(roomId: UUID): SavedProofReceiptPayload? {
        val payload = lastReceipt?.takeIf { it.roomId == roomId } ?: return null
        lastReceipt = null
        return payload
    }
}
