package com.surensureshkumar.movemark.data.legal

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LegalStatusTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val docs = """"documents":{"terms":{"version":"t1","content_hash":"a"},"privacy_notice":{"version":"p1","url":null}}"""

    private fun status(body: String) = json.decodeFromString(LegalStatus.serializer(), body)

    @Test fun outstandingAcceptanceShowsTheGate() {
        val s = status("""{"enforced":false,"acceptance_required":true,"blocked":false,$docs}""")
        assertTrue(s.needsAcceptance)
        assertEquals("p1", s.documents?.privacyNotice?.version)
    }

    @Test fun acceptedUsersSkipIt() {
        assertFalse(status("""{"enforced":true,"acceptance_required":false,"blocked":false,$docs}""").needsAcceptance)
    }

    @Test fun nothingPublishedMeansNoGate() {
        assertFalse(status("""{"enforced":false,"acceptance_required":true,"documents":null}""").needsAcceptance)
    }
}
