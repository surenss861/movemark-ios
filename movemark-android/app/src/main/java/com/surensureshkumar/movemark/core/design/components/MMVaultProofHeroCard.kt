package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
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
    previewImageUrl: String? = null,
) {
    val clamped = progress.coerceIn(0f, 1f)
    val progressWidth by animateFloatAsState(
        targetValue = clamped,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 360),
        label = "vaultProgress",
    )

    MMProofCard(modifier = modifier) {
        Row(verticalAlignment = Alignment.Top) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MMColors.FieldFill)
                    .border(1.dp, MMColors.CardStroke, RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center,
            ) {
                if (!previewImageUrl.isNullOrBlank()) {
                    AsyncImage(
                        model = previewImageUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(14.dp)),
                    )
                } else {
                    Icon(
                        Icons.Default.PhotoCamera,
                        contentDescription = null,
                        tint = MMColors.TextMuted.copy(alpha = 0.7f),
                        modifier = Modifier.size(26.dp),
                    )
                }
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    propertyName,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.TextPrimary,
                )
                if (!location.isNullOrBlank()) {
                    Text(
                        location,
                        fontSize = 13.sp,
                        color = MMColors.TextMuted,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
                Text(
                    phaseLabel,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.Primary.copy(alpha = 0.9f),
                    modifier = Modifier.padding(top = 6.dp),
                )
                Text(
                    progressLine,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextSecondary,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    nextLine,
                    fontSize = 13.sp,
                    color = MMColors.TextMuted,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
        Spacer(Modifier.height(14.dp))
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
                    .background(
                        MMColors.Primary.copy(alpha = if (clamped > 0f) 0.9f else 0.35f),
                    ),
            )
        }
        Spacer(Modifier.height(14.dp))
        MMButton(text = primaryTitle, onClick = onPrimary)
    }
}
