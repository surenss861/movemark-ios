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
