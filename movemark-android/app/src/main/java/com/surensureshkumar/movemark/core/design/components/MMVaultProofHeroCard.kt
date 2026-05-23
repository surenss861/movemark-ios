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
) {
    val clamped = progress.coerceIn(0f, 1f)
    val hasProof = clamped > 0f
    val progressWidth by animateFloatAsState(
        targetValue = clamped,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 360),
        label = "vaultProgress",
    )
    val statusLabel = when {
        clamped >= 1f -> "All rooms ready"
        hasProof -> progressLine
        else -> "Needs photos"
    }
    val statusTone = if (hasProof) MMProofStatusTone.Success else MMProofStatusTone.Warning
    val accentRail = if (hasProof) MMProofCaseAccentRail.Saved else MMProofCaseAccentRail.NeedsProof

    MMProofCaseCard(
        modifier = modifier,
        cornerRadius = 22.dp,
        header = MMProofCaseHeader(
            eyebrow = phaseLabel,
            statusLabel = statusLabel,
            statusTone = statusTone,
            accentRail = accentRail,
        ),
        contentPadding = 16.dp,
    ) {
        if (hasProof || previewImage != null) {
            MMProofPhotoPane(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .clip(RoundedCornerShape(14.dp)),
                size = MMProofPhotoPaneSize.Medium,
                imageBitmap = previewImage,
                roomName = propertyName,
                phaseLabel = progressLine,
            )
            Spacer(Modifier.height(14.dp))
        } else {
            MMProofPhotoPane(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp)
                    .clip(RoundedCornerShape(14.dp)),
                size = MMProofPhotoPaneSize.Medium,
            )
            Spacer(Modifier.height(14.dp))
        }

        if (!location.isNullOrBlank()) {
            Text(location, fontSize = 13.sp, color = MMColors.TextMuted)
            Spacer(Modifier.height(4.dp))
        }
        Text(nextLine, fontSize = 13.sp, color = MMColors.TextSecondary)
        Spacer(Modifier.height(12.dp))
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
