package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

@Composable
fun MMVaultProofHeroCard(
    propertyName: String,
    location: String?,
    phaseLabel: String,
    progressLine: String,
    nextLine: String,
    progress: Float,
    primaryTitle: String,
    onPrimary: () -> Unit,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    previewImage: ImageBitmap? = null,
    roomName: String? = null,
    photoCount: Int = 0,
    issueCount: Int = 0,
) {
    val clamped = progress.coerceIn(0f, 1f)
    val hasProof = clamped > 0f || previewImage != null
    val progressWidth by animateFloatAsState(
        targetValue = clamped,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 360),
        label = "vaultProgress",
    )
    val statusLabel = when {
        clamped >= 1f -> "All rooms ready"
        hasProof -> "In progress"
        else -> "Needs photos"
    }
    val statusTone = if (hasProof) MMProofStatusTone.Success else MMProofStatusTone.Warning

    Column(modifier = modifier) {
        if (hasProof && previewImage != null) {
            MMProofArtifactCard(
                model = MMProofArtifactModel(
                    phaseEyebrow = "Room Proof",
                    phaseLabel = phaseLabel,
                    roomName = roomName ?: propertyName,
                    photoCount = photoCount.coerceAtLeast(1),
                    issueCount = issueCount,
                    verifiedLabel = progressLine,
                    savedLabel = "Saved to vault",
                    statusLabel = statusLabel,
                    statusTone = statusTone,
                ),
                imageBitmap = previewImage,
                photoHeight = 140.dp,
                cornerRadius = 20.dp,
                reduceMotion = reduceMotion,
            )
            Spacer(Modifier.height(14.dp))
        } else {
            MMProofTaskCard(
                title = if (roomName != null) "Start with $roomName" else "Start move-in proof",
                reason = nextLine,
                onClick = onPrimary,
                statusLabel = statusLabel,
                statusTone = statusTone,
                showChevron = false,
            )
            Spacer(Modifier.height(12.dp))
            MMButton(text = primaryTitle, onClick = onPrimary)
            Spacer(Modifier.height(14.dp))
        }

        if (!location.isNullOrBlank()) {
            Text(location, fontSize = 13.sp, color = MMColors.TextMuted)
            Spacer(Modifier.height(4.dp))
        }
        if (hasProof) {
            Text(nextLine, fontSize = 13.sp, color = MMColors.TextSecondary)
            Spacer(Modifier.height(10.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MMColors.FieldFill.copy(alpha = 0.85f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progressWidth.coerceAtLeast(0.04f))
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(MMColors.Primary.copy(alpha = if (hasProof) 0.9f else 0.35f)),
                )
            }
            Spacer(Modifier.height(14.dp))
            MMButton(text = primaryTitle, onClick = onPrimary)
        }
    }
}
