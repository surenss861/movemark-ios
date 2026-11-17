package com.surensureshkumar.movemark.data.auth

import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.UUID

/** A failed read of the name must never look like "no name" (the A14 offline-onboarding P0). */
class ProfileRepositoryLookupTest {
    private lateinit var server: MockWebServer
    private lateinit var repository: ProfileRepository
    private val user = UUID.fromString("00000000-0000-4000-8000-000000000001")

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val base = server.url("/neondb/rest/v1")
        val transport = AuthenticatedTransport(
            FakeTokens(),
            OkHttpClient(),
            AuthenticatedTransport.AuthOrigins(dataApiHost = base.host, apiHost = "api.invalid"),
        )
        repository = ProfileRepository(PostgrestClient(base, transport))
    }

    @After
    fun tearDown() = server.shutdown()

    @Test
    fun savedNameIsFound() = runTest {
        server.enqueue(MockResponse().setBody("""[{"id":"$user","full_name":"  Avery Tester "}]"""))
        assertEquals(ProfileLookup.Found("Avery Tester"), repository.lookupFullName(user))
    }

    @Test
    fun blankOrAbsentNameIsMissing() = runTest {
        server.enqueue(MockResponse().setBody("""[{"id":"$user","full_name":""}]"""))
        assertEquals(ProfileLookup.Missing, repository.lookupFullName(user))
        server.enqueue(MockResponse().setBody("[]"))
        assertEquals(ProfileLookup.Missing, repository.lookupFullName(user))
    }

    @Test
    fun droppedConnectionIsFailed() = runTest {
        // OkHttp may retry a dropped connection once; every attempt is dropped.
        repeat(3) { server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AT_START)) }
        assertTrue(repository.lookupFullName(user) is ProfileLookup.Failed)
    }

    @Test
    fun serverErrorIsFailed() = runTest {
        server.enqueue(MockResponse().setResponseCode(503).setBody("""{"message":"unavailable"}"""))
        assertTrue(repository.lookupFullName(user) is ProfileLookup.Failed)
    }

    @Test
    fun unreachableHostIsFailed() = runTest {
        server.shutdown()
        assertTrue(repository.lookupFullName(user) is ProfileLookup.Failed)
    }
}
