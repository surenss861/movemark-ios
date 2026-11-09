package com.surensureshkumar.movemark.data.legal

import com.surensureshkumar.movemark.data.backend.PostgrestException
import com.surensureshkumar.movemark.features.legal.LegalGateState
import com.surensureshkumar.movemark.features.legal.LegalGateViewModel
import com.surensureshkumar.movemark.features.legal.legalCanContinue
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The age-range step (migration 1055, `bands_v1`): iOS `LegalAgeRangeTests` / `LegalGateTests` parity. */
class LegalAgeRangeTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val docs = """"documents":{"terms":{"version":"2.0"},"privacy_notice":{"version":"2.0"}}"""

    private fun status(extra: String = "") =
        json.decodeFromString(LegalStatus.serializer(), """{"acceptance_required":true$extra,$docs}""")

    private fun sent(call: LegalAcceptanceCall) = (call as LegalAcceptanceCall.Send).params

    @Test fun aServerWithout1055SendsTheThreeArgumentCall() {
        val s = status()
        assertNull(s.ageRequirement)
        val params = sent(LegalAcceptanceCall.make(s, "google", band = null))
        assertEquals(setOf("p_method", "p_terms_version", "p_privacy_notice_version"), params.keys)
        assertEquals("google", params["p_method"]!!.jsonPrimitive.content)
    }

    @Test fun bandsV1SendsTheFiveArgumentCallWithTheServersCode() {
        val s = status(""","age_requirement":"bands_v1","age_category":null""")
        val teen = sent(LegalAcceptanceCall.make(s, "email", LegalAgeBand.Teen))
        assertEquals(
            setOf("p_method", "p_terms_version", "p_privacy_notice_version", "p_age_attestation", "p_age_band"),
            teen.keys,
        )
        assertEquals("bands_v1", teen["p_age_attestation"]!!.jsonPrimitive.content)
        assertEquals("13_17", teen["p_age_band"]!!.jsonPrimitive.content)
        assertEquals("18_plus", sent(LegalAcceptanceCall.make(s, "email", LegalAgeBand.Adult))["p_age_band"]!!.jsonPrimitive.content)
    }

    @Test fun bandsV1WithoutAnEligibleRangeSendsNothing() {
        val s = status(""","age_requirement":"bands_v1"""")
        assertEquals(LegalAcceptanceCall.NotReady, LegalAcceptanceCall.make(s, "email", band = null))
    }

    @Test fun anUnknownAgeCodeMeansUpdateTheApp() {
        for (code in listOf("age_18", "age_13_qc_14", "bands_v2")) {
            val s = status(""","age_requirement":"$code"""")
            assertTrue(s.requiresAppUpdate)
            assertEquals(LegalAcceptanceCall.UpdateRequired, LegalAcceptanceCall.make(s, "email", LegalAgeBand.Adult))
        }
    }

    @Test fun ageCategoryIsRead() {
        assertEquals("teen", status(""","age_requirement":"bands_v1","age_category":"teen"""").ageCategory)
    }

    @Test fun theFourAnswersMapToRangesOrNotAvailable() {
        assertEquals(listOf("Under 13", "13", "14 to 17", "18 or older"), LegalAgeChoice.entries.map { it.label })
        assertNull(LegalAgeChoice.Under13.band(null))
        assertTrue(LegalAgeChoice.Under13.isUnavailable(null))
        // 13 must answer the Quebec question first.
        assertNull(LegalAgeChoice.Thirteen.band(null))
        assertFalse(LegalAgeChoice.Thirteen.isUnavailable(null))
        assertNull(LegalAgeChoice.Thirteen.band(true))
        assertTrue(LegalAgeChoice.Thirteen.isUnavailable(true))
        assertEquals(LegalAgeBand.Teen, LegalAgeChoice.Thirteen.band(false))
        assertEquals(LegalAgeBand.Teen, LegalAgeChoice.FourteenToSeventeen.band(null))
        assertEquals(LegalAgeBand.Adult, LegalAgeChoice.Adult.band(null))
    }

    @Test fun continueNeedsTheTermsAndAnEligibleRange() {
        val ageRange = LegalGateState(required = true, ageRequirement = "bands_v1")
        assertFalse(legalCanContinue(agreed = false, ageRange, LegalAgeBand.Adult))
        assertFalse(legalCanContinue(agreed = true, ageRange, band = null)) // under 13, Quebec 13, or unanswered
        assertTrue(legalCanContinue(agreed = true, ageRange, LegalAgeBand.Teen))
        assertFalse(legalCanContinue(agreed = true, ageRange.copy(isSaving = true), LegalAgeBand.Teen))
        // A server without 1055: the terms box alone, as before.
        assertTrue(legalCanContinue(agreed = true, LegalGateState(required = true), band = null))
        // An unknown code: never.
        assertFalse(legalCanContinue(agreed = true, LegalGateState(required = true, ageRequirement = "age_18"), LegalAgeBand.Adult))
    }

    @Test fun noStatusFailsOpen() {
        // A server without the gate, or one that can't be reached: the app opens; the server enforces.
        assertEquals(false, LegalGateState.from(null).required)
    }

    @Test fun serverErrorsAreMatchedOnTheRaiseText() {
        val failure = PostgrestException(400, "22023", "LEGAL_AGE_BAND_INVALID")
        assertTrue(LegalGateViewModel.serverText(failure).contains("LEGAL_AGE_BAND"))
        assertFalse(failure.message!!.contains("LEGAL_AGE_BAND")) // the exception's own text doesn't carry it
    }
}
