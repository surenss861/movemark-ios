package com.surensureshkumar.movemark.data.legal

import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * P1 (Galaxy A14, 1.4.0 2026111301): after acceptance, a cold start showed "One last thing." again and kept it.
 *
 * `get_legal_status()` is `legal_status_for_user(nullif(auth.user_id(), '')::uuid)` with no null check. When the
 * Data API momentarily evaluates a valid token with `auth.user_id()` null (seen on dev as a one-off
 * LEGAL_NOT_AUTHENTICATED, which accept raises but status doesn't), it answers for a NULL user: documents published,
 * no acceptance, so `acceptance_required: true`. The app trusted that single answer. A "not required" answer can only
 * come from the real caller, so a "required" answer is confirmed before the gate is shown.
 */
class LegalStatusConfirmTest {
    private lateinit var server: MockWebServer
    private lateinit var repository: LegalRepository

    private val docs = """"documents":{"terms":{"version":"2.0"},"privacy_notice":{"version":"2.0"}}"""
    /** What the server returns for a NULL caller: the same as for an account that never accepted. */
    private val nullCallerAnswer = """{"enforced":false,"acceptance_required":true,"blocked":false,"age_requirement":"bands_v2","age_category":null,$docs,"accepted":null}"""
    private val acceptedAnswer = """{"enforced":false,"acceptance_required":false,"blocked":false,"age_requirement":"bands_v2","age_category":"adult",$docs,"accepted":{"terms_version":"2.0","privacy_notice_version":"2.0","age_attestation":"bands_v2","age_band":"adult","residence":"outside_quebec"}}"""

    @Before fun setUp() {
        server = MockWebServer().apply { start() }
        val base = server.url("/neondb/rest/v1")
        val transport = AuthenticatedTransport(
            FakeTokens(), OkHttpClient(), AuthenticatedTransport.AuthOrigins(dataApiHost = base.host, apiHost = "api.invalid"),
        )
        repository = LegalRepository(PostgrestClient(base, transport), confirmDelayMillis = 0)
    }

    @After fun tearDown() = server.shutdown()

    private fun answer(body: String) = server.enqueue(MockResponse().setBody(body).setHeader("Content-Type", "application/json"))

    @Test fun aOneOffRequiredAnswerAfterAcceptanceDoesNotReopenTheGate() = runTest {
        answer(nullCallerAnswer)
        answer(acceptedAnswer)
        val result = repository.statusResult()
        val status = (result as LegalStatusResult.Success).status
        assertFalse("the gate must not reopen for an account that accepted", status.needsAcceptance)
        assertEquals(2, server.requestCount)
    }

    @Test fun theForegroundRecheckIsConfirmedToo() = runTest {
        answer(nullCallerAnswer)
        answer(acceptedAnswer)
        assertFalse(repository.status()!!.needsAcceptance)
    }

    @Test fun aNewAccountStillGetsTheGateAfterConfirmation() = runTest {
        repeat(3) { answer(nullCallerAnswer) }
        val status = (repository.statusResult() as LegalStatusResult.Success).status
        assertTrue(status.needsAcceptance)
        assertEquals(3, server.requestCount)
    }

    @Test fun notRequiredIsTrustedAtOnce() = runTest {
        answer(acceptedAnswer)
        assertFalse((repository.statusResult() as LegalStatusResult.Success).status.needsAcceptance)
        assertEquals(1, server.requestCount)
    }

    @Test fun aConfirmationThatFailsKeepsTheFirstAnswer() = runTest {
        answer(nullCallerAnswer)
        server.enqueue(MockResponse().setResponseCode(500).setBody("""{"code":"XX000","message":"boom"}"""))
        server.enqueue(MockResponse().setResponseCode(500).setBody("""{"code":"XX000","message":"boom"}"""))
        assertTrue((repository.statusResult() as LegalStatusResult.Success).status.needsAcceptance)
    }
}
