package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.UUID

class ChecklistRepositoryTest {
    private lateinit var server: MockWebServer
    private lateinit var repo: ChecklistRepository

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val base = server.url("/rest/v1")
        val transport = AuthenticatedTransport(FakeTokens(), OkHttpClient(), AuthenticatedTransport.AuthOrigins(base.host, "api.invalid"))
        repo = ChecklistRepository(PostgrestClient(base, transport))
    }

    @After
    fun tearDown() = server.shutdown()

    @Test
    fun upsertMergesOnPropertyAndUser() = runTest {
        server.enqueue(MockResponse().setResponseCode(201))
        val row = MoveOutChecklistRow.empty(UUID.randomUUID(), UUID.randomUUID()).with(MoveOutChecklistRow.Item.KeysReturned, true)
        repo.upsert(row)
        val req = server.takeRequest()
        assertEquals("POST", req.method)
        assertTrue(req.path!!.contains("on_conflict=property_id%2Cuser_id") || req.path!!.contains("on_conflict=property_id,user_id"))
        assertTrue(req.getHeader("Prefer")!!.contains("resolution=merge-duplicates"))
        val body = Json.parseToJsonElement(req.body.readUtf8()).jsonObject
        assertTrue(body["keys_returned"]!!.jsonPrimitive.boolean)
        assertEquals(1, row.completedCount)
    }

    @Test
    fun fetchReturnsNullWhenThereIsNoRow() = runTest {
        server.enqueue(MockResponse().setBody("[]"))
        assertNull(repo.fetch(UUID.randomUUID(), UUID.randomUUID()))
    }

    @Test
    fun everyItemTogglesItsOwnColumn() {
        val empty = MoveOutChecklistRow.empty(UUID.randomUUID(), UUID.randomUUID())
        MoveOutChecklistRow.Item.entries.forEach { item ->
            val toggled = empty.with(item, true)
            assertTrue(toggled.isDone(item))
            assertEquals(1, toggled.completedCount)
        }
        assertEquals(6, MoveOutChecklistRow.Item.entries.fold(empty) { r, i -> r.with(i, true) }.completedCount)
    }
}
