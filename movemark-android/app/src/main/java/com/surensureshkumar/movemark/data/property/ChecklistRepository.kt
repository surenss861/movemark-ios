package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.PostgrestClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/** One rental's move-out closeout checklist (`move_out_checklists`, one row per property and user; iOS `MoveOutChecklistRow`). */
@Serializable
data class MoveOutChecklistRow(
    val id: String? = null,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("cabinets_clear") val cabinetsClear: Boolean = false,
    @SerialName("appliances_clean") val appliancesClean: Boolean = false,
    @SerialName("keys_returned") val keysReturned: Boolean = false,
    @SerialName("utilities_cancelled") val utilitiesCancelled: Boolean = false,
    @SerialName("cleaning_receipt_uploaded") val cleaningReceiptUploaded: Boolean = false,
    @SerialName("forwarding_address_noted") val forwardingAddressNoted: Boolean = false,
) {
    enum class Item(val title: String) {
        CabinetsClear("Cabinets cleared"),
        AppliancesClean("Appliances cleaned"),
        KeysReturned("Keys returned"),
        UtilitiesCancelled("Utilities cancelled"),
        CleaningReceipt("Cleaning receipt saved"),
        ForwardingAddress("Forwarding address noted"),
    }

    fun isDone(item: Item): Boolean = when (item) {
        Item.CabinetsClear -> cabinetsClear
        Item.AppliancesClean -> appliancesClean
        Item.KeysReturned -> keysReturned
        Item.UtilitiesCancelled -> utilitiesCancelled
        Item.CleaningReceipt -> cleaningReceiptUploaded
        Item.ForwardingAddress -> forwardingAddressNoted
    }

    fun with(item: Item, done: Boolean): MoveOutChecklistRow = when (item) {
        Item.CabinetsClear -> copy(cabinetsClear = done)
        Item.AppliancesClean -> copy(appliancesClean = done)
        Item.KeysReturned -> copy(keysReturned = done)
        Item.UtilitiesCancelled -> copy(utilitiesCancelled = done)
        Item.CleaningReceipt -> copy(cleaningReceiptUploaded = done)
        Item.ForwardingAddress -> copy(forwardingAddressNoted = done)
    }

    val completedCount: Int get() = Item.entries.count(::isDone)

    companion object {
        fun empty(propertyId: UUID, userId: UUID) =
            MoveOutChecklistRow(UUID.randomUUID().toString(), propertyId.toString(), userId.toString())
    }
}

@Singleton
class ChecklistRepository @Inject constructor(private val postgrest: PostgrestClient) {
    suspend fun fetch(propertyId: UUID, userId: UUID): MoveOutChecklistRow? =
        postgrest.select<MoveOutChecklistRow>("move_out_checklists") {
            eq("property_id", propertyId.toString())
            eq("user_id", userId.toString())
            order("id")
            limit(1)
        }.firstOrNull()

    /** One row per rental and user: a repeated save updates it. */
    suspend fun upsert(row: MoveOutChecklistRow) = postgrest.upsert("move_out_checklists", row, onConflict = "property_id,user_id")
}
