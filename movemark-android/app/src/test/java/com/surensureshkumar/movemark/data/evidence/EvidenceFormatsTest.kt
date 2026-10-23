package com.surensureshkumar.movemark.data.evidence

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EvidenceFormatsTest {
    private fun ftyp(brand: String) = byteArrayOf(0, 0, 0, 24) + "ftyp$brand".toByteArray(Charsets.ISO_8859_1) + ByteArray(8)

    @Test
    fun detectsAcceptedSourcesBySignature() {
        assertEquals("image/jpeg", EvidenceFormats.detect(byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0))?.mimeType)
        val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0)
        assertEquals("image/png", EvidenceFormats.detect(png)?.mimeType)
        assertEquals("image/heic", EvidenceFormats.detect(ftyp("heic"))?.mimeType)
        assertEquals("image/heif", EvidenceFormats.detect(ftyp("mif1"))?.mimeType)
    }

    @Test
    fun refusesOtherFormats() {
        val webp = "RIFF\u0000\u0000\u0000\u0000WEBPVP8 ".toByteArray(Charsets.ISO_8859_1)
        assertNull(EvidenceFormats.detect(webp))
        assertEquals("WEBP", EvidenceFormats.describe(webp))
        assertNull(EvidenceFormats.detect("GIF89a".toByteArray()))
        assertNull(EvidenceFormats.detect(ftyp("avif")))
    }

    @Test
    fun sha256IsLowercaseHex() {
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            EvidenceFormats.sha256Hex(ByteArray(0)),
        )
    }
}
