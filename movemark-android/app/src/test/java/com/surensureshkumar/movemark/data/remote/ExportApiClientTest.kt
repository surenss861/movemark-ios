package com.surensureshkumar.movemark.data.remote

import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.util.UUID

/** Export refusals read the way iOS `ExportRequestRefusal` reads them. */
class ExportApiClientTest {
    private lateinit var server: MockWebServer
    private lateinit var client: ExportApiClient

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val transport = AuthenticatedTransport(
            FakeTokens(),
            OkHttpClient(),
            AuthenticatedTransport.AuthOrigins(dataApiHost = "data.invalid", apiHost = server.hostName),
        )
        client = ExportApiClient(server.url("/"), transport)
    }

    @After
    fun tearDown() = server.shutdown()

    private suspend fun refusal(code: Int, body: String, request: suspend () -> Unit): Throwable {
        server.enqueue(MockResponse().setResponseCode(code).setBody(body))
        try {
            request()
        } catch (e: Throwable) {
            return e
        }
        fail("expected a refusal")
        throw AssertionError()
    }

    @Test
    fun paymentRequiredOpensThePaywallForEveryReportType() = runTest {
        val id = UUID.randomUUID()
        val a = refusal(402, """{"error":"x","code":"quota_exhausted"}""") { client.requestMoveInExport(id) }
        assertTrue(a is ExportApiException.PaymentRequired)
        assertEquals("quota_exhausted", (a as ExportApiException.PaymentRequired).code)
        assertTrue(refusal(402, "{}") { client.requestMoveOutExport(id) } is ExportApiException.PaymentRequired)
        assertTrue(
            refusal(403, """{"code":"pro_required"}""") { client.requestDisputePacketExport(id) } is ExportApiException.PaymentRequired,
        )
        val paths = List(3) { server.takeRequest().path }
        assertEquals(listOf("/api/exports/move-in", "/api/exports/move-out", "/api/exports/dispute-packet"), paths)
    }

    @Test
    fun alreadyActiveIsNotAnErrorAndNotAlwaysMoveOut() = runTest {
        val e = refusal(409, """{"code":"export_already_active"}""") { client.requestMoveInExport(UUID.randomUUID()) }
        assertTrue(e is ExportApiException.AlreadyActive)
        assertTrue(!e.message.orEmpty().contains("move-out"))
    }
}
