package com.surensureshkumar.movemark.data.evidence

import android.graphics.BitmapFactory
import android.media.ExifInterface
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode
import java.io.ByteArrayInputStream
import java.io.File

/**
 * Option B parity with iOS `TeenPhotoPrivacyTests`. The fixtures (test/resources/teen-privacy, made with exiftool 13.55)
 * carry GPS (position, altitude, speed, direction), make, model, software, artist, host, body and lens serials, owner,
 * lens make and model, user comment, a JPEG comment, IPTC (sub-location, by-line) and XMP (exif:GPS, photoshop:City/
 * Country/Credit, Iptc4xmpCore:Location, aux:SerialNumber, dc:creator). Teen outputs must carry none of it (checked
 * with ExifInterface and a byte search); adult sources must be byte-identical.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TeenPhotoPrivacyTest {
    private fun fixture(name: String): ByteArray =
        checkNotNull(javaClass.classLoader!!.getResourceAsStream("teen-privacy/$name")) { name }.use { it.readBytes() }

    /** Identifying strings planted in the fixtures, and the containers that carry XMP, IPTC and comments. */
    private val planted = listOf(
        "Google", "Pixel 9", "HDR+", "Jane Teen", "hostbox", "BODY12345", "LENS999", "at home", "Montreal", "Canada",
        "Plateau", "123 Rue Example", "kitchen", "http://ns.adobe.com/xap", "x:xmpmeta", "Photoshop 3.0", "8BIM",
        "GPS",
    )

    private fun assertNoPlantedBytes(data: ByteArray) {
        val text = String(data, Charsets.ISO_8859_1)
        for (needle in planted) assertFalse("found \"$needle\"", text.contains(needle))
    }

    private fun exif(data: ByteArray) = ExifInterface(ByteArrayInputStream(data))

    private fun assertNoIdentifyingTags(data: ByteArray) {
        val e = exif(data)
        assertFalse(e.getLatLong(FloatArray(2)))
        for (tag in listOf(
            ExifInterface.TAG_GPS_LATITUDE, ExifInterface.TAG_GPS_LONGITUDE, ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_SPEED, ExifInterface.TAG_GPS_IMG_DIRECTION, ExifInterface.TAG_GPS_VERSION_ID,
            ExifInterface.TAG_MAKE, ExifInterface.TAG_MODEL, ExifInterface.TAG_SOFTWARE, ExifInterface.TAG_ARTIST,
            "HostComputer", "CameraOwnerName", "BodySerialNumber", "LensSerialNumber", "LensMake", "LensModel",
            ExifInterface.TAG_MAKER_NOTE, ExifInterface.TAG_USER_COMMENT,
        )) {
            assertNull("tag $tag", e.getAttribute(tag))
        }
    }

    /** From the first start-of-scan through end-of-image: the compressed pixels. */
    private fun scans(jpeg: ByteArray): ByteArray {
        var i = 2
        while (!(jpeg[i] == 0xFF.toByte() && jpeg[i + 1] == 0xDA.toByte())) {
            i += 2 + (((jpeg[i + 2].toInt() and 0xFF) shl 8) or (jpeg[i + 3].toInt() and 0xFF))
        }
        var end = jpeg.size - 2
        while (!(jpeg[end] == 0xFF.toByte() && jpeg[end + 1] == 0xD9.toByte())) end--
        return jpeg.copyOfRange(i, end + 2)
    }

    private fun pngChunks(png: ByteArray): List<Pair<String, ByteArray>> {
        val chunks = mutableListOf<Pair<String, ByteArray>>()
        var i = 8
        while (i + 8 <= png.size) {
            val length = java.nio.ByteBuffer.wrap(png, i, 4).int
            val type = String(png, i + 4, 4, Charsets.ISO_8859_1)
            chunks += type to png.copyOfRange(i + 8, i + 8 + length)
            i += 12 + length
        }
        return chunks
    }

    /** Set -Dmovemark.teenPrivacyOut=<dir> to keep the outputs (checked with the API's `identifying_metadata`). */
    private fun keep(name: String, data: ByteArray) {
        val dir = System.getProperty("movemark.teenPrivacyOut")?.takeIf { it.isNotBlank() } ?: return
        File(dir).apply { mkdirs() }.resolve(name).writeBytes(data)
    }

    @Test fun theFixturesReallyCarryEverything() {
        val jpeg = fixture("gps.jpg")
        assertTrue(exif(jpeg).getLatLong(FloatArray(2)))
        assertEquals("Google", exif(jpeg).getAttribute(ExifInterface.TAG_MAKE))
        val text = String(jpeg, Charsets.ISO_8859_1)
        assertTrue(text.contains("http://ns.adobe.com/xap") && text.contains("Photoshop 3.0") && text.contains("BODY12345"))
    }

    @Test fun teenJpegKeepsOnlyCaptureDateOffsetAndOrientation() {
        val input = fixture("gps.jpg")
        val out = TeenPhotoPrivacy.strip(input)
        keep("teen.jpg", out)

        assertNoIdentifyingTags(out)
        assertNoPlantedBytes(out)
        val e = exif(out)
        assertEquals("2026:11:01 14:22:33", e.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL))
        assertEquals("-05:00", e.getAttribute("OffsetTimeOriginal"))
        assertEquals(ExifInterface.ORIENTATION_ROTATE_90, e.getAttributeInt(ExifInterface.TAG_ORIENTATION, 0))
        // Lossless: the compressed image data is copied, not re-encoded.
        assertArrayEquals(scans(input), scans(out))
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(out, 0, out.size, bounds)
        assertEquals(64, bounds.outWidth)
        assertEquals(48, bounds.outHeight)
    }

    @Test fun strippingIsIdempotent() {
        val once = TeenPhotoPrivacy.strip(fixture("gps.jpg"))
        assertArrayEquals(once, TeenPhotoPrivacy.strip(once))
        val png = TeenPhotoPrivacy.strip(fixture("gps.png"))
        assertArrayEquals(png, TeenPhotoPrivacy.strip(png))
    }

    @Test fun teenPngDropsExifAndTextChunksAndKeepsEveryPixel() {
        val input = fixture("gps.png")
        assertTrue(pngChunks(input).any { it.first == "eXIf" })
        val out = TeenPhotoPrivacy.strip(input)
        keep("teen.png", out)

        val types = pngChunks(out).map { it.first }
        assertTrue(types.none { it in setOf("eXIf", "tEXt", "zTXt", "iTXt") })
        assertEquals("IEND", types.last())
        assertEquals(
            pngChunks(input).filter { it.first == "IDAT" }.map { it.second.toList() },
            pngChunks(out).filter { it.first == "IDAT" }.map { it.second.toList() },
        )
        assertNoPlantedBytes(out)
    }

    @Test fun teenSourcesAreTheStrippedFileAndAdultSourcesAreUntouched() {
        val input = fixture("gps.jpg")
        val adult = EvidenceImport.source(input, EvidenceCaptureSource.Library, PhotoPrivacy.Standard)
        assertArrayEquals(input, adult.data)
        assertEquals(EvidenceFormats.sha256Hex(input), adult.sha256Hex)

        val teen = EvidenceImport.source(input, EvidenceCaptureSource.Library, PhotoPrivacy.Teen)
        assertNoPlantedBytes(teen.data)
        assertEquals("image/jpeg", teen.mimeType)
        assertEquals(EvidenceFormats.sha256Hex(teen.data), teen.sha256Hex) // the hash the upload signs
        assertNotEquals(adult.sha256Hex, teen.sha256Hex)
        assertEquals("2026-11-01T19:22:33Z", teen.capturedAt) // the capture date survives
    }

    @Test fun aSourceQueuedBeforeTheRuleWasKnownIsStrippedAtUpload() {
        val queued = EvidenceImport.source(fixture("gps.jpg"), EvidenceCaptureSource.Camera, PhotoPrivacy.Standard)
        val safe = EvidenceImport.teenSafe(queued)
        assertNoPlantedBytes(safe.data)
        assertEquals(EvidenceCaptureSource.Camera, safe.captureSource)
        // Already stripped: the same object back, nothing re-hashed.
        assertTrue(EvidenceImport.teenSafe(safe) === safe)
    }

    @Test fun derivativeAndThumbnailComeFromTheStrippedSource() {
        val context = androidx.test.core.app.ApplicationProvider.getApplicationContext<android.content.Context>()
        // 400x300: the derivative pipeline needs a long side of at least 256 px.
        val teen = EvidenceImport.source(fixture("gps-400.jpg"), EvidenceCaptureSource.Library, PhotoPrivacy.Teen)
        assertNoPlantedBytes(teen.data)
        val prepared = checkNotNull(EvidenceImport.prepare(context, teen, PhotoPrivacy.Teen))
        keep("teen-derivative.jpg", prepared.derivative)
        assertNoPlantedBytes(prepared.derivative)
        assertNoIdentifyingTags(prepared.derivative)
        prepared.thumbnail?.let { assertNoPlantedBytes(it) }
    }

    @Test fun teenHeicBecomesAFullResolutionJpeg() {
        val input = fixture("gps.heic")
        assertEquals("image/heic", EvidenceFormats.detect(input)?.mimeType)
        val decodable = BitmapFactory.decodeByteArray(input, 0, input.size) != null
        org.junit.Assume.assumeTrue("this JVM's graphics can't decode HEIC (checked on the emulator instead)", decodable)
        val out = TeenPhotoPrivacy.strip(input)
        keep("teen-from-heic.jpg", out)
        assertEquals("image/jpeg", EvidenceFormats.detect(out)?.mimeType)
        assertNoIdentifyingTags(out)
        assertNoPlantedBytes(out)
    }

    @Test fun theMinimalExifIsWhatExifInterfaceReadsBack() {
        val segment = TeenPhotoPrivacy.exifSegment(TeenPhotoPrivacy.KeptTags("2026:01:02 03:04:05", null, 3))
        val jpeg = TeenPhotoPrivacy.stripJpeg(fixture("gps.jpg"), TeenPhotoPrivacy.KeptTags("2026:01:02 03:04:05", null, 3))
        assertTrue(String(jpeg, Charsets.ISO_8859_1).contains(String(segment, Charsets.ISO_8859_1)))
        val e = exif(jpeg)
        assertEquals("2026:01:02 03:04:05", e.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL))
        assertNull(e.getAttribute("OffsetTimeOriginal"))
        assertEquals(ExifInterface.ORIENTATION_ROTATE_180, e.getAttributeInt(ExifInterface.TAG_ORIENTATION, 0))
        // No date at all: orientation only.
        val bare = TeenPhotoPrivacy.stripJpeg(fixture("gps.jpg"), TeenPhotoPrivacy.KeptTags(null, null, 1))
        assertNull(exif(bare).getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL))
    }
}
