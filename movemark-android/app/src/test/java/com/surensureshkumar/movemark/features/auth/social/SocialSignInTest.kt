package com.surensureshkumar.movemark.features.auth.social

import android.app.Activity
import com.surensureshkumar.movemark.data.backend.InMemorySessionStorage
import com.surensureshkumar.movemark.data.backend.NeonAuthClient
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import com.surensureshkumar.movemark.data.backend.fakeJwt
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * The social-sign-in probe layer (iOS SocialSignInTests): the gate never accepts a non-probe URL; signInSocial
 * sends exactly the Better Auth ID-token request and keeps a session only on success; the probe runner always
 * leaves the probe signed out and never calls the network for a dismissed sheet.
 */
@RunWith(RobolectricTestRunner::class)
class SocialSignInTest {
    private lateinit var server: MockWebServer
    private var socialStatus = 200
    private var socialBody = """{"redirect":false,"token":"t","user":{"id":"22222222-2222-4222-8222-222222222222","email":"probe@gmail.com"}}"""
    private val activity: Activity by lazy { Robolectric.buildActivity(Activity::class.java).get() }

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse = when (request.requestUrl!!.encodedPath) {
                    "/neondb/auth/sign-in/social" ->
                        if (socialStatus == 200) MockResponse()
                            .addHeader("Set-Cookie", "__Secure-neon-auth.session_token=cookie-value; Path=/; HttpOnly")
                            .setBody(socialBody)
                        else MockResponse().setResponseCode(socialStatus).setBody(socialBody)
                    "/neondb/auth/token" -> MockResponse().setBody("""{"token":"${fakeJwt(900)}"}""")
                    "/neondb/auth/sign-out" -> MockResponse().setBody("{}")
                    else -> MockResponse().setResponseCode(404)
                }
            }
            start()
        }
    }

    @After
    fun tearDown() = server.shutdown()

    private fun client(storage: InMemorySessionStorage = InMemorySessionStorage()) =
        NeonAuthClient(server.url("/neondb/auth"), OkHttpClient(), storage)

    private fun paths(): List<String> = List(server.requestCount) { server.takeRequest().requestUrl!!.encodedPath }

    // ---- Gate ----

    @Test
    fun probeUrlIsOnlyAnHttpsNeonAuthHostThatIsNotTheApps() {
        val app = "https://ep-app-999.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth".toHttpUrl()
        val cases = mapOf(
            "https://ep-probe-123.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth" to true,
            "http://ep-probe-123.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth" to false,
            "https://evil.example/neondb/auth" to false,
            "https://ep-x.neonauth.us-east-2.aws.neon.tech.evil.example/auth" to false,
            "https://ep-app-999.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth" to false,
            "" to false,
            "not a url" to false,
        )
        cases.forEach { (raw, accepted) ->
            assertEquals(raw, accepted, SocialSignInConfig.validatedProbeUrl(raw, app) != null)
        }
    }

    @Test
    fun providerOrderIsGoogleFirstOnAndroid() {
        assertEquals(listOf(SocialProvider.GOOGLE, SocialProvider.APPLE), SocialProvider.androidOrder)
    }

    @Test
    fun nonceHelpers() {
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", NativeSocialCredentialProvider.sha256Hex("abc"))
        val a = NativeSocialCredentialProvider.randomNonce()
        assertEquals(32, a.length)
        assertNotEquals(a, NativeSocialCredentialProvider.randomNonce())
    }

    // ---- signInSocial ----

    @Test
    fun signInSocialSendsTheIdTokenRequestAndKeepsTheSession() = runTest {
        val storage = InMemorySessionStorage()
        val auth = client(storage)
        val user = auth.signInSocial("google", "g-token", "the-nonce")
        assertEquals("22222222-2222-4222-8222-222222222222", user.id)

        val request = server.takeRequest()
        assertEquals("/neondb/auth/sign-in/social", request.requestUrl!!.encodedPath)
        assertEquals("http://${server.hostName}:${server.port}", request.getHeader("Origin"))
        val json = Json.parseToJsonElement(request.body.readUtf8()).jsonObject
        assertEquals(setOf("provider", "idToken"), json.keys)  // no callbackURL: never the redirect flow
        assertEquals("google", json["provider"]!!.jsonPrimitive.content)
        val idToken = json["idToken"]!!.jsonObject
        assertEquals("g-token", idToken["token"]!!.jsonPrimitive.content)
        assertEquals("the-nonce", idToken["nonce"]!!.jsonPrimitive.content)
        assertEquals("/neondb/auth/token", server.takeRequest().requestUrl!!.encodedPath)  // proved usable first
        assertNotNull(storage.value)
        assertEquals(user, auth.currentUser())
    }

    @Test
    fun missingNonceIsOmitted() = runTest {
        client().signInSocial("apple", "a-token", null)
        val json = Json.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertFalse(json["idToken"]!!.jsonObject.containsKey("nonce"))
    }

    @Test
    fun rejectedTokenKeepsNoSession() = runTest {
        for ((status, code) in listOf(401 to "ACCOUNT_NOT_LINKED", 400 to "INVALID_TOKEN")) {
            socialStatus = status
            socialBody = """{"code":"$code","message":"no"}"""
            val storage = InMemorySessionStorage()
            val auth = client(storage)
            try {
                auth.signInSocial("google", "x", null)
                fail("expected rejection for $code")
            } catch (e: NeonAuthException.Rejected) {
                assertEquals(code, e.code)
            }
            assertNull(auth.currentUser())
            assertNull(storage.value)
        }
        assertTrue(paths().none { it.endsWith("/token") })
    }

    // ---- Probe runner ----

    @Test
    fun probeRunReportsIdentityThenSignsOutOfTheProbe() = runTest {
        val storage = InMemorySessionStorage()
        val probe = server.url("/neondb/auth")
        val runner = SocialProbeRunner(
            credentials = { _, p -> SocialIdentityToken(p, "id", "n") },
            makeClient = { url -> assertEquals(probe, url); client(storage) },
        )
        val result = runner.run(activity, SocialProvider.GOOGLE, probe)
        assertEquals(SocialProbeResult(SocialProvider.GOOGLE, "22222222-2222-4222-8222-222222222222", "probe@gmail.com"), result)
        assertEquals("/neondb/auth/sign-out", paths().last())
        assertNull(storage.value)
    }

    @Test
    fun dismissedSheetMakesNoNetworkCall() = runTest {
        val runner = SocialProbeRunner(
            credentials = { _, _ -> throw SocialSignInException.Cancelled() },
            makeClient = { client() },
        )
        try {
            runner.run(activity, SocialProvider.GOOGLE, server.url("/neondb/auth"))
            fail("expected cancellation")
        } catch (_: SocialSignInException.Cancelled) {
        }
        assertEquals(0, server.requestCount)
    }

    @Test
    fun failedProbeSignInLeavesNoProbeSession() = runTest {
        socialStatus = 401
        socialBody = """{"code":"ACCOUNT_NOT_LINKED","message":"account not linked"}"""
        val storage = InMemorySessionStorage()
        val runner = SocialProbeRunner(credentials = { _, p -> SocialIdentityToken(p, "id", null) }, makeClient = { client(storage) })
        try {
            runner.run(activity, SocialProvider.GOOGLE, server.url("/neondb/auth"))
            fail("expected rejection")
        } catch (_: NeonAuthException.Rejected) {
        }
        assertNull(storage.value)
    }

    @Test
    fun appleIsUnavailableUntilTheBrowserFlowIsProven() = runTest {
        try {
            NativeSocialCredentialProvider(googleWebClientId = "x").credential(activity, SocialProvider.APPLE)
            fail("expected unavailable")
        } catch (_: SocialSignInException.ProviderUnavailable) {
        }
    }

    @Test
    fun googleWithoutAClientIdIsUnavailable() = runTest {
        try {
            NativeSocialCredentialProvider(googleWebClientId = "").credential(activity, SocialProvider.GOOGLE)
            fail("expected unavailable")
        } catch (_: SocialSignInException.ProviderUnavailable) {
        }
    }

    @Test
    fun socialIsOffWithoutAProbeUrl() {
        // Unit tests build the debug variant with no SOCIAL_PROBE_AUTH_URL in CI: the block must stay hidden.
        if (com.surensureshkumar.movemark.BuildConfig.SOCIAL_PROBE_AUTH_URL.isBlank()) assertFalse(SocialSignInConfig.isEnabled)
    }
}
