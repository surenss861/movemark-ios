package com.surensureshkumar.movemark.data.evidence.pending

import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceItem.Status
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingUploadPolicyTest {
    private fun item(status: Status = Status.Pending) = PendingEvidenceItem(
        id = java.util.UUID.randomUUID().toString(), fileName = "a.jpg", mimeType = "image/jpeg", fileExtension = "jpg",
        byteCount = 1, sha256Hex = "00", pixelWidth = 1, pixelHeight = 1, addedAt = 0, captureSource = "camera", status = status,
    )

    private fun manifest(vararg items: PendingEvidenceItem, entryId: String? = null, saveRequested: Boolean? = null) =
        PendingEvidenceManifest(key = testKey, roomName = "Kitchen", entryId = entryId, items = items.toList(), saveRequested = saveRequested)

    @Test
    fun photosOnlyTakenAreNeverSentAutomatically() {
        assertFalse(PendingUploadPolicy.awaitingUpload(manifest(item(), item())))
        assertFalse(PendingUploadPolicy.awaitingUpload(manifest(item(), saveRequested = false)))
    }

    @Test
    fun aSaveThatCouldNotFinishIsSentAutomatically() {
        assertTrue(PendingUploadPolicy.awaitingUpload(manifest(item(Status.Failed), entryId = "e", saveRequested = true)))
        // Even photos still marked pending, once their save was asked for (e.g. stopped before markUploading).
        assertTrue(PendingUploadPolicy.awaitingUpload(manifest(item(), entryId = "e", saveRequested = true)))
    }

    @Test
    fun photosMovedToANewEntryWaitForTheirOwnSave() {
        assertFalse(PendingUploadPolicy.awaitingUpload(manifest(item(Status.Failed), entryId = "e", saveRequested = false)))
    }

    @Test
    fun manifestsFromBeforeTheFlagAreInferredFromTheSave() {
        // Build 2026111302/03: a save that was interrupted (A14 repro) left an entry id and uploading/failed photos.
        assertTrue(PendingUploadPolicy.awaitingUpload(manifest(item(Status.Uploading), entryId = "e")))
        assertTrue(PendingUploadPolicy.awaitingUpload(manifest(item(Status.Failed), entryId = "e")))
        assertFalse(PendingUploadPolicy.awaitingUpload(manifest(item(Status.Failed))))
        assertFalse(PendingUploadPolicy.awaitingUpload(manifest(item(), entryId = "e")))
    }

    @Test
    fun nothingLeftIsNotAwaiting() {
        assertFalse(PendingUploadPolicy.awaitingUpload(manifest(entryId = "e", saveRequested = true)))
    }

    @Test
    fun retryUntilDoneThenStopAtTheCap() {
        assertEquals(PendingUploadPolicy.Outcome.Done, PendingUploadPolicy.outcome(remaining = 0, attempt = 0))
        assertEquals(PendingUploadPolicy.Outcome.Retry, PendingUploadPolicy.outcome(remaining = 2, attempt = 0))
        assertEquals(PendingUploadPolicy.Outcome.Retry, PendingUploadPolicy.outcome(2, PendingUploadPolicy.MAX_ATTEMPTS - 2))
        assertEquals(PendingUploadPolicy.Outcome.GiveUp, PendingUploadPolicy.outcome(2, PendingUploadPolicy.MAX_ATTEMPTS - 1))
        assertEquals(PendingUploadPolicy.Outcome.Done, PendingUploadPolicy.outcome(0, PendingUploadPolicy.MAX_ATTEMPTS + 3))
    }
}
