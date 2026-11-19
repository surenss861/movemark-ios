package com.surensureshkumar.movemark.data.evidence.pending

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.ExifInterface
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceImport
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/**
 * On a device: a real JPEG (with EXIF orientation and capture date) goes through the real import into the
 * pending store under filesDir, comes back byte-for-byte from a fresh store (a relaunch), and still renders
 * into an upright working derivative. The original is never re-encoded.
 */
@RunWith(AndroidJUnit4::class)
class PendingEvidenceDeviceTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var root: File

    @Before
    fun setUp() {
        root = File(context.filesDir, "PendingEvidenceTest/v1").apply { deleteRecursively() }
    }

    @After
    fun tearDown() {
        root.parentFile?.deleteRecursively()
    }

    /** A 600×400 JPEG tagged "rotate 90" with a capture date, like a phone camera writes. */
    private fun cameraJpeg(): ByteArray {
        val bitmap = Bitmap.createBitmap(600, 400, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.rgb(40, 120, 200)) }
        val jpeg = ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it) }.toByteArray()
        val file = File(context.cacheDir, "exif-${UUID.randomUUID()}.jpg").apply { writeBytes(jpeg) }
        ExifInterface(file.absolutePath).apply {
            setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_ROTATE_90.toString())
            setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, "2026:10:01 09:30:00")
            saveAttributes()
        }
        return file.readBytes().also { file.delete() }
    }

    @Test
    fun aCameraJpegSurvivesARelaunchUntouchedAndStillRenders() = runBlocking {
        val original = cameraJpeg()
        val source = EvidenceImport.source(original, EvidenceCaptureSource.Camera)
        val key = PendingEvidenceKey.of(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), moveOut = true)
        PendingEvidenceStore(root).add(listOf(PendingEvidenceInput(UUID.randomUUID(), source)), key, "Kitchen")

        val restored = PendingEvidenceStore(root).restore(key)
        assertNotNull(restored)
        val back = restored!!.items.single().source
        assertArrayEquals("stored original is byte-identical", original, back.data)
        assertEquals(source.sha256Hex, back.sha256Hex)
        assertEquals(600, back.pixelWidth)
        assertEquals(400, back.pixelHeight)
        assertNotNull(back.capturedAt)

        val prepared = EvidenceImport.prepare(context, back)
        assertNotNull(prepared)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(prepared!!.derivative, 0, prepared.derivative.size, bounds)
        assertEquals("derivative is upright (rotated)", 400, bounds.outWidth)
        assertEquals(600, bounds.outHeight)
        assertArrayEquals("preparing never touches the source", original, back.data)
        assertTrue(prepared.thumbnail!!.isNotEmpty())
    }

    @Test
    fun theDefaultRootIsInFilesDirNotCache() {
        val rootDir = PendingEvidenceStore.defaultRoot(context.filesDir)
        assertTrue(rootDir.absolutePath.startsWith(context.filesDir.absolutePath))
        assertTrue(!rootDir.absolutePath.startsWith(context.cacheDir.absolutePath))
    }
}
