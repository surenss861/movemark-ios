package com.surensureshkumar.movemark.data.backend

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.util.concurrent.atomic.AtomicInteger

class NeonAuthClientTest {
    private lateinit var server: MockWebServer
    private lateinit var storage: InMemorySessionStorage
    private var now = 1_000_000L
    private val tokenCalls = AtomicInteger(0)
    private var tokenStatus = 200
    private var tokenLifetime = 900L

    @Before
    fun setUp() {
        storage = InMemorySessionStorage()
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse = when (request.requestUrl!!.encodedPath) {
                    "/neondb/auth/sign-in/email", "/neondb/auth/sign-up/email" -> MockResponse()
                        .addHeader("Set-Cookie", "neon-auth.session_data=x; Path=/")
                        .addHeader("Set-Cookie", "neon-auth.session_token=abc123; Path=/; HttpOnly")
                        .setBody("""{"user":{"id":"5F7E0E0C-0000-4000-8000-000000000001","email":"qa@movemark.test"}}""")
                    "/neondb/auth/token" -> {
                        val n = tokenCalls.incrementAndGet()
                        if (tokenStatus != 200) MockResponse().setResponseCode(tokenStatus)
                        else MockResponse().setBody("""{"token":"${fakeJwt(tokenLifetime, "t$n")}"}""")
                    }
                    "/neondb/auth/sign-out" -> MockResponse().setBody("{}")
                    "/neondb/auth/request-password-reset" -> MockResponse().setBody("""{"status":true}""")
                    else -> MockResponse().setResponseCode(404)
                }
            }
            start()
        }
    }

    @After
    fun tearDown() = server.shutdown()

    private fun client() = NeonAuthClient(server.url("/neondb/auth"), OkHttpClient(), storage) { now }

    private fun takeUntil(path: String): RecordedRequest {
        while (true) {
            val request = server.takeRequest()
            if (request.requestUrl!!.encodedPath == path) return request
        }
    }

    @Test
    fun signInStoresSessionCookieAndMintsToken() = runTest {
        val auth = client()
        val user = auth.signIn("qa@movemark.test", "password1")
        assertEquals("5f7e0e0c-0000-4000-8000-000000000001", user.id)

        val signIn = takeUntil("/neondb/auth/sign-in/email")
        assertEquals("http://${server.hostName}:${server.port}", signIn.getHeader("Origin"))
        assertTrue(signIn.body.readUtf8().contains("\"email\":\"qa@movemark.test\""))
        val token = takeUntil("/neondb/auth/token")
        assertEquals("neon-auth.session_token=abc123", token.getHeader("Cookie"))
        assertNotNull(storage.value)

        // A fresh client restores the session from storage without the network.
        assertEquals(user, client().currentUser())
    }

    @Test
    fun cachedTokenIsReusedUntilCloseToExpiry() = runTest {
        val auth = client()
        auth.signIn("qa@movemark.test", "password1")
        val first = auth.validAccessToken()
        assertEquals(first, auth.validAccessToken())
        assertEquals(1, tokenCalls.get())

        now += (tokenLifetime - NeonAuthClient.REFRESH_LEEWAY_SECONDS) * 1000 + 1
        val second = auth.validAccessToken()
        assertTrue(first != second)
        assertEquals(2, tokenCalls.get())
    }

    @Test
    fun concurrentRefreshesShareOneMint() = runTest {
        val auth = client()
        auth.signIn("qa@movemark.test", "password1")
        val rejected = auth.validAccessToken()
        val tokens = (1..5).map { async { auth.refreshedAccessToken(replacing = rejected) } }.awaitAll()
        assertEquals(1, tokens.toSet().size)
        assertEquals(2, tokenCalls.get())
        // Holding an already-replaced token never refreshes again.
        assertEquals(tokens.first(), auth.refreshedAccessToken(replacing = rejected))
        assertEquals(2, tokenCalls.get())
    }

    @Test
    fun rejectedSessionSignsOutLocally() = runTest {
        val auth = client()
        auth.signIn("qa@movemark.test", "password1")
        tokenStatus = 401
        try {
            auth.validAccessToken(forceRefresh = true)
            fail("expected SessionExpired")
        } catch (_: NeonAuthException.SessionExpired) {
        }
        assertNull(storage.value)
        assertNull(auth.currentUser())
    }

    @Test
    fun signOutRevokesAndClears() = runTest {
        val auth = client()
        auth.signIn("qa@movemark.test", "password1")
        auth.signOut()
        val signOut = takeUntil("/neondb/auth/sign-out")
        assertEquals("neon-auth.session_token=abc123", signOut.getHeader("Cookie"))
        assertNotNull(signOut.getHeader("Origin"))
        assertNull(storage.value)
        try {
            auth.validAccessToken()
            fail("expected SessionExpired")
        } catch (_: NeonAuthException.SessionExpired) {
        }
    }

    @Test
    fun rejectedCredentialsMapToUserMessage() = runTest {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest) = MockResponse().setResponseCode(401)
                .setBody("""{"code":"INVALID_EMAIL_OR_PASSWORD","message":"Invalid email or password"}""")
        }
        try {
            client().signIn("qa@movemark.test", "wrong-pass")
            fail("expected Rejected")
        } catch (e: NeonAuthException.Rejected) {
            assertEquals("INVALID_EMAIL_OR_PASSWORD", e.code)
            assertEquals("Email or password is incorrect.", e.message)
        }
    }

    @Test
    fun jwtLifetimeComesFromIatAndExp() {
        assertEquals(900L, NeonAuthClient.lifetimeSecondsOfJwt(fakeJwt(900)))
        assertNull(NeonAuthClient.lifetimeSecondsOfJwt("not-a-jwt"))
    }
}
