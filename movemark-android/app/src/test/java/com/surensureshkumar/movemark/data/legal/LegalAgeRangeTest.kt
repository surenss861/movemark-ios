package com.surensureshkumar.movemark.data.legal

import com.surensureshkumar.movemark.data.backend.PostgrestException
import com.surensureshkumar.movemark.features.legal.LegalGateState
import com.surensureshkumar.movemark.features.legal.LegalGateViewModel
import com.surensureshkumar.movemark.features.legal.LegalGateViewModel.AcceptFailure
import com.surensureshkumar.movemark.features.legal.legalCanContinue
import com.surensureshkumar.movemark.features.legal.legalStop
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Quebec + age-range step (migrations 1055 `bands_v1` and 1057 `bands_v2`): iOS `LegalGate` parity. */
class LegalAgeRangeTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val docs = """"documents":{"terms":{"version":"2.0"},"privacy_notice":{"version":"2.0"}}"""

    private fun status(extra: String = "") =
        json.decodeFromString(LegalStatus.serializer(), """{"acceptance_required":true$extra,$docs}""")

    private fun code(c: String) = status(""","age_requirement":"$c"""")
    private fun sent(call: LegalAcceptanceCall) = (call as LegalAcceptanceCall.Send).params

    @Test fun aServerWithout1055SendsTheThreeArgumentCall() {
        val s = status()
        assertNull(s.ageRequirement)
        val params = sent(LegalAcceptanceCall.make(s, "google", band = null))
        assertEquals(setOf("p_method", "p_terms_version", "p_privacy_notice_version"), params.keys)
        assertEquals("google", params["p_method"]!!.jsonPrimitive.content)
    }

    @Test fun bandsV2SendsSixKeysWithABooleanFalse() {
        val params = sent(LegalAcceptanceCall.make(code("bands_v2"), "email", LegalAgeBand.Teen))
        assertEquals(
            setOf("p_method", "p_terms_version", "p_privacy_notice_version", "p_age_attestation", "p_age_band", "p_lives_in_quebec"),
            params.keys,
        )
        assertEquals("bands_v2", params["p_age_attestation"]!!.jsonPrimitive.content)
        assertEquals("13_17", params["p_age_band"]!!.jsonPrimitive.content)
        val quebec = params["p_lives_in_quebec"] as JsonPrimitive
        assertFalse(quebec.isString) // a JSON boolean, not "false"
        assertEquals("false", quebec.content)
        assertTrue(params.toString().contains("\"p_lives_in_quebec\":false"))
        assertEquals("18_plus", sent(LegalAcceptanceCall.make(code("bands_v2"), "email", LegalAgeBand.Adult))["p_age_band"]!!.jsonPrimitive.content)
    }

    @Test fun bandsV1KeepsTheFiveKeyCall() {
        val params = sent(LegalAcceptanceCall.make(code("bands_v1"), "email", LegalAgeBand.Adult))
        assertEquals(
            setOf("p_method", "p_terms_version", "p_privacy_notice_version", "p_age_attestation", "p_age_band"),
            params.keys,
        )
        assertEquals("bands_v1", params["p_age_attestation"]!!.jsonPrimitive.content)
    }

    @Test fun singleBoxCodesSendTheFourKeyCall() {
        for (c in listOf("age_13_qc_14", "age_18")) {
            val params = sent(LegalAcceptanceCall.make(code(c), "email", band = null))
            assertEquals(setOf("p_method", "p_terms_version", "p_privacy_notice_version", "p_age_attestation"), params.keys)
            assertEquals(c, params["p_age_attestation"]!!.jsonPrimitive.content)
        }
    }

    @Test fun theFourKnownCodesAndNothingElse() {
        assertEquals(
            listOf("bands_v2", "bands_v1", "age_13_qc_14", "age_18"),
            LegalAgeRequirement.entries.map { it.code },
        )
        for (c in listOf("bands_v3", "age_21", "", "BANDS_V2")) {
            val s = code(c)
            assertTrue(c, s.requiresAppUpdate)
            assertEquals(LegalAcceptanceCall.UpdateRequired, LegalAcceptanceCall.make(s, "email", LegalAgeBand.Adult))
            assertTrue(LegalGateState.from(s).requiresAppUpdate)
        }
        assertEquals("Update MoveMark from the Play Store to continue.", LegalGateViewModel.UPDATE_APP)
    }

    @Test fun quebecYesMeansNothingIsEverSent() {
        // "Yes" gives no band for any age, so there is no call to make: zero accept calls.
        for (choice in LegalAgeChoice.entries) {
            assertNull(choice.band(livesInQuebec = true))
            assertEquals(LegalUnavailable.Quebec, LegalUnavailable.reason(choice, livesInQuebec = true))
            for (c in listOf("bands_v2", "bands_v1")) {
                assertEquals(
                    LegalAcceptanceCall.NotReady,
                    LegalAcceptanceCall.make(code(c), "email", choice.band(livesInQuebec = true)),
                )
            }
        }
        assertEquals(LegalUnavailable.Quebec, LegalUnavailable.reason(null, livesInQuebec = true))
    }

    @Test fun outsideQuebecTheAnswersMapToRanges() {
        assertEquals(listOf("Under 13", "13", "14 to 17", "18 or older"), LegalAgeChoice.entries.map { it.label })
        assertNull(LegalAgeChoice.Under13.band(false))
        assertEquals(LegalUnavailable.Age, LegalUnavailable.reason(LegalAgeChoice.Under13, false))
        assertEquals(LegalAgeBand.Teen, LegalAgeChoice.Thirteen.band(false))
        assertEquals(LegalAgeBand.Teen, LegalAgeChoice.FourteenToSeventeen.band(false))
        assertEquals(LegalAgeBand.Adult, LegalAgeChoice.Adult.band(false))
        // Quebec unanswered: no range yet.
        for (choice in LegalAgeChoice.entries) assertNull(choice.band(null))
        assertNull(LegalUnavailable.reason(LegalAgeChoice.Adult, false))
    }

    @Test fun ageCategoryIsRead() {
        assertEquals("teen", status(""","age_requirement":"bands_v2","age_category":"teen"""").ageCategory)
    }

    @Test fun continueNeedsTheTermsAndAnEligibleAnswer() {
        val v2 = LegalGateState(required = true, ageRequirement = "bands_v2")
        assertFalse(legalCanContinue(agreed = false, v2, LegalAgeBand.Adult))
        assertFalse(legalCanContinue(agreed = true, v2, band = null))
        assertTrue(legalCanContinue(agreed = true, v2, LegalAgeBand.Teen))
        assertFalse(legalCanContinue(agreed = true, v2.copy(isSaving = true), LegalAgeBand.Teen))
        assertFalse(legalCanContinue(agreed = true, v2.copy(regionRefused = true), LegalAgeBand.Adult))
        // Single box: it must be ticked.
        val single = LegalGateState(required = true, ageRequirement = "age_18")
        assertFalse(legalCanContinue(agreed = true, single, null, ageConfirmed = false))
        assertTrue(legalCanContinue(agreed = true, single, null, ageConfirmed = true))
        // A server without 1055: the terms box alone, as before.
        assertTrue(legalCanContinue(agreed = true, LegalGateState(required = true), band = null))
        // An unknown code: never.
        assertFalse(legalCanContinue(agreed = true, LegalGateState(required = true, ageRequirement = "bands_v9"), LegalAgeBand.Adult, true))
    }

    @Test fun theScreenStopsForQuebecOrUnder13Only() {
        val v2 = LegalGateState(required = true, ageRequirement = "bands_v2")
        assertNull(legalStop(v2, null, null))
        assertEquals(LegalUnavailable.Quebec, legalStop(v2, null, true))
        assertEquals(LegalUnavailable.Age, legalStop(v2, LegalAgeChoice.Under13, false))
        assertNull(legalStop(v2, LegalAgeChoice.Thirteen, false))
        assertEquals(LegalUnavailable.Quebec, legalStop(v2.copy(regionRefused = true), LegalAgeChoice.Adult, false))
        assertNull(legalStop(LegalGateState(required = true, ageRequirement = "age_18"), null, true))
    }

    @Test fun noStatusFailsOpen() {
        assertEquals(false, LegalGateState.from(null).required)
        assertEquals(true, LegalGateState.from(code("bands_v2")).required)
    }

    @Test fun refusalsMapToWhatTheScreenDoes() {
        fun text(msg: String) = LegalGateViewModel.serverText(PostgrestException(400, "22023", msg))
        assertEquals(AcceptFailure.RegionNotAvailable, LegalGateViewModel.classify(text("LEGAL_REGION_NOT_AVAILABLE")))
        assertEquals(AcceptFailure.AgeChanged, LegalGateViewModel.classify(text("LEGAL_REGION_REQUIRED")))
        assertEquals(AcceptFailure.AgeChanged, LegalGateViewModel.classify(text("LEGAL_AGE_ATTESTATION_INVALID")))
        assertEquals(AcceptFailure.AgeChanged, LegalGateViewModel.classify(text("LEGAL_AGE_ATTESTATION_REQUIRED")))
        assertEquals(AcceptFailure.AgeChanged, LegalGateViewModel.classify(text("LEGAL_AGE_BAND_INVALID")))
        assertEquals(AcceptFailure.DocumentsChanged, LegalGateViewModel.classify(text("LEGAL_VERSION_NOT_ACTIVE")))
        assertEquals(AcceptFailure.Other, LegalGateViewModel.classify(text("something else")))
        assertEquals(
            "The age requirement just changed. Please review it and confirm again.",
            LegalGateViewModel.AGE_CHANGED,
        )
        // The exception's own text doesn't carry the RAISE message; serverText does.
        assertFalse(PostgrestException(400, "22023", "LEGAL_REGION_REQUIRED").message!!.contains("LEGAL_REGION"))
    }

    /**
     * The exact bodies this build posts to `rpc/accept_legal_documents`, written out when -Dmovemark.legalContractOut is
     * set so they can be run against local Postgres with migrations through 1057 (versions are placeholders there).
     */
    @Test fun writesTheRequestBodiesForTheContractCheck() {
        val dir = System.getProperty("movemark.legalContractOut")?.takeIf { it.isNotBlank() } ?: return
        val placeholders = """"documents":{"terms":{"version":"TERMS"},"privacy_notice":{"version":"NOTICE"}}"""
        fun s(c: String) = json.decodeFromString(LegalStatus.serializer(), """{"acceptance_required":true,"age_requirement":"$c",$placeholders}""")
        val bodies = mapOf(
            "bands_v2-teen" to LegalAcceptanceCall.make(s("bands_v2"), "email", LegalAgeBand.Teen),
            "bands_v2-adult" to LegalAcceptanceCall.make(s("bands_v2"), "google", LegalAgeBand.Adult),
            "bands_v1-adult" to LegalAcceptanceCall.make(s("bands_v1"), "email", LegalAgeBand.Adult),
        )
        java.io.File(dir).apply { mkdirs() }.let { out ->
            bodies.forEach { (name, call) -> out.resolve("$name.json").writeText(sent(call).toString()) }
        }
    }
}
