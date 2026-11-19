package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.domain.RentalEditForm
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.util.UUID

/** What reaches `properties`: move_in_date / lease_start / lease_end as yyyy-MM-dd, as iOS writes them. */
class PropertyDatesStorageTest {
    private lateinit var server: MockWebServer
    private lateinit var repo: PropertyRepository

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val base = server.url("/rest/v1")
        val transport = AuthenticatedTransport(FakeTokens(), OkHttpClient(), AuthenticatedTransport.AuthOrigins(base.host, "api.invalid"))
        repo = PropertyRepository(PostgrestClient(base, transport))
    }

    @After
    fun tearDown() = server.shutdown()

    private fun echo() = server.enqueue(MockResponse().setBody(
        """[{"id":"p","user_id":"u","title":"t","address_line_1":"a","city":"c","province_state":"r","postal_code":"0","country":"CA"}]""",
    ))

    @Test
    fun addingARentalStoresAllThreeDates() = runTest {
        echo()
        repo.createProperty(
            CreatePropertyInput("", "12 Elm St", city = "Toronto", region = "ON", postalCode = "",
                moveInDate = LocalDate.of(2026, 9, 1), leaseStart = LocalDate.of(2026, 8, 15), leaseEnd = LocalDate.of(2027, 8, 14)),
            UUID.randomUUID(),
        )
        val body = Json.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals("2026-09-01", body["move_in_date"]!!.jsonPrimitive.content)
        assertEquals("2026-08-15", body["lease_start"]!!.jsonPrimitive.content)
        assertEquals("2027-08-14", body["lease_end"]!!.jsonPrimitive.content)
    }

    @Test
    fun firstRunSetupStoresMoveInAndNoLease() = runTest {
        echo()
        repo.createProperty(CreatePropertyInput("", "12 Elm St", city = "", region = "", postalCode = "", moveInDate = LocalDate.of(2026, 9, 1)), UUID.randomUUID())
        val body = Json.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals("2026-09-01", body["move_in_date"]!!.jsonPrimitive.content)
        assertFalse(body.containsKey("lease_start"))
        assertFalse(body.containsKey("lease_end"))
    }

    @Test
    fun editLeavesAnUnsetLeaseOutOfTheRequest() = runTest {
        server.enqueue(MockResponse().setResponseCode(204))
        val initial = RentalEditForm(addressLine1 = "12 Elm St", moveInDate = LocalDate.of(2026, 9, 1))
        repo.updateProperty(UUID.randomUUID(), initial.copy(moveInDate = LocalDate.of(2026, 9, 2)).toPatch(initial))
        val req = server.takeRequest()
        assertEquals("PATCH", req.method)
        val body = Json.parseToJsonElement(req.body.readUtf8()).jsonObject
        assertEquals("2026-09-02", body["move_in_date"]!!.jsonPrimitive.content)
        assertFalse("an unset lease is never overwritten", body.containsKey("lease_start") || body.containsKey("lease_end"))
    }
}
