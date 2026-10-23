package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.models.EntryPhotosPage
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.PropertySnapshotV2
import com.surensureshkumar.movemark.data.models.RoomEntriesPage
import com.surensureshkumar.movemark.data.models.RoomRow
import com.surensureshkumar.movemark.data.models.VaultSummary
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PropertyRepository @Inject constructor(
    private val postgrest: PostgrestClient,
) {
    private val dbDate = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    private companion object {
        const val MAX_PROPERTIES = 300
        const val MAX_ROOMS = 200
        const val ENTRIES_PER_ROOM = 30
        const val PHOTOS_PER_ENTRY = 12
    }

    /**
     * The bounded property snapshot in one round trip — rooms with true totals, the newest entries and their
     * first photos, documents, maintenance. See `get_property_snapshot_v2` in
     * neon/migrations/0990_bounded_snapshot_v2.sql — SECURITY INVOKER, so RLS applies as for direct reads.
     * Returns the raw JSON so [PropertyHydrator] can persist it verbatim to the offline cache.
     */
    suspend fun fetchPropertySnapshotJson(propertyId: UUID): String =
        postgrest.rpcRaw(
            "get_property_snapshot_v2",
            buildJsonObject {
                put("p_property_id", propertyId.toString())
                put("p_entries_per_room", ENTRIES_PER_ROOM)
                put("p_photos_per_entry", PHOTOS_PER_ENTRY)
            },
        )

    fun decodeSnapshot(json: String): PropertySnapshotV2 =
        postgrest.json.decodeFromString(PropertySnapshotV2.serializer(), json)

    /** Older entries of one room and stage, newest first, before the (created_at, id) cursor. */
    suspend fun fetchRoomEntriesPage(
        roomId: UUID,
        inspectionType: String,
        beforeCreatedAt: String?,
        beforeId: String?,
        limit: Int,
    ): RoomEntriesPage = postgrest.rpc(
        "get_room_entries_page",
        RoomEntriesPage.serializer(),
        buildJsonObject {
            put("p_room_id", roomId.toString())
            put("p_inspection_type", inspectionType)
            // The function wants both halves of the cursor or neither.
            if (beforeCreatedAt != null && beforeId != null) {
                put("p_before_created_at", beforeCreatedAt)
                put("p_before_id", beforeId)
            } else {
                put("p_before_created_at", JsonNull)
                put("p_before_id", JsonNull)
            }
            put("p_limit", limit)
            put("p_photos_per_entry", PHOTOS_PER_ENTRY)
        },
    )

    /** One entry's photos after the (created_at, id) cursor, in capture order. */
    suspend fun fetchEntryPhotosPage(
        inspectionItemId: UUID,
        afterCreatedAt: String?,
        afterId: String?,
        limit: Int,
    ): EntryPhotosPage = postgrest.rpc(
        "get_entry_photos_page",
        EntryPhotosPage.serializer(),
        buildJsonObject {
            put("p_inspection_item_id", inspectionItemId.toString())
            if (afterCreatedAt != null && afterId != null) {
                put("p_after_created_at", afterCreatedAt)
                put("p_after_id", afterId)
            } else {
                put("p_after_created_at", JsonNull)
                put("p_after_id", JsonNull)
            }
            put("p_limit", limit)
        },
    )

    /** One summary per rental of the caller (rooms, documented rooms, newest evidence) — never a snapshot per rental. */
    suspend fun fetchVaultSummaries(): List<VaultSummary> =
        postgrest.rpc("get_vault_summaries", ListSerializer(VaultSummary.serializer()))

    suspend fun fetchProperties(userId: UUID): List<PropertyRow> =
        postgrest.select("properties") {
            eq("user_id", userId.toString())
            // Oldest-first preserves `fetched.first()`'s "earliest property" default selection; the cap keeps a
            // long-time user's property history from growing into an unbounded list.
            order("created_at")
            order("id")
            limit(MAX_PROPERTIES)
        }

    suspend fun fetchRooms(propertyId: UUID): List<RoomRow> =
        postgrest.select("rooms") {
            eq("property_id", propertyId.toString())
            order("sort_order")
            order("id")
            limit(MAX_ROOMS)
        }

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
        return postgrest.insertReturning<PropertyRow, PropertyRow>("properties", row).single()
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
        postgrest.insert("rooms", rooms)
    }

    suspend fun insertRoom(propertyId: UUID, name: String, sortOrder: Int): RoomRow {
        val row = RoomRow(
            id = UUID.randomUUID().toString(),
            propertyId = propertyId.toString(),
            name = name,
            sortOrder = sortOrder,
        )
        return postgrest.insertReturning<RoomRow, RoomRow>("rooms", row).single()
    }
}
