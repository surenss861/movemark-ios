package com.surensureshkumar.movemark.data.evidence

import java.security.MessageDigest

enum class EvidenceCaptureSource(val raw: String) {
    Camera("camera"),
    Library("library"),
}

/**
 * Evidence exactly as the device produced it (iOS `MMEvidenceSource`): the captured or selected file's
 * bytes, never decoded and re-encoded, resized, cropped, enhanced or converted. Kept with all of its
 * metadata and stored privately as the immutable source; the API signs its SHA-256 into the upload.
 */
class EvidenceSource(
    val data: ByteArray,
    val mimeType: String,
    val fileExtension: String,
    /** Stored pixel dimensions of the file (before orientation is applied). */
    val pixelWidth: Int,
    val pixelHeight: Int,
    val sha256Hex: String,
    /** EXIF `DateTimeOriginal` (with its offset when present) as an ISO-8601 instant: declared by the file, not verified. */
    val capturedAt: String?,
    val captureSource: EvidenceCaptureSource,
)

/** What one evidence upload sends: the untouched source, its working JPEG derivative and an optional thumbnail. */
class PreparedEvidence(
    val source: EvidenceSource,
    val derivative: ByteArray,
    val thumbnail: ByteArray?,
)

sealed class EvidenceImportException(message: String) : Exception(message) {
    class Unreadable : EvidenceImportException("This photo couldn’t be read. Try another one.")
    class UnsupportedFormat(type: String) :
        EvidenceImportException("This photo format ($type) isn’t supported yet. Use a JPEG, HEIC or PNG photo.")
    class TooLarge : EvidenceImportException("This photo is larger than 25 MB, so it can’t be stored as original evidence.")
}

/** Format detection by file signature — the same check the API applies to stored sources. */
object EvidenceFormats {
    /** Server limit for immutable sources (`SOURCE` in the API). Sources are never shrunk to fit. */
    const val MAX_SOURCE_BYTES = 25 * 1024 * 1024

    data class Format(val mimeType: String, val fileExtension: String)

    private val heicBrands = setOf("heic", "heix", "hevc", "hevx", "heim", "heis", "hevm", "hevs")
    private val heifBrands = setOf("mif1", "msf1")

    /** The accepted source format of [data], or null when it is something else (WebP, GIF, DNG, …). */
    fun detect(data: ByteArray): Format? {
        if (data.size >= 3 && data[0] == 0xFF.toByte() && data[1] == 0xD8.toByte() && data[2] == 0xFF.toByte()) {
            return Format("image/jpeg", "jpg")
        }
        val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        if (data.size >= 8 && data.copyOfRange(0, 8).contentEquals(png)) return Format("image/png", "png")
        if (data.size >= 12 && String(data, 4, 4, Charsets.ISO_8859_1) == "ftyp") {
            val brand = String(data, 8, 4, Charsets.ISO_8859_1)
            if (brand in heicBrands) return Format("image/heic", "heic")
            if (brand in heifBrands) return Format("image/heif", "heif")
        }
        return null
    }

    /** A short label for an unsupported file, for the error message. */
    fun describe(data: ByteArray): String = when {
        data.size >= 12 && String(data, 0, 4, Charsets.ISO_8859_1) == "RIFF" &&
            String(data, 8, 4, Charsets.ISO_8859_1) == "WEBP" -> "WEBP"
        data.size >= 3 && String(data, 0, 3, Charsets.ISO_8859_1) == "GIF" -> "GIF"
        else -> "this file type"
    }

    fun sha256Hex(data: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(data).joinToString("") { "%02x".format(it) }
}
