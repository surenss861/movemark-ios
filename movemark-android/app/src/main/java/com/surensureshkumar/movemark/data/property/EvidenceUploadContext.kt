package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.domain.ProofPhase
import java.util.UUID

data class EvidenceUploadContext(
    val inspectionItemId: UUID,
    val roomId: UUID,
    val title: String,
    val propertyId: UUID,
    val userId: UUID,
    val proofPhase: ProofPhase,
    /** Linked after the photos save (best-effort, as on iOS). */
    val issueTags: List<String> = emptyList(),
)
