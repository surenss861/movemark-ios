/**
 * @file Option B (owner decision 2026-11-08): for accounts whose declared age range is 13 to 17, every photo and image
 *       document is stripped of location (GPS) and other identifying metadata (camera make/model/software, serial
 *       numbers, owner, lens, maker notes, user comment, IPTC and XMP) on the device, BEFORE it is written to the
 *       pending queue or uploaded. Only the capture date (+ offset) and orientation are kept, so evidence still says
 *       when. Adults keep today's behaviour: the source exactly as the device produced it. The server enforces the teen
 *       rule on its own (API finalize inspects the stored bytes; migration 1056 refuses unchecked rows).
 * @domain evidence
 * @status stable
 * @see [[MMPhotoPrivacy.swift]] — iOS counterpart
 */
package com.surensureshkumar.movemark.data.evidence

import android.graphics.Bitmap
import android.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

/** The account's photo rule, from the server's `age_category` ('teen' or 'adult'). */
enum class PhotoPrivacy {
    /** Today's behaviour: sources are kept byte-for-byte. */
    Standard,

    /** 13 to 17: location and identifying metadata removed before anything is stored. */
    Teen,
}

/**
 * Where the import pipeline reads the current rule. Set from the legal status (and restored per account from
 * [PhotoPrivacyStore] at sign-in, so an offline launch still knows it). Not an authority: the server enforces.
 */
object PhotoPrivacyPolicy {
    @Volatile
    var current: PhotoPrivacy = PhotoPrivacy.Standard

    /** The rule for a server `age_category`; null (nothing declared yet) means "keep what this account had". */
    fun fromServerCategory(category: String?): PhotoPrivacy? = when (category) {
        null -> null
        "teen" -> PhotoPrivacy.Teen
        else -> PhotoPrivacy.Standard
    }
}

/**
 * The teen copy of a photo. JPEG keeps its compressed image data (lossless: only header segments are rewritten);
 * PNG keeps every pixel chunk; HEIC/HEIF become a full-resolution JPEG (quality 95, orientation applied), because a
 * teen source must be a format the server can inspect. Deterministic and idempotent: a stripped file comes back
 * byte-for-byte unchanged.
 */
object TeenPhotoPrivacy {
    private const val HEIC_JPEG_QUALITY = 95
    private val EXIF_DATE = Regex("""\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}""")
    private val EXIF_OFFSET = Regex("""[+-]\d{2}:\d{2}""")

    /** What survives stripping: declared, not verified. */
    data class KeptTags(val dateTimeOriginal: String?, val offsetTimeOriginal: String?, val orientation: Int)

    fun strip(data: ByteArray): ByteArray {
        val format = EvidenceFormats.detect(data)
            ?: throw EvidenceImportException.UnsupportedFormat(EvidenceFormats.describe(data))
        return when (format.mimeType) {
            "image/jpeg" -> runCatching { stripJpeg(data, keptTags(data)) }.getOrNull() ?: reencode(data)
            "image/png" -> runCatching { stripPng(data) }.getOrNull() ?: throw EvidenceImportException.Unreadable()
            else -> reencode(data) // HEIC / HEIF
        }
    }

    /** The capture date, its offset and the orientation, read from [data]'s EXIF. Malformed values are dropped. */
    fun keptTags(data: ByteArray): KeptTags {
        val exif = runCatching { ExifInterface(ByteArrayInputStream(data)) }.getOrNull()
        val date = exif?.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)?.trim()?.takeIf { EXIF_DATE.matches(it) }
        val offset = exif?.getAttribute(TAG_OFFSET_TIME_ORIGINAL)?.trim()?.takeIf { EXIF_OFFSET.matches(it) }
        val orientation = exif?.getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)?.takeIf { it in 1..8 } ?: 1
        return KeptTags(date, offset, orientation)
    }

    /**
     * Rebuilds the JPEG's header segments: keeps JFIF (APP0), the colour profile (APP2 ICC_PROFILE), Adobe (APP14) and
     * every non-APP segment (tables, frame, scans); drops every other APPn (EXIF, XMP and extended XMP, IPTC/Photoshop,
     * MPF, JUMBF/C2PA, vendor blocks) and comments; writes a fresh EXIF with only [kept]; and drops anything after the
     * end-of-image marker (secondary images such as gain maps or depth maps carry their own metadata).
     */
    fun stripJpeg(data: ByteArray, kept: KeptTags): ByteArray {
        require(data.size >= 4 && u8(data, 0) == 0xFF && u8(data, 1) == 0xD8) { "not a JPEG" }
        val jfif = ByteArrayOutputStream()
        val rest = ByteArrayOutputStream()
        var i = 2
        while (true) {
            require(i + 1 < data.size && u8(data, i) == 0xFF) { "bad marker" }
            while (i + 1 < data.size && u8(data, i + 1) == 0xFF) i++ // fill bytes
            val marker = u8(data, i + 1)
            if (marker == 0xDA) break
            require(marker != 0xD9) { "no image data" }
            if (marker in 0xD0..0xD7 || marker == 0x01) { i += 2; continue }
            require(i + 4 <= data.size) { "truncated" }
            val end = i + 2 + u16(data, i + 2)
            require(end <= data.size) { "truncated" }
            when {
                marker == 0xE0 && startsWith(data, i + 4, "JFIF\u0000") -> jfif.write(data, i, end - i)
                keepsSegment(data, i, marker) -> rest.write(data, i, end - i)
            }
            i = end
        }
        val out = ByteArrayOutputStream(data.size)
        out.write(0xFF); out.write(0xD8)
        jfif.writeTo(out)
        out.write(exifSegment(kept))
        rest.writeTo(out)
        copyScans(data, i, out)
        return out.toByteArray()
    }

    /** From the first SOS through EOI: entropy-coded data verbatim; APPn and comments between scans dropped. */
    private fun copyScans(data: ByteArray, start: Int, out: ByteArrayOutputStream) {
        var i = start
        while (i + 1 < data.size) {
            if (u8(data, i) != 0xFF) { out.write(data, i, data.size - i); return } // not at a marker: keep the rest as is
            val marker = u8(data, i + 1)
            if (marker == 0xD9) { out.write(data, i, 2); return }
            if (marker == 0xFF) { i++; continue }
            if (marker in 0xD0..0xD7 || marker == 0x01) { out.write(data, i, 2); i += 2; continue }
            val end = minOf(data.size, i + 2 + u16(data, i + 2))
            if (keepsSegment(data, i, marker)) out.write(data, i, end - i)
            i = end
            if (marker != 0xDA) continue
            // Entropy-coded data runs to the next marker that isn't a stuffed 0x00 or a restart marker.
            val scan = i
            while (i + 1 < data.size) {
                if (u8(data, i) == 0xFF) {
                    val next = u8(data, i + 1)
                    if (next != 0x00 && next !in 0xD0..0xD7) break
                }
                i++
            }
            if (i + 1 >= data.size) i = data.size // truncated: keep what there is
            out.write(data, scan, i - scan)
        }
    }

    private fun keepsSegment(data: ByteArray, at: Int, marker: Int): Boolean = when {
        marker == 0xE2 -> startsWith(data, at + 4, "ICC_PROFILE\u0000")
        marker == 0xEE -> startsWith(data, at + 4, "Adobe")
        marker in 0xE0..0xEF -> false // APP0 JFIF is handled by the caller; everything else carries metadata
        marker == 0xFE -> false // comment
        else -> true
    }

    /** A minimal big-endian EXIF block: IFD0 Orientation, and an EXIF IFD with only the capture date and offset. */
    fun exifSegment(kept: KeptTags): ByteArray {
        val strings = buildList {
            kept.dateTimeOriginal?.let { add(0x9003 to it) }
            kept.offsetTimeOriginal?.let { add(0x9011 to it) }
        }
        val ifd0Count = if (strings.isEmpty()) 1 else 2
        val ifd0Size = 2 + 12 * ifd0Count + 4
        val exifCount = 1 + strings.size // ExifVersion + strings
        val exifIfdOffset = 8 + ifd0Size
        val exifSize = 2 + 12 * exifCount + 4
        var dataOffset = exifIfdOffset + exifSize

        val tiff = ByteArrayOutputStream()
        fun u16(v: Int) { tiff.write(v ushr 8 and 0xFF); tiff.write(v and 0xFF) }
        fun u32(v: Int) { u16(v ushr 16 and 0xFFFF); u16(v and 0xFFFF) }
        fun entry(tag: Int, type: Int, count: Int, value: Int) { u16(tag); u16(type); u32(count); u32(value) }

        tiff.write('M'.code); tiff.write('M'.code); u16(0x2A); u32(8)
        u16(ifd0Count)
        entry(0x0112, 3, 1, kept.orientation shl 16) // SHORT, left-justified in the value field
        if (strings.isNotEmpty()) entry(0x8769, 4, 1, exifIfdOffset)
        u32(0)
        if (strings.isNotEmpty()) {
            u16(exifCount)
            entry(0x9000, 7, 4, 0x30323332) // ExifVersion "0232"
            val payloads = strings.map { (tag, text) ->
                val bytes = (text + "\u0000").toByteArray(Charsets.US_ASCII)
                entry(tag, 2, bytes.size, dataOffset)
                dataOffset += bytes.size
                bytes
            }
            u32(0)
            payloads.forEach { tiff.write(it) }
        }
        val body = tiff.toByteArray()
        val header = "Exif\u0000\u0000".toByteArray(Charsets.US_ASCII)
        val length = 2 + header.size + body.size
        return byteArrayOf(0xFF.toByte(), 0xE1.toByte(), (length ushr 8).toByte(), length.toByte()) + header + body
    }

    /** Drops `eXIf` and every text chunk (`tEXt`, `zTXt`, `iTXt`, which carry XMP); keeps the rest, up to IEND. */
    fun stripPng(data: ByteArray): ByteArray {
        require(data.size >= 8 && EvidenceFormats.detect(data)?.mimeType == "image/png") { "not a PNG" }
        val out = ByteArrayOutputStream(data.size)
        out.write(data, 0, 8)
        var i = 8
        while (i + 8 <= data.size) {
            val length = (u16(data, i) shl 16) or u16(data, i + 2)
            val type = String(data, i + 4, 4, Charsets.ISO_8859_1)
            val end = i + 12 + length
            require(length >= 0 && end <= data.size) { "truncated PNG" }
            if (type !in DROPPED_PNG_CHUNKS) out.write(data, i, end - i)
            i = end
            if (type == "IEND") return out.toByteArray()
        }
        throw IllegalArgumentException("PNG without IEND")
    }

    /** HEIC/HEIF (or a JPEG this can't parse): the full image, upright, as JPEG with only the capture date. */
    private fun reencode(data: ByteArray): ByteArray {
        val kept = keptTags(data)
        val bitmap = EvidenceImport.renderUpright(data, Int.MAX_VALUE) ?: throw EvidenceImportException.Unreadable()
        val jpeg = try {
            ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, HEIC_JPEG_QUALITY, it) }.toByteArray()
        } finally {
            bitmap.recycle()
        }
        return stripJpeg(jpeg, kept.copy(orientation = 1))
    }

    private val DROPPED_PNG_CHUNKS = setOf("eXIf", "tEXt", "zTXt", "iTXt")
    private const val TAG_OFFSET_TIME_ORIGINAL = "OffsetTimeOriginal"

    private fun u8(data: ByteArray, at: Int) = data[at].toInt() and 0xFF
    private fun u16(data: ByteArray, at: Int) = (u8(data, at) shl 8) or u8(data, at + 1)
    private fun startsWith(data: ByteArray, at: Int, prefix: String): Boolean =
        at + prefix.length <= data.size && prefix.indices.all { data[at + it].toInt() and 0xFF == prefix[it].code }
}
