package com.surensureshkumar.movemark.data.backend

import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AuthenticatedTransportTest {
    private lateinit var server: MockWebServer
    private lateinit var tokens: FakeTokens

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        tokens = FakeTokens()
    }

    @After
    fun tearDown() = server.shutdown()

    private fun transport(dataApiHost: String? = "data.invalid", apiHost: String? = "api.invalid") =
        AuthenticatedTransport(tokens, OkHttpClient(), AuthenticatedTransport.AuthOrigins(dataApiHost, apiHost))

    private fun get() = Request.Builder().url(server.url("/x")).build()

    @Test
    fun apiUnauthorizedRefreshesOnceAndRetries() = runTest {
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(MockResponse().setBody("ok"))
        val response = transport(apiHost = server.hostName).execute(get())

        assertEquals(200, response.code)
        assertEquals(1, tokens.refreshes.get())
        assertEquals("Bearer token-1", server.takeRequest().getHeader("Authorization"))
        assertEquals("Bearer token-2", server.takeRequest().getHeader("Authorization"))
    }

    @Test
    fun secondRejectionIsReturnedNotLooped() = runTest {
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(MockResponse().setResponseCode(401))
        val response = transport(apiHost = server.hostName).execute(get())
        assertEquals(401, response.code)
        assertEquals(2, server.requestCount)
        assertEquals(1, tokens.refreshes.get())
    }

    @Test
    fun dataApiExpiredTokenMessageRetries() = runTest {
        server.enqueue(MockResponse().setResponseCode(400).setBody("""{"code":null,"message":"JWT token has expired"}"""))
        server.enqueue(MockResponse().setBody("[]"))
        val response = transport(dataApiHost = server.hostName).execute(get())
        assertEquals(200, response.code)
        assertEquals(1, tokens.refreshes.get())
    }

    @Test
    fun ordinaryErrorsPassThrough() = runTest {
        // A PostgREST error carries a code; a 401 from a host that isn't the API is not ours to refresh for.
        server.enqueue(MockResponse().setResponseCode(400).setBody("""{"code":"PGRST100","message":"JWT token has expired"}"""))
        assertEquals(400, transport(dataApiHost = server.hostName).execute(get()).code)
        server.enqueue(MockResponse().setResponseCode(401))
        assertEquals(401, transport(apiHost = "other.invalid").execute(get()).code)
        server.enqueue(MockResponse().setResponseCode(403))
        assertEquals(403, transport(apiHost = server.hostName).execute(get()).code)
        assertEquals(0, tokens.refreshes.get())
    }

    @Test
    fun rejectionRulesAreScopedToTheirOrigin() {
        val origins = AuthenticatedTransport.AuthOrigins(dataApiHost = "data.example", apiHost = "api.example")
        val expired = """{"code":null,"message":"JWT token has expired"}""".toByteArray()
        assertTrue(AuthenticatedTransport.isAuthRejection(400, "data.example", expired, origins))
        assertFalse(AuthenticatedTransport.isAuthRejection(400, "api.example", expired, origins))
        assertTrue(AuthenticatedTransport.isAuthRejection(401, "API.example", ByteArray(0), origins))
        assertFalse(AuthenticatedTransport.isAuthRejection(401, "data.example", ByteArray(0), origins))
        val missing = """{"message":"missing authentication credentials"}""".toByteArray()
        assertFalse(AuthenticatedTransport.isAuthRejection(400, "data.example", missing, origins))
    }
}
