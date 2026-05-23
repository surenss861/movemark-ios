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
import com.surensureshkumar.movemark.domain.ProofPhase

@Composable
fun RoomProofCaptureHero(
    roomName: String,
    proofPhase: ProofPhase,
    statusLine: String,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            if (proofPhase == ProofPhase.MoveOut) "MOVE-OUT PROOF" else "MOVE-IN PROOF",
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.8.sp,
            color = MMColors.TextMuted,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            roomName,
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextPrimary,
        )
        Spacer(Modifier.height(6.dp))
        Text(statusLine, color = MMColors.TextSecondary, fontSize = 14.sp)
    }
}
