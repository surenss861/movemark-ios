package com.surensureshkumar.movemark.features.proof

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.domain.ProofPhase

@Composable
fun RoomProofCaptureHero(
    roomName: String,
    proofPhase: ProofPhase,
    modifier: Modifier = Modifier,
) {
    val subtitle = if (proofPhase == ProofPhase.MoveOut) {
        "Save move-out proof before handing back keys."
    } else {
        "Save move-in proof before anything changes."
    }
    MMProofSectionHeader(
        title = "Capture $roomName",
        subtitle = subtitle,
        modifier = modifier,
    )
}
