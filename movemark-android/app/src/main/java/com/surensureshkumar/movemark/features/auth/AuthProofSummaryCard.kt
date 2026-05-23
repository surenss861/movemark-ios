package com.surensureshkumar.movemark.features.auth

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.components.MMProofArtifactCard
import com.surensureshkumar.movemark.core.design.components.MMProofArtifactModel
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone

@Composable
fun AuthProofSummaryCard(
    mode: AuthMode,
    modifier: Modifier = Modifier,
) {
    val statusLabel = if (mode == AuthMode.SignIn) {
        "Sign in to save proof"
    } else {
        "Create account to save proof"
    }
    val metaLine = if (mode == AuthMode.SignIn) {
        "Your move-in photos stay in your vault."
    } else {
        "Start with one room — add more anytime."
    }

    MMProofArtifactCard(
        model = MMProofArtifactModel(
            phaseEyebrow = "Room Proof",
            phaseLabel = "Move-in",
            roomName = "Kitchen proof",
            photoCount = 2,
            issueCount = 1,
            verifiedLabel = metaLine,
            savedLabel = statusLabel,
            statusLabel = statusLabel,
            statusTone = MMProofStatusTone.Success,
        ),
        drawableResId = R.drawable.welcome_kitchen_main,
        photoHeight = 120.dp,
        cornerRadius = 18.dp,
        tagsVisible = false,
        modifier = modifier,
    )
}
