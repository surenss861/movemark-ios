package com.surensureshkumar.movemark.data.backend

import com.surensureshkumar.movemark.data.evidence.EvidenceCaptureSource
import com.surensureshkumar.movemark.data.evidence.EvidenceFormats
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import com.surensureshkumar.movemark.data.evidence.PreparedEvidence
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.util.Collections

class MoveMarkStorageServiceTest {
    private lateinit var server: MockWebServer
    private lateinit var service: MoveMarkStorageService
    private val requests = Collections.synchronizedList(mutableListOf<RecordedRequest>())

    /** Path → response; unmatched paths 404. */
    private val routes = Collections.synchronizedMap(mutableMapOf<String, () -> MockResponse>())

    private val sourceBytes = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 1, 2, 3)
    private val prepared = PreparedEvidence(
        source = EvidenceSource(
            data = sourceBytes,
            mimeType = "image/jpeg",
            fileExtension = "jpg",
            pixelWidth = 4032,
            pixelHeight = 3024,
            sha256Hex = EvidenceFormats.sha256Hex(sourceBytes),
            capturedAt = "2026-10-20T12:00:00Z",
            captureSource = EvidenceCaptureSource.Camera,
        ),
        derivative = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 9, 9),
        thumbnail = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 7),
    )

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse {
                    requests += request
                    val key = "${request.method} ${request.requestUrl!!.encodedPath}"
                    return routes[key]?.invoke() ?: MockResponse().setResponseCode(404)
                }
            }
            start()
        }
        val transport = AuthenticatedTransport(
            FakeTokens(),
            OkHttpClient(),
            AuthenticatedTransport.AuthOrigins(dataApiHost = "data.invalid", apiHost = server.hostName),
        )
        service = MoveMarkStorageService(server.url("/"), transport, OkHttpClient())
    }

    @After
    fun tearDown() = server.shutdown()

    private fun ticketJson(finalizeRequired: Boolean = true) = """
        {"uploadTicketId":"t-1","bucket":"inspection-media","path":"u/p/move-in/r/x.jpg",
         "url":"${server.url("/put/derivative")}","method":"PUT",
         "headers":{"Content-Type":"image/jpeg","Content-Length":"5"},
         "thumbnail":{"path":"u/p/move-in/r/x_thumb.jpg","url":"${server.url("/put/thumb")}","method":"PUT",
                      "headers":{"Content-Type":"image/jpeg","Content-Length":"4"}},
         "source":{"path":"u/p/move-in/r/x_source.jpg","url":"${server.url("/put/source")}","method":"PUT",
                   "headers":{"Content-Type":"image/jpeg","Content-Length":"6","x-amz-checksum-sha256":"c2hh",
                              "x-amz-sdk-checksum-algorithm":"SHA256"}},
         "finalizeRequired":$finalizeRequired,"expiresInSeconds":600}
    """.trimIndent()

    private fun ok(body: String = "") = { MockResponse().setBody(body) }

    private fun happyRoutes() {
        routes["POST /api/storage/uploads"] = ok(ticketJson())
        routes["PUT /put/source"] = ok()
        routes["PUT /put/derivative"] = ok()
        routes["PUT /put/thumb"] = ok()
        routes["POST /api/storage/uploads/t-1/finalize"] = ok("""{"status":"finalized","thumbnail":true}""")
        routes["POST /api/storage/uploads/t-1/abandon"] = ok("""{"status":"deleted"}""")
    }

    private fun recorded(key: String) = requests.first { "${it.method} ${it.requestUrl!!.encodedPath}" == key }

    @Test
    fun evidenceUploadFollowsTicketPutFinalize() = runTest {
        happyRoutes()
        val upload = service.uploadEvidence(prepared, "P-1", "R-1", isMoveOut = false)

        assertEquals("u/p/move-in/r/x.jpg", upload.path)
        assertEquals("u/p/move-in/r/x_thumb.jpg", upload.thumbnailPath)
        assertEquals("u/p/move-in/r/x_source.jpg", upload.sourcePath)
        assertEquals("2026-10-20T12:00:00Z", upload.capturedAt)
        assertEquals(
            listOf(
                "POST /api/storage/uploads", "PUT /put/source", "PUT /put/derivative", "PUT /put/thumb",
                "POST /api/storage/uploads/t-1/finalize",
            ),
            requests.map { "${it.method} ${it.requestUrl!!.encodedPath}" },
        )

        val ticket = Json.parseToJsonElement(recorded("POST /api/storage/uploads").body.readUtf8()).jsonObject
        assertEquals("evidence", ticket["kind"]!!.jsonPrimitive.content)
        assertEquals("p-1", ticket["propertyId"]!!.jsonPrimitive.content)
        assertEquals("move_in", ticket["phase"]!!.jsonPrimitive.content)
        assertEquals(5, ticket["size"]!!.jsonPrimitive.int)
        val source = ticket["source"]!!.jsonObject
        assertEquals(prepared.source.sha256Hex, source["sha256"]!!.jsonPrimitive.content)
        assertEquals("camera", source["captureSource"]!!.jsonPrimitive.content)
        assertEquals(6, source["size"]!!.jsonPrimitive.int)

        // Presigned PUTs carry exactly the signed headers and the untouched bytes — never our token.
        val put = recorded("PUT /put/source")
        assertArrayEquals(sourceBytes, put.body.readByteArray())
        assertEquals("image/jpeg", put.getHeader("Content-Type"))
        assertEquals("6", put.getHeader("Content-Length"))
        assertEquals("c2hh", put.getHeader("x-amz-checksum-sha256"))
        assertNull(put.getHeader("Authorization"))
        assertEquals("Bearer token-1", recorded("POST /api/storage/uploads").getHeader("Authorization"))
    }

    @Test
    fun failedPutReleasesTheTicket() = runTest {
        happyRoutes()
        routes["PUT /put/derivative"] = { MockResponse().setResponseCode(403) }
        try {
            service.uploadEvidence(prepared, "p", "r", isMoveOut = true)
            fail("expected MoveMarkUploadFailure")
        } catch (e: MoveMarkUploadFailure) {
            assertTrue(e.underlying is MoveMarkStorageException.UploadFailed)
            assertNull(e.unreleased) // abandon got through
        }
        recorded("POST /api/storage/uploads/t-1/abandon")
        assertTrue(requests.none { it.requestUrl!!.encodedPath.endsWith("/finalize") })
    }

    @Test
    fun unreleasedTicketIsReportedWhenAbandonFails() = runTest {
        happyRoutes()
        routes["POST /api/storage/uploads/t-1/finalize"] = { MockResponse().setResponseCode(409).setBody("""{"code":"source_checksum_mismatch"}""") }
        routes["POST /api/storage/uploads/t-1/abandon"] = { MockResponse().setResponseCode(500) }
        try {
            service.uploadEvidence(prepared, "p", "r", isMoveOut = false)
            fail("expected MoveMarkUploadFailure")
        } catch (e: MoveMarkUploadFailure) {
            assertEquals("t-1", e.unreleased?.ticketId)
        }
    }

    @Test
    fun thumbnailFailureIsBestEffort() = runTest {
        happyRoutes()
        routes["PUT /put/thumb"] = { MockResponse().setResponseCode(500) }
        routes["POST /api/storage/uploads/t-1/finalize"] = ok("""{"status":"finalized","thumbnail":false}""")
        val upload = service.uploadEvidence(prepared, "p", "r", isMoveOut = false)
        assertNull(upload.thumbnailPath)
    }

    @Test
    fun abandonReportsKeptDeletedFailed() = runTest {
        val upload = MoveMarkUpload("t-1", "inspection-media", "a.jpg", null)
        routes["POST /api/storage/uploads/t-1/abandon"] = ok("""{"status":"kept","reason":"referenced"}""")
        assertEquals(AbandonResult.Kept, service.abandon(upload))
        routes["POST /api/storage/uploads/t-1/abandon"] = ok("""{"status":"deleted"}""")
        assertEquals(AbandonResult.Deleted, service.abandon(upload))
        routes["POST /api/storage/uploads/t-1/abandon"] = { MockResponse().setResponseCode(503) }
        assertEquals(AbandonResult.Failed, service.abandon(upload))
    }

    @Test
    fun rejectionsMapToUserMessages() = runTest {
        routes["POST /api/storage/uploads"] = { MockResponse().setResponseCode(413).setBody("""{"error":"Upload not allowed","code":"too_large"}""") }
        assertMessage("This file is too large to upload.")
        routes["POST /api/storage/uploads"] = { MockResponse().setResponseCode(400).setBody("""{"error":"Upload not allowed","code":"unsupported_type"}""") }
        assertMessage("This file type isn’t supported.")
        routes["POST /api/storage/uploads"] = { MockResponse().setResponseCode(429).setBody("""{"error":"Too many requests"}""") }
        assertMessage("That’s a lot at once. Wait a minute, then try again.")
    }

    private suspend fun assertMessage(expected: String) {
        try {
            service.uploadDocument(byteArrayOf(1), "application/pdf", null, "p", "lease")
            fail("expected rejection")
        } catch (e: MoveMarkStorageException.Rejected) {
            assertEquals(expected, e.message)
        }
    }

    @Test
    fun downloadsAndDeletesAreByRowId() = runTest {
        routes["POST /api/storage/downloads"] = ok("""{"items":[{"id":"ID-1","url":"https://s/a","thumbnailUrl":null}],"expiresInSeconds":3600}""")
        val urls = service.downloadUrls(MoveMarkStorageService.DownloadKind.Evidence, listOf("ID-1"))
        assertEquals("https://s/a", urls["id-1"]?.url)
        assertEquals("""{"kind":"evidence","ids":["id-1"]}""", recorded("POST /api/storage/downloads").body.readUtf8())

        // One already-deleted row makes the batch 404; the rest are then deleted one by one.
        var calls = 0
        routes["DELETE /api/storage/evidence"] = { calls++; if (calls == 1) MockResponse().setResponseCode(404) else MockResponse().setResponseCode(204) }
        service.deleteEvidence(listOf("a", "b"))
        assertEquals(3, calls)
    }
}
