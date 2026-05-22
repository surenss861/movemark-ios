package com.surensureshkumar.movemark.features.proof.camera

import android.net.Uri
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CameraCaptureResultHolder @Inject constructor() {
    @Volatile
    private var pendingRoomId: UUID? = null

    @Volatile
    private var pendingUris: List<Uri> = emptyList()

    fun deliver(roomId: UUID, uris: List<Uri>) {
        pendingRoomId = roomId
        pendingUris = uris
    }

    fun consume(roomId: UUID): List<Uri>? {
        if (pendingRoomId != roomId) return null
        val uris = pendingUris
        pendingRoomId = null
        pendingUris = emptyList()
        return uris.takeIf { it.isNotEmpty() }
    }
}
