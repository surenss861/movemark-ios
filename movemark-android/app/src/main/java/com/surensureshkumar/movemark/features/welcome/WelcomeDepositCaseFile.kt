package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.components.MMProofArtifactCard
import com.surensureshkumar.movemark.core.design.components.MMProofArtifactModel
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone

private val WelcomeArtifact = MMProofArtifactModel(
    phaseEyebrow = "Room Proof",
    phaseLabel = "Move-in",
    roomName = "Kitchen",
    photoCount = 12,
    issueCount = 3,
    verifiedLabel = "Verified Apr 14 · 5:42 PM",
    savedLabel = "Saved to vault",
    statusLabel = "Ready",
    statusTone = MMProofStatusTone.Success,
    issueTags = listOf("Already there", "Chipped paint"),
)

/**
 * Welcome hero — layered proof artifact with report peek behind the card.
 */
@Composable
fun WelcomeDepositCaseFile(
    cardVisible: Boolean,
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val cardAlpha by animateFloatAsState(
        targetValue = if (cardVisible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardAlpha",
    )
    val cardOffsetY by animateFloatAsState(
        targetValue = if (cardVisible) 0f else 14f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardOffset",
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .alpha(cardAlpha)
            .offset(y = cardOffsetY.dp)
            .padding(top = 8.dp),
    ) {
        MMProofArtifactCard(
            model = WelcomeArtifact,
            drawableResId = R.drawable.welcome_kitchen_main,
            photoHeight = 180.dp,
            cornerRadius = 20.dp,
            showReportPeek = true,
            tagsVisible = tagsVisible,
            reduceMotion = reduceMotion,
        )
    }
}
