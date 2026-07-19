package com.surensureshkumar.movemark.core.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.ByteArrayOutputStream

/** Reads [this] via the content resolver, downscales to at most [maxSide] px, and JPEG-compresses. */
fun Uri.toJpegBytes(context: Context, maxSide: Int = 1920, quality: Int = 82): ByteArray? =
    runCatching {
        context.contentResolver.openInputStream(this)?.use { stream ->
            val bitmap = BitmapFactory.decodeStream(stream) ?: return@runCatching null
            val scaled = bitmap.scaleMax(maxSide)
            ByteArrayOutputStream().apply {
                scaled.compress(Bitmap.CompressFormat.JPEG, quality, this)
                if (scaled !== bitmap) scaled.recycle()
                bitmap.recycle()
            }.toByteArray()
        }
    }.getOrNull()

/**
 * Re-downscales an already-produced (full-size) JPEG byte array to a small grid thumbnail
 * (~320px longest side by default). Used at upload time for evidence/maintenance photos so a
 * lightweight companion image can be stored alongside the full-size capture (`thumbnail_path`)
 * for grids/lists to load instead of the full-size file. Returns null on decode failure — callers
 * should treat a missing thumbnail as non-fatal and fall back to the full-size path.
 */
fun ByteArray.toThumbnailJpeg(maxSide: Int = 320, quality: Int = 80): ByteArray? =
    runCatching {
        val bitmap = BitmapFactory.decodeByteArray(this, 0, size) ?: return@runCatching null
        val scaled = bitmap.scaleMax(maxSide)
        ByteArrayOutputStream().apply {
            scaled.compress(Bitmap.CompressFormat.JPEG, quality, this)
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
        }.toByteArray()
    }.getOrNull()

/** Derives a thumbnail's storage path from its full-size sibling: same directory, `_thumb` suffix. */
fun thumbnailPathFor(filePath: String): String =
    if (filePath.endsWith(".jpg", ignoreCase = true)) {
        filePath.dropLast(4) + "_thumb.jpg"
    } else {
        "${filePath}_thumb.jpg"
    }

private fun Bitmap.scaleMax(maxSide: Int): Bitmap {
    val max = maxOf(width, height)
    if (max <= maxSide) return this
    val scale = maxSide.toFloat() / max
    return Bitmap.createScaledBitmap(
        this,
        (width * scale).toInt().coerceAtLeast(1),
        (height * scale).toInt().coerceAtLeast(1),
        true,
    )
}
