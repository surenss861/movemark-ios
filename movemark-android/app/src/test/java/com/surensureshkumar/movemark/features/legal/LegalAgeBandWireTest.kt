package com.surensureshkumar.movemark.features.legal

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.legal.LegalAcceptanceCall
import com.surensureshkumar.movemark.data.legal.LegalAgeBand
import com.surensureshkumar.movemark.data.legal.LegalDocument
import com.surensureshkumar.movemark.data.legal.LegalDocuments
import com.surensureshkumar.movemark.data.legal.LegalRepository
import com.surensureshkumar.movemark.data.legal.LegalStatus
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/**
 * The age band on the wire, end to end (after the iOS 1.4 P0 where "18 or older" was sent as "13_17"): real taps on the
 * agreement screen → the screen's band → the real [LegalAcceptanceCall] → the real [LegalRepository.accept] over the
 * Data API client → the body a mock server receives. No credentials, no real backend.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LegalAgeBandWireTest {
    @get:Rule val compose = createComposeRule()

    private lateinit var server: MockWebServer
    private lateinit var repository: LegalRepository
    private val status = LegalStatus(
        enforced = true,
        acceptanceRequired = true,
        documents = LegalDocuments(LegalDocument("terms-2.0"), LegalDocument("privacy-2.0")),
        ageRequirement = "bands_v2",
    )

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val base = server.url("/neondb/rest/v1")
        val transport = AuthenticatedTransport(
            FakeTokens(),
            OkHttpClient(),
            AuthenticatedTransport.AuthOrigins(dataApiHost = base.host, apiHost = "api.invalid"),
        )
        repository = LegalRepository(PostgrestClient(base, transport))
    }

    @After
    fun tearDown() = server.shutdown()

    /** Drives the screen with real taps and returns the band it hands to onAccept. */
    private fun answer(ageTag: String): LegalAgeBand? {
        val accepted = mutableListOf<LegalAgeBand?>()
        compose.setContent {
            LegalAcceptanceScreen(
                state = LegalGateState(required = true, ageRequirement = "bands_v2"),
                onAccept = { accepted += it },
                onSignOut = {},
                onDeleteAccount = {},
            )
        }
        compose.onNodeWithText(LEGAL_CONSENT_TEXT).performScrollTo().performClick()
        compose.onNodeWithTag("legal.quebec.no").performScrollTo().performClick()
        compose.onNodeWithTag(ageTag).performScrollTo().performClick()
        compose.onNodeWithTag("legal.continue").performClick()
        assertEquals(1, accepted.size)
        return accepted.single()
    }

    /** Sends the screen's answer the way LegalGateViewModel.accept does and returns the body the server received. */
    private fun sendAndCapture(band: LegalAgeBand?): Map<String, kotlinx.serialization.json.JsonElement> {
        val call = LegalAcceptanceCall.make(status, "email", band) as LegalAcceptanceCall.Send
        server.enqueue(
            MockResponse().setBody(
                """{"enforced":true,"acceptance_required":false,"age_requirement":"bands_v2","age_category":"adult"}""",
            ),
        )
        runBlocking { repository.accept(call.params) }
        val request = server.takeRequest()
        assertTrue(request.path.orEmpty().endsWith("/rpc/accept_legal_documents"))
        return Json.parseToJsonElement(request.body.readUtf8()).jsonObject
    }

    @Test
    fun eighteenOrOlderIsSentAs18Plus() {
        val body = sendAndCapture(answer("legal.age.Adult"))
        assertEquals("18_plus", body["p_age_band"]!!.jsonPrimitive.content)
        assertEquals("bands_v2", body["p_age_attestation"]!!.jsonPrimitive.content)
        assertFalse(body["p_lives_in_quebec"]!!.jsonPrimitive.boolean)
    }

    @Test
    fun fourteenToSeventeenIsSentAs13To17() {
        val body = sendAndCapture(answer("legal.age.FourteenToSeventeen"))
        assertEquals("13_17", body["p_age_band"]!!.jsonPrimitive.content)
    }
}
