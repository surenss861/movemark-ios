package com.surensureshkumar.movemark.data.property

import java.util.UUID

data class EvidenceUploadContext(
    val inspectionItemId: UUID,
    val roomId: UUID,
    val title: String,
    val propertyId: UUID,
    val userId: UUID,
)
