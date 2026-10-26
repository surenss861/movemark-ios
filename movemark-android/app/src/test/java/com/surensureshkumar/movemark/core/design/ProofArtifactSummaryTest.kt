package com.surensureshkumar.movemark.core.design

import com.surensureshkumar.movemark.core.design.components.proofArtifactSummary
import com.surensureshkumar.movemark.features.proof.SavedProofReceiptPayload
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class ProofArtifactSummaryTest {
    @Test
    fun pluralisesPhotosAndIssues() {
        assertEquals("1 photo · 1 issue", proofArtifactSummary(1, 1))
        assertEquals("2 photos · 0 issues", proofArtifactSummary(2, 0))
        assertEquals("3 photos · 2 issues", proofArtifactSummary(3, 2))
    }

    @Test
    fun receiptPayloadCarriesIssueCount() {
        // Device QA: saving an entry tagged "Scratch" showed "0 issues" on the receipt (hard-coded).
        val payload = SavedProofReceiptPayload(
            roomId = UUID.randomUUID(), roomName = "Kitchen", propertyId = UUID.randomUUID(),
            savedCount = 2, attemptedCount = 2, hadPartialFailure = false,
            timestampMillis = 0L, thumbnailJpeg = null, issueCount = 1,
        )
        assertEquals("2 photos · 1 issue", proofArtifactSummary(payload.savedCount, payload.issueCount))
    }
}
