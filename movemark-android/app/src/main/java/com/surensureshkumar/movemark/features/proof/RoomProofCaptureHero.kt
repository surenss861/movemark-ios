package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.domain.ProofPhase

@Composable
fun RoomProofCaptureHero(
    roomName: String,
    proofPhase: ProofPhase,
    statusLine: String,
    modifier: Modifier = Modifier,
) {
    MMProofCard(modifier = modifier.fillMaxWidth()) {
        Text(
            if (proofPhase == ProofPhase.MoveOut) "Move-out proof" else "Move-in proof",
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.Primary.copy(alpha = 0.92f),
        )
        Spacer(Modifier.height(6.dp))
        Text(
            roomName,
            style = androidx.compose.material3.MaterialTheme.typography.headlineMedium,
            color = MMColors.TextPrimary,
        )
        Spacer(Modifier.height(8.dp))
        Text(statusLine, color = MMColors.TextSecondary, fontSize = 15.sp)
    }
}
