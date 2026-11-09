package com.surensureshkumar.movemark.data.evidence

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

/*
 * MoveMark — the one place evidence images are prepared for upload (iOS `MMEvidenceImport`). Every evidence
 * entry point (camera, room library picks, add photos, maintenance) uses it.
 *
 * Three representations, kept strictly apart:
 * - SOURCE: the file exactly as the device produced it (picker file bytes, or the camera's capture file).
 *   Never decoded and re-encoded, resized, cropped, enhanced or converted. Keeps all of its metadata;
 *   stored privately and never served by normal APIs.
 * - WORKING DERIVATIVE: a JPEG made from the source for the UI, downloads and PDFs. Orientation applied,
 *   long side ≤ 4096 px and never upscaled, quality 90, capture date kept, location and all other
 *   metadata removed (Bitmap re-encoding writes none; only the capture date is written back).
 * - THUMBNAIL: ≤ 320 px JPEG for grids, no metadata.
 */
object EvidenceImport {
    /** Server limit for the working derivative (`PHOTO` in the API). */
    const val MAX_DERIVATIVE_BYTES = 15 * 1024 * 1024
    private const val DERIVATIVE_MAX_PIXELS = 4096
    private const val DERIVATIVE_QUALITY = 90
    private const val THUMBNAIL_MAX_PIXELS = 320
    private const val THUMBNAIL_QUALITY = 70

    /** Reads [uri]'s bytes and wraps them as source evidence (stripped first for a teen account). */
    fun source(
        context: Context,
        uri: Uri,
        captureSource: EvidenceCaptureSource,
        privacy: PhotoPrivacy = PhotoPrivacyPolicy.current,
    ): EvidenceSource {
        val data = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw EvidenceImportException.Unreadable()
        return source(data, captureSource, privacy)
    }

    /**
     * Wraps the platform's file bytes as source evidence. Adults: reads metadata only; the bytes are untouched.
     * Teen accounts ([PhotoPrivacy.Teen]): the bytes are first stripped by [TeenPhotoPrivacy], so the pending queue,
     * the SHA-256, the upload, the derivative and the thumbnail all come from the stripped file.
     */
    fun source(
        data: ByteArray,
        captureSource: EvidenceCaptureSource,
        privacy: PhotoPrivacy = PhotoPrivacyPolicy.current,
    ): EvidenceSource {
        if (data.isEmpty()) throw EvidenceImportException.Unreadable()
        EvidenceFormats.detect(data) ?: throw EvidenceImportException.UnsupportedFormat(EvidenceFormats.describe(data))
        if (data.size > EvidenceFormats.MAX_SOURCE_BYTES) throw EvidenceImportException.TooLarge()
        return wrap(if (privacy == PhotoPrivacy.Teen) TeenPhotoPrivacy.strip(data) else data, captureSource)
    }

    private fun wrap(data: ByteArray, captureSource: EvidenceCaptureSource): EvidenceSource {
        val format = EvidenceFormats.detect(data) ?: throw EvidenceImportException.Unreadable()
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw EvidenceImportException.Unreadable()
        val exif = runCatching { ExifInterface(ByteArrayInputStream(data)) }.getOrNull()
        return EvidenceSource(
            data = data,
            mimeType = format.mimeType,
            fileExtension = format.fileExtension,
            pixelWidth = bounds.outWidth,
            pixelHeight = bounds.outHeight,
            sha256Hex = EvidenceFormats.sha256Hex(data),
            capturedAt = exif?.let {
                captureDate(it.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL), it.getAttribute(TAG_OFFSET_TIME_ORIGINAL))
            },
            captureSource = captureSource,
        )
    }

    /**
     * EXIF `DateTimeOriginal` (+ `OffsetTimeOriginal`) as an ISO-8601 instant. Without an offset the photo's
     * local time is read in the device's time zone — the same assumption iOS makes.
     */
    fun captureDate(original: String?, offset: String?): String? {
        val raw = original?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val local = runCatching { LocalDateTime.parse(raw, EXIF_DATE) }.getOrNull() ?: return null
        val withOffset = offset?.trim()?.takeIf { it.isNotEmpty() }?.let { off ->
            runCatching { OffsetDateTime.of(local, java.time.ZoneOffset.of(off)) }.getOrNull()
        }
        return (withOffset?.toInstant() ?: local.atZone(ZoneId.systemDefault()).toInstant()).toString()
    }

    /**
     * Everything an upload sends, or null when the source can't be rendered into a derivative. For a teen account a
     * source queued before the rule was known is stripped here (a no-op for one that already is).
     */
    fun prepare(context: Context, source: EvidenceSource, privacy: PhotoPrivacy = PhotoPrivacyPolicy.current): PreparedEvidence? {
        val safe = if (privacy == PhotoPrivacy.Teen) teenSafe(source) else source
        val derivative = derivative(context, safe) ?: return null
        return PreparedEvidence(safe, derivative, thumbnail(safe))
    }

    /** [source] as a teen source: unchanged when it is already stripped, else re-wrapped from the stripped bytes. */
    fun teenSafe(source: EvidenceSource): EvidenceSource {
        val stripped = TeenPhotoPrivacy.strip(source.data)
        return if (stripped.contentEquals(source.data)) source else wrap(stripped, source.captureSource)
    }

    /**
     * Working derivative: JPEG, orientation applied, long side ≤ 4096 and never above the source's, quality 90,
     * capture date kept, location and other metadata dropped. If it exceeds the server's derivative limit it is
     * reduced deterministically (quality first, then size) — the source is never touched to make it fit.
     */
    fun derivative(context: Context, source: EvidenceSource, maxBytes: Int = MAX_DERIVATIVE_BYTES): ByteArray? {
        val longSide = maxOf(source.pixelWidth, source.pixelHeight)
        var maxPixels = minOf(DERIVATIVE_MAX_PIXELS, longSide)
        val qualities = listOf(DERIVATIVE_QUALITY, 85, 80, 75, 70)
        while (maxPixels >= 256) {
            val bitmap = renderUpright(source.data, maxPixels) ?: return null
            try {
                for (quality in qualities) {
                    val jpeg = bitmap.toJpeg(quality)
                    if (jpeg.size <= maxBytes) return withCaptureDate(context, jpeg, source.data)
                }
            } finally {
                bitmap.recycle()
            }
            maxPixels = (maxPixels * 0.85).toInt()
        }
        return null
    }

    /** Thumbnail: JPEG, orientation applied, long side ≤ 320 (never above the source's), no metadata. */
    fun thumbnail(source: EvidenceSource): ByteArray? {
        val bitmap = renderUpright(source.data, minOf(THUMBNAIL_MAX_PIXELS, maxOf(source.pixelWidth, source.pixelHeight)))
            ?: return null
        return try {
            bitmap.toJpeg(THUMBNAIL_QUALITY)
        } finally {
            bitmap.recycle()
        }
    }

    /** Decodes [data] upright with its long side exactly [maxPixels] (or less, never upscaled). */
    internal fun renderUpright(data: ByteArray, maxPixels: Int): Bitmap? = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        val longSide = maxOf(bounds.outWidth, bounds.outHeight)
        if (longSide <= 0) return null
        var sample = 1
        while (longSide / (sample * 2) >= maxPixels) sample *= 2
        val decoded = BitmapFactory.decodeByteArray(data, 0, data.size, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: return null
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(data)).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val matrix = orientationMatrix(orientation)
        val scale = minOf(1f, maxPixels.toFloat() / maxOf(decoded.width, decoded.height))
        if (scale < 1f) matrix.postScale(scale, scale)
        if (matrix.isIdentity) return decoded
        val out = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (out !== decoded) decoded.recycle()
        out
    }.getOrNull()

    private fun orientationMatrix(orientation: Int): Matrix = Matrix().apply {
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { postRotate(90f); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { postRotate(-90f); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(-90f)
        }
    }

    private fun Bitmap.toJpeg(quality: Int): ByteArray =
        ByteArrayOutputStream().also { compress(Bitmap.CompressFormat.JPEG, quality, it) }.toByteArray()

    /** Writes only the source's capture date (and offset) into [jpeg]; nothing else is carried over. */
    private fun withCaptureDate(context: Context, jpeg: ByteArray, sourceData: ByteArray): ByteArray {
        val sourceExif = runCatching { ExifInterface(ByteArrayInputStream(sourceData)) }.getOrNull() ?: return jpeg
        val original = sourceExif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL) ?: return jpeg
        val offset = sourceExif.getAttribute(TAG_OFFSET_TIME_ORIGINAL)
        val file = File(context.cacheDir, "evidence-${UUID.randomUUID()}.jpg")
        return try {
            file.writeBytes(jpeg)
            ExifInterface(file.absolutePath).apply {
                setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, original)
                if (offset != null) setAttribute(TAG_OFFSET_TIME_ORIGINAL, offset)
                saveAttributes()
            }
            file.readBytes()
        } catch (_: Exception) {
            jpeg
        } finally {
            file.delete()
        }
    }

    /** `ExifInterface.TAG_OFFSET_TIME_ORIGINAL` is API 28+; the tag name is the same string everywhere. */
    private const val TAG_OFFSET_TIME_ORIGINAL = "OffsetTimeOriginal"
    private val EXIF_DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy:MM:dd HH:mm:ss")
}
