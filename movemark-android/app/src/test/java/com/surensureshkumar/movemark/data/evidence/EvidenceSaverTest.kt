package com.surensureshkumar.movemark.data.evidence

import com.surensureshkumar.movemark.data.backend.AbandonResult
import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.backend.MoveMarkUploadFailure
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.util.UUID

class EvidenceSaverTest {
    private fun source(tag: Int) = EvidenceSource(
        data = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), tag.toByte()),
        mimeType = "image/jpeg",
        fileExtension = "jpg",
        pixelWidth = 10,
        pixelHeight = 10,
        sha256Hex = "%064d".format(tag),
        capturedAt = null,
        captureSource = EvidenceCaptureSource.Library,
    )

    /** A fake backend: rows by id, uploads by ticket, scripted failures. */
    private class Backend {
        val rows = mutableMapOf<UUID, MoveMarkUpload>()
        val uploads = mutableListOf<MoveMarkUpload>()
        var failNextInserts = 0
        var insertCommitsBeforeFailing = false
        var abandonResults = ArrayDeque<AbandonResult>()
        var uploadFailure: Throwable? = null

        fun saver() = EvidenceSaver(
            upload = { _ ->
                uploadFailure?.let { uploadFailure = null; throw it }
                MoveMarkUpload("t-${uploads.size + 1}", "inspection-media", "p${uploads.size + 1}.jpg", null).also { uploads += it }
            },
            insert = { rowId, upload ->
                if (rows.containsKey(rowId)) throw IllegalStateException("duplicate key")
                if (failNextInserts > 0) {
                    failNextInserts--
                    if (insertCommitsBeforeFailing) rows[rowId] = upload // committed, but the response was lost
                    throw IOException("timeout")
                }
                rows[rowId] = upload
            },
            abandon = { upload ->
                abandonResults.removeFirstOrNull()
                    ?: if (rows.values.any { it.ticketId == upload.ticketId }) AbandonResult.Kept else AbandonResult.Deleted
            },
        )
    }

    @Test
    fun savesEachPhotoOnceWithItsRowId() = runTest {
        val backend = Backend()
        val items = listOf(PendingEvidence(source(1)), PendingEvidence(source(2)))
        val result = backend.saver().save(items)
        assertTrue(result.isComplete)
        assertEquals(items.map { it.rowId }, result.saved.map { it.id })
        assertEquals(2, backend.rows.size)
    }

    @Test
    fun lostInsertResponseIsSavedNotDuplicated() = runTest {
        val backend = Backend().apply { failNextInserts = 1; insertCommitsBeforeFailing = true }
        val result = backend.saver().save(listOf(PendingEvidence(source(1))))
        // The abandon finds the row: kept, so the photo counts as saved and is never re-sent.
        assertTrue(result.isComplete)
        assertEquals(1, backend.rows.size)
        assertEquals(1, result.insertFailures)
    }

    @Test
    fun unknownOutcomeIsSettledBeforeAnyReupload() = runTest {
        val backend = Backend().apply {
            failNextInserts = 1
            insertCommitsBeforeFailing = true
            abandonResults.addLast(AbandonResult.Failed) // the abandon after the failed insert doesn't get through
        }
        val first = backend.saver().save(listOf(PendingEvidence(source(1))))
        val pending = first.pending.single()
        assertEquals("t-1", pending.unresolved?.ticketId)

        // Retry: the earlier upload is abandoned again first; it is referenced, so it is saved without re-uploading.
        val second = backend.saver().save(first.pending)
        assertTrue(second.isComplete)
        assertEquals(pending.rowId, second.saved.single().id)
        assertEquals(1, backend.uploads.size)
        assertEquals(1, backend.rows.size)
    }

    @Test
    fun stillUnknownStaysPendingWithoutUploading() = runTest {
        val backend = Backend()
        val stuck = PendingEvidence(source(1), unresolved = MoveMarkUpload("t-0", "b", "x.jpg", null))
        backend.abandonResults.addLast(AbandonResult.Failed)
        val result = backend.saver().save(listOf(stuck))
        assertEquals(stuck, result.pending.single())
        assertTrue(backend.uploads.isEmpty())
    }

    @Test
    fun deletedEarlierUploadIsReuploadedUnderTheSameRowId() = runTest {
        val backend = Backend().apply { failNextInserts = 1 }
        val first = backend.saver().save(listOf(PendingEvidence(source(1))))
        val pending = first.pending.single()
        assertNull(pending.unresolved) // abandon answered deleted

        val second = backend.saver().save(first.pending)
        assertEquals(pending.rowId, second.saved.single().id)
        assertEquals(2, backend.uploads.size)
        assertEquals(1, backend.rows.size)
    }

    @Test
    fun failedUploadKeepsItsUnreleasedTicket() = runTest {
        val backend = Backend().apply {
            uploadFailure = MoveMarkUploadFailure(IOException("put"), MoveMarkUpload("t-9", "b", "x.jpg", null))
        }
        val result = backend.saver().save(listOf(PendingEvidence(source(1))))
        assertEquals("t-9", result.pending.single().unresolved?.ticketId)
        assertEquals(0, result.insertFailures)
    }
}
