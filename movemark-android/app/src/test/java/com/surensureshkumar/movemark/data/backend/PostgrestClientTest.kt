package com.surensureshkumar.movemark.data.backend

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class PostgrestClientTest {
    @Serializable
    data class Row(val id: String, val name: String? = null, @SerialName("created_at") val createdAt: String? = null)

    private lateinit var server: MockWebServer
    private lateinit var client: PostgrestClient

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val base = server.url("/neondb/rest/v1")
        val transport = AuthenticatedTransport(
            FakeTokens(),
            OkHttpClient(),
            AuthenticatedTransport.AuthOrigins(dataApiHost = base.host, apiHost = "api.invalid"),
        )
        client = PostgrestClient(base, transport)
    }

    @After
    fun tearDown() = server.shutdown()

    @Test
    fun selectEncodesFiltersOrderAndLimit() = runTest {
        server.enqueue(MockResponse().setBody("""[{"id":"1","name":"Kitchen","extra":true}]"""))
        val rows = client.select<Row>("rooms") {
            eq("property_id", "p-1")
            isIn("name", listOf("Water damage", "a,b", "say \"hi\""))
            order("sort_order")
            order("id", ascending = false)
            limit(200)
        }
        assertEquals(listOf(Row("1", "Kitchen")), rows)

        val request = server.takeRequest()
        assertEquals("GET", request.method)
        assertEquals("/neondb/rest/v1/rooms", request.requestUrl!!.encodedPath)
        val url = request.requestUrl!!
        assertEquals("eq.p-1", url.queryParameter("property_id"))
        assertEquals("in.(\"Water damage\",\"a,b\",\"say \\\"hi\\\"\")", url.queryParameter("name"))
        assertEquals("sort_order.asc,id.desc", url.queryParameter("order"))
        assertEquals("200", url.queryParameter("limit"))
        assertEquals("*", url.queryParameter("select"))
        assertEquals("Bearer token-1", request.getHeader("Authorization"))
    }

    @Test
    fun insertReturningAsksForRepresentationAndOmitsNulls() = runTest {
        server.enqueue(MockResponse().setResponseCode(201).setBody("""[{"id":"1","name":"Hall","created_at":"2026-10-22T09:15:01.24133+00:00"}]"""))
        val inserted = client.insertReturning<Row, Row>("rooms", Row("1", "Hall"))
        assertEquals("2026-10-22T09:15:01.24133+00:00", inserted.single().createdAt)

        val request = server.takeRequest()
        assertEquals("POST", request.method)
        assertEquals("return=representation", request.getHeader("Prefer"))
        // Null columns are left to their database defaults.
        assertEquals("""{"id":"1","name":"Hall"}""", request.body.readUtf8())
    }

    @Test
    fun rpcWithoutParamsSendsEmptyObject() = runTest {
        server.enqueue(MockResponse().setBody("[]"))
        client.rpcRaw("get_vault_summaries")
        val request = server.takeRequest()
        assertEquals("POST", request.method)
        assertEquals("/neondb/rest/v1/rpc/get_vault_summaries", request.requestUrl!!.encodedPath)
        assertEquals("{}", request.body.readUtf8())
        assertTrue(request.getHeader("Content-Type")!!.startsWith("application/json"))
    }

    @Test
    fun rpcSendsParamsAsJson() = runTest {
        server.enqueue(MockResponse().setBody("""{"has_more":false}"""))
        client.rpcRaw("get_entry_photos_page", buildJsonObject { put("p_limit", 200) })
        assertEquals("""{"p_limit":200}""", server.takeRequest().body.readUtf8())
    }

    @Test
    fun updateAndDeleteAreFilteredAndMinimal() = runTest {
        server.enqueue(MockResponse().setResponseCode(204))
        server.enqueue(MockResponse().setResponseCode(204))
        client.update("profiles", Row("1", "New")) { eq("id", "1") }
        client.delete("inspection_item_tags") { eq("inspection_item_id", "item-1") }

        val update = server.takeRequest()
        assertEquals("PATCH", update.method)
        assertEquals("eq.1", update.requestUrl!!.queryParameter("id"))
        assertEquals("return=minimal", update.getHeader("Prefer"))
        val delete = server.takeRequest()
        assertEquals("DELETE", delete.method)
        assertEquals("eq.item-1", delete.requestUrl!!.queryParameter("inspection_item_id"))
    }

    @Test
    fun insertIgnoringDuplicatesUsesOnConflict() = runTest {
        server.enqueue(MockResponse().setResponseCode(201))
        client.insertIgnoringDuplicates("profiles", Row("1"), onConflict = "id")
        val request = server.takeRequest()
        assertEquals("id", request.requestUrl!!.queryParameter("on_conflict"))
        assertEquals("resolution=ignore-duplicates,return=minimal", request.getHeader("Prefer"))
    }

    @Test
    fun errorsBecomePostgrestExceptionWithoutRetry() = runTest {
        server.enqueue(MockResponse().setResponseCode(403).setBody("""{"code":"42501","message":"permission denied"}"""))
        try {
            client.select<Row>("rooms") { order("id"); limit(1) }
            fail("expected PostgrestException")
        } catch (e: PostgrestException) {
            assertEquals(403, e.status)
            assertEquals("42501", e.code)
            assertFalse(e.message!!.contains("permission"))
        }
        assertEquals(1, server.requestCount)
    }

    @Test
    fun quoteEscapesBackslashesAndQuotes() {
        assertEquals("\"a\\\\b\\\"c\"", PostgrestQuery.quote("a\\b\"c"))
    }
}
