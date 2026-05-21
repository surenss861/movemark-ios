package com.surensureshkumar.movemark.data.property

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class InspectionInsertRow(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("inspection_type") val inspectionType: String,
)
