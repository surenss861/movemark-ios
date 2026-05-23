package com.surensureshkumar.movemark.features.proof.camera

import android.content.Context
import java.io.File
import java.util.UUID

object CameraPhotoStorage {
    private const val CAPTURE_DIR = "movemark_captures"

    fun capturesDir(context: Context): File =
        File(context.cacheDir, CAPTURE_DIR).apply { mkdirs() }

    fun newCaptureFile(context: Context, roomId: UUID): File {
        val name = "movemark_${roomId}_${System.currentTimeMillis()}.jpg"
        return File(capturesDir(context), name)
    }
}
