package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.PropertySnapshot
import com.surensureshkumar.movemark.data.models.RoomRow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PropertyRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    private val dbDate = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    private companion object {
        const val MAX_PROPERTIES = 300L
    }

    // Decoded independently of the client's default (strict) serializer: the RPC's jsonb payload
    // mirrors whole table rows, and `ignoreUnknownKeys` keeps this resilient to future columns
    // the migration/schema adds that these Kotlin row models haven't been updated to include yet
    // (a decode failure on one unrelated new column would otherwise break the entire snapshot).
    private val snapshotJson = Json { ignoreUnknownKeys = true }

    /**
     * Single-round-trip replacement for the old rooms/inspections/inspection_items/evidence_files/
     * tags/documents/maintenance_issues fan-out. See `get_property_snapshot` in
     * supabase/migrations/20260719000001_property_snapshot_thumbnails_realtime.sql — SECURITY
     * INVOKER, so this still runs under the same per-table RLS as the direct `.select()` calls.
     */
    suspend fun fetchPropertySnapshot(propertyId: UUID): PropertySnapshot =
        decodeSnapshot(fetchPropertySnapshotJson(propertyId))

    /**
     * Same RPC call as [fetchPropertySnapshot], but returns the raw jsonb response string so
     * callers (see [PropertyHydrator]) can persist it verbatim to the offline cache and decode it
     * back with [decodeSnapshot] later, without a lossy re-serialize round trip.
     */
    suspend fun fetchPropertySnapshotJson(propertyId: UUID): String {
        val result = client.postgrest.rpc(
            "get_property_snapshot",
            buildJsonObject { put("p_property_id", propertyId.toString()) },
        )
        return result.data
    }

    fun decodeSnapshot(json: String): PropertySnapshot =
        snapshotJson.decodeFromString(PropertySnapshot.serializer(), json)

    suspend fun fetchProperties(userId: UUID): List<PropertyRow> =
        client.from("properties")
            .select {
                filter { eq("user_id", userId.toString()) }
                // Explicit order (previously implicit/unspecified) plus a cap so a long-time user's
                // property history can't grow this into an unbounded list; oldest-first preserves
                // `fetched.first()`'s existing "earliest property" default-selection behavior.
                order("created_at", Order.ASCENDING)
                limit(MAX_PROPERTIES)
            }
            .decodeList()

    suspend fun fetchRooms(propertyId: UUID): List<RoomRow> =
        client.from("rooms")
            .select {
                filter { eq("property_id", propertyId.toString()) }
                order("sort_order", Order.ASCENDING)
            }
            .decodeList()

    suspend fun createProperty(input: CreatePropertyInput, userId: UUID): PropertyRow {
        val id = UUID.randomUUID()
        val row = PropertyRow(
            id = id.toString(),
            userId = userId.toString(),
            title = input.titleValue,
            addressLine1 = input.addressLine1.trim().ifEmpty { "Address" },
            addressLine2 = input.unit.trim().takeIf { it.isNotEmpty() },
            city = input.city.trim().ifEmpty { "Unknown" },
            provinceState = input.region.trim().ifEmpty { "Unknown" },
            postalCode = input.postalCode.trim().ifEmpty { "00000" },
            country = input.country.trim().ifEmpty { "CA" },
            landlordName = input.landlordName.trim().takeIf { it.isNotEmpty() },
            landlordEmail = input.landlordEmail.trim().takeIf { it.isNotEmpty() },
            landlordPhone = input.landlordPhone.trim().takeIf { it.isNotEmpty() },
            moveInDate = dbDate.format(java.util.Date()),
        )
        return client.from("properties")
            .insert(row) { select() }
            .decodeSingle()
    }

    suspend fun insertDefaultRooms(propertyId: UUID) {
        val names = listOf(
            "Kitchen", "Living Room", "Primary Bedroom", "Bedroom 2",
            "Bathroom", "Bathroom 2", "Hallway", "Laundry",
            "Storage", "Balcony/Patio",
        )
        val rooms = names.mapIndexed { index, name ->
            RoomRow(
                id = UUID.randomUUID().toString(),
                propertyId = propertyId.toString(),
                name = name,
                sortOrder = index,
            )
        }
        client.from("rooms").insert(rooms) {
            select()
        }
    }

    suspend fun insertRoom(propertyId: UUID, name: String, sortOrder: Int): RoomRow {
        val row = RoomRow(
            id = UUID.randomUUID().toString(),
            propertyId = propertyId.toString(),
            name = name,
            sortOrder = sortOrder,
        )
        return client.from("rooms").insert(row) { select() }.decodeSingle()
    }
}
