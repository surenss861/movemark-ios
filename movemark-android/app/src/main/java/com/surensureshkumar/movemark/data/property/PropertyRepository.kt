package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.RoomRow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
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

    suspend fun fetchProperties(userId: UUID): List<PropertyRow> =
        client.from("properties")
            .select {
                filter { eq("user_id", userId.toString()) }
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
        client.from("rooms").insert(rooms)
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
