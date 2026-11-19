package com.surensureshkumar.movemark.data.evidence.pending

import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceFormats
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

internal fun testSource(tag: Int, captureSource: EvidenceCaptureSource = EvidenceCaptureSource.Camera): EvidenceSource {
    val data = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte()) + "photo-$tag".toByteArray() + ByteArray(64) { tag.toByte() }
    return EvidenceSource(
        data = data,
        mimeType = "image/jpeg",
        fileExtension = "jpg",
        pixelWidth = 4032,
        pixelHeight = 3024,
        sha256Hex = EvidenceFormats.sha256Hex(data),
        capturedAt = "2026-10-01T10:00:00Z",
        captureSource = captureSource,
    )
}

internal val testKey = PendingEvidenceKey.of(
    userId = UUID.fromString("11111111-1111-1111-1111-111111111111"),
    propertyId = UUID.fromString("22222222-2222-2222-2222-222222222222"),
    roomId = UUID.fromString("33333333-3333-3333-3333-333333333333"),
    moveOut = false,
)

class PendingEvidenceStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    private fun store(root: File = File(tmp.root, "PendingEvidence/v1")) = PendingEvidenceStore(root, Dispatchers.Unconfined)

    private fun inputs(vararg tags: Int) = tags.map { PendingEvidenceInput(UUID.randomUUID(), testSource(it)) }

    @Test
    fun photosSurviveARelaunchByteForByte() = runTest {
        val first = store()
        val added = inputs(1, 2)
        first.add(added, testKey, "Kitchen", PendingEvidenceDraft(title = "Counter", notes = "chip", tags = listOf("Scratch")))

        // A new process: a fresh store over the same folder.
        val restored = store().restore(testKey)
        assertNotNull(restored)
        restored!!
        assertEquals(added.map { it.id.toString() }, restored.items.map { it.item.id })
        restored.items.zip(added).forEach { (r, input) ->
            assertArrayEquals("original bytes are untouched", input.source.data, r.source.data)
            assertEquals(input.source.sha256Hex, r.source.sha256Hex)
            assertEquals(EvidenceCaptureSource.Camera, r.source.captureSource)
            assertEquals(4032, r.source.pixelWidth)
        }
        assertEquals("Counter", restored.manifest.draft.title)
        assertEquals(listOf("Scratch"), restored.manifest.draft.tags)
        assertEquals("Kitchen", restored.manifest.roomName)
    }

    @Test
    fun addingTheSameIdTwiceKeepsOnePhoto() = runTest {
        val s = store()
        val input = inputs(1)
        s.add(input, testKey, "Kitchen")
        s.add(input, testKey, "Kitchen")
        assertEquals(1, s.manifest(testKey)!!.items.size)
    }

    @Test
    fun aCorruptedFileIsDroppedNotShownAsIntact() = runTest {
        val s = store()
        s.add(inputs(1, 2), testKey, "Kitchen")
        val victim = s.manifest(testKey)!!.items.first()
        s.fileFor(testKey, victim).writeBytes(byteArrayOf(1, 2, 3))

        val restored = s.restore(testKey)!!
        assertEquals(1, restored.items.size)
        assertFalse(restored.items.any { it.item.id == victim.id })
        assertEquals(1, s.manifest(testKey)!!.items.size)
    }

    @Test
    fun orphanAndTempFilesAreSweptOnRestore() = runTest {
        val s = store()
        s.add(inputs(1), testKey, "Kitchen")
        val folder = s.roomFolder(testKey)
        File(folder, "stray.jpg").writeBytes(byteArrayOf(9))
        File(folder, ".manifest.json.tmp").writeText("{half")
        s.restore(testKey)
        val names = folder.list()!!.toSet()
        assertFalse("stray.jpg" in names)
        // The manifest and the photo; a hidden temp file is simply overwritten by the next atomic write.
        assertEquals(2, names.count { !it.startsWith(".") })
        assertTrue("manifest.json" in names)
    }

    @Test
    fun confirmedPhotosLeaveThePhoneAndEmptyFoldersGo() = runTest {
        val s = store()
        s.add(inputs(1, 2), testKey, "Kitchen")
        val ids = s.manifest(testKey)!!.items.map { it.id }
        s.confirm(listOf(ids[0]), testKey)
        assertEquals(1, s.manifest(testKey)!!.items.size)
        assertEquals(1, s.manifest(testKey)!!.savedCount)
        s.confirm(listOf(ids[1]), testKey)
        assertNull(s.manifest(testKey))
        assertFalse(s.userFolder(testKey.userId).exists())
    }

    @Test
    fun removingAPhotoWithAnUnknownUploadQueuesItsRelease() = runTest {
        val s = store()
        s.add(inputs(1), testKey, "Kitchen")
        val id = s.manifest(testKey)!!.items.single().id
        val upload = PendingEvidenceUpload("t1", "inspection-media", "p.jpg")
        s.setUnresolved(upload, id, testKey)
        s.remove(listOf(id), testKey)
        val manifest = s.manifest(testKey)!!
        assertTrue(manifest.items.isEmpty())
        assertEquals(listOf(upload), manifest.cleanup)
        assertTrue(manifest.needsServerCleanup)
        s.dropCleanup(upload, testKey)
        assertNull(s.manifest(testKey))
    }

    @Test
    fun entryIdIsChosenOnceAndKept() = runTest {
        val s = store()
        s.add(inputs(1), testKey, "Kitchen")
        val a = s.beginEntry(testKey) { "aaaaaaaa-0000-0000-0000-000000000000" }
        val b = store().beginEntry(testKey) { "bbbbbbbb-0000-0000-0000-000000000000" }
        assertEquals(a, b)
    }

    @Test
    fun interruptedUploadsBecomeFailed() = runTest {
        val s = store()
        s.add(inputs(1, 2), testKey, "Kitchen")
        val ids = s.manifest(testKey)!!.items.map { it.id }
        s.markUploading(ids, testKey)
        assertEquals(2, s.manifest(testKey)!!.requestedCount)
        store().settleInterrupted(testKey)
        assertTrue(s.manifest(testKey)!!.items.all { it.status == PendingEvidenceItem.Status.Failed })
    }

    @Test
    fun rehomingMovesFilesWithoutReencoding() = runTest {
        val s = store()
        val appendKey = testKey.copy(appendTo = "44444444-4444-4444-4444-444444444444")
        val input = inputs(7)
        s.add(input, appendKey, "Kitchen")
        s.rehomeToNewEntry(appendKey)
        assertNull(s.manifest(appendKey))
        val restored = s.restore(testKey)!!
        assertArrayEquals(input.single().source.data, restored.items.single().source.data)
    }

    @Test
    fun summariesAndClearUser() = runTest {
        val s = store()
        s.add(inputs(1, 2), testKey, "Kitchen")
        s.add(inputs(3), testKey.copy(roomId = "55555555-5555-5555-5555-555555555555"), "Bath")
        assertEquals(3, s.pendingCount(testKey.userId))
        assertEquals(setOf("Kitchen", "Bath"), s.summaries(testKey.userId).map { it.roomName }.toSet())
        assertEquals(0, s.pendingCount("99999999-9999-9999-9999-999999999999"))
        s.clearUser(testKey.userId)
        assertEquals(0, s.pendingCount(testKey.userId))
    }

    @Test
    fun aManifestFromANewerVersionIsIgnored() = runTest {
        val s = store()
        s.add(inputs(1), testKey, "Kitchen")
        val file = File(s.roomFolder(testKey), "manifest.json")
        file.writeText(file.readText().replace("\"version\":1", "\"version\":99"))
        assertNull(s.manifest(testKey))
    }
}
