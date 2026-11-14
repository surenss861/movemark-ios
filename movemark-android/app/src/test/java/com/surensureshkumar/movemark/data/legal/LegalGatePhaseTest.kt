package com.surensureshkumar.movemark.data.legal

import com.surensureshkumar.movemark.data.backend.PostgrestException
import com.surensureshkumar.movemark.features.legal.LegalGatePhase
import com.surensureshkumar.movemark.features.legal.LegalGateState
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

/** "Needs acceptance" only from an authenticated, successful status; every other outcome is its own phase. */
class LegalGatePhaseTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val docs = """"documents":{"terms":{"version":"2.0"},"privacy_notice":{"version":"2.0"}}"""
    private fun status(required: Boolean) =
        json.decodeFromString(LegalStatus.serializer(), """{"acceptance_required":$required,"age_requirement":"bands_v2",$docs}""")

    @Test fun beforeAnyAnswerItIsLoading() = assertEquals(LegalGatePhase.Loading, LegalGateState().phase)

    @Test fun aSuccessfulRequiredAnswerNeedsAcceptance() =
        assertEquals(LegalGatePhase.NeedsAcceptance, LegalGateState.from(LegalStatusResult.Success(status(true))).phase)

    @Test fun aSuccessfulNotRequiredAnswerIsAccepted() =
        assertEquals(LegalGatePhase.Accepted, LegalGateState.from(LegalStatusResult.Success(status(false))).phase)

    @Test fun offlineOpensOnTheCacheNeverTheGate() =
        assertEquals(LegalGatePhase.OpenOnCache, LegalGateState.from(LegalStatusResult.Failure(LegalStatusFailure.Offline)).phase)

    @Test fun anUnauthenticatedIdentityIsUnavailableNeverRequired() {
        val failure = LegalStatusFailure.classify(PostgrestException(403, "42501", "LEGAL_NOT_AUTHENTICATED"))
        assertEquals(LegalStatusFailure.Unavailable, failure)
        assertEquals(LegalGatePhase.Unavailable, LegalGateState.from(LegalStatusResult.Failure(failure)).phase)
    }

    @Test fun anUnverifiedRequiredIsNeverTheGate() =
        assertEquals(LegalGatePhase.Unavailable, LegalGateState(required = true, verified = false).phase)
}
