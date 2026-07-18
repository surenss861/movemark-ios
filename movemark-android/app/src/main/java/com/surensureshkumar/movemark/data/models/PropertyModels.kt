package com.surensureshkumar.movemark.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class PropertyRow(
    val id: String,
    @SerialName("user_id") val userId: String,
    var title: String,
    @SerialName("address_line_1") var addressLine1: String,
    @SerialName("address_line_2") var addressLine2: String? = null,
    var city: String,
    @SerialName("province_state") var provinceState: String,
    @SerialName("postal_code") var postalCode: String,
    var country: String,
    @SerialName("landlord_name") var landlordName: String? = null,
    @SerialName("landlord_email") var landlordEmail: String? = null,
    @SerialName("landlord_phone") var landlordPhone: String? = null,
    @SerialName("deposit_amount") var depositAmount: Double? = null,
    @SerialName("rent_amount") var rentAmount: Double? = null,
    @SerialName("move_in_date") var moveInDate: String? = null,
    @SerialName("lease_start") var leaseStart: String? = null,
    @SerialName("lease_end") var leaseEnd: String? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class RoomRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    var name: String,
    @SerialName("sort_order") var sortOrder: Int,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class InspectionRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("inspection_type") var inspectionType: String,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class InspectionItemRow(
    val id: String,
    @SerialName("inspection_id") val inspectionId: String,
    @SerialName("room_id") val roomId: String,
    var notes: String? = null,
    @SerialName("condition_rating") var conditionRating: Int? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

@Serializable
data class EvidenceFileRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("inspection_item_id") var inspectionItemId: String? = null,
    @SerialName("maintenance_issue_id") var maintenanceIssueId: String? = null,
    @SerialName("file_path") var filePath: String,
    @SerialName("file_type") var fileType: String,
    @SerialName("captured_at") var capturedAt: String? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

data class EvidencePhoto(
    val id: UUID,
    val filePath: String,
)

data class EvidenceRecord(
    val id: UUID,
    val title: String,
    val notes: String,
    val photoCount: Int,
    val photos: List<EvidencePhoto> = emptyList(),
    /** 1 (poor) .. 5 (excellent); matches InspectionItemRow.conditionRating. Null if never set. */
    val conditionRating: Int? = null,
)

data class RoomRecord(
    val id: UUID,
    val name: String,
    /** Move-in inspection evidence only. */
    val moveInEvidence: List<EvidenceRecord> = emptyList(),
    /** Move-out inspection evidence only — never mixed with move-in. */
    val moveOutEvidence: List<EvidenceRecord> = emptyList(),
)

data class PropertyRecord(
    val id: UUID,
    val title: String,
    val addressLine1: String,
    val city: String,
    val provinceState: String,
    val rooms: List<RoomRecord>,
)

@Serializable
data class MaintenanceIssueRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    var title: String,
    var category: String? = null,
    var description: String? = null,
    var status: String = "open",
    @SerialName("landlord_response") var landlordResponse: String? = null,
    @SerialName("date_discovered") var dateDiscovered: String? = null,
    @SerialName("date_reported") var dateReported: String? = null,
    @SerialName("follow_up_date") var followUpDate: String? = null,
    @SerialName("created_at") var createdAt: String? = null,
)

data class MaintenanceRecord(
    val id: UUID,
    val title: String,
    val category: String,
    val details: String,
    val status: String,
    val landlordResponse: String?,
    val photoCount: Int,
    val createdAt: String?,
)

data class CreatePropertyInput(
    val title: String,
    val addressLine1: String,
    val unit: String = "",
    val city: String,
    val region: String,
    val postalCode: String,
    val country: String = "CA",
    val landlordName: String = "",
    val landlordEmail: String = "",
    val landlordPhone: String = "",
    val depositAmount: String = "",
    val rentAmount: String = "",
) {
    val titleValue: String
        get() = title.trim().ifEmpty { addressLine1.trim().ifEmpty { "My rental" } }
}
