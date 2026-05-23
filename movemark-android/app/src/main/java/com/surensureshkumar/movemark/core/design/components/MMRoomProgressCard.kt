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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

@Composable
fun MMRoomProgressCard(
    headline: String,
    nextLine: String,
    progress: Float,
    primaryTitle: String,
    onPrimary: () -> Unit,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    progressLabel: String? = null,
) {
    val clamped = progress.coerceIn(0f, 1f)
    val progressWidth by animateFloatAsState(
        targetValue = clamped,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 360),
        label = "roomProgress",
    )

    MMProofCard(modifier = modifier) {
        Column(Modifier.padding(16.dp)) {
            Text("Room proof", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextMuted)
            Spacer(Modifier.height(4.dp))
            Text(headline, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary)
            Spacer(Modifier.height(4.dp))
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
                        .fillMaxWidth(progressWidth.coerceAtLeast(if (clamped > 0f) 0.04f else 0f))
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(MMColors.Primary.copy(alpha = 0.88f)),
                )
            }
            if (!progressLabel.isNullOrBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(progressLabel, fontSize = 12.sp, color = MMColors.TextMuted)
            }
            Spacer(Modifier.height(12.dp))
            MMButton(text = primaryTitle, onClick = onPrimary)
        }
    }
}
