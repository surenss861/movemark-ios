package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

@Composable
fun MMProofDocumentPreview(
    modifier: Modifier = Modifier,
    large: Boolean = true,
    isBright: Boolean = true,
    isProcessing: Boolean = false,
    reduceMotion: Boolean = false,
) {
    val pulseAlpha = if (isProcessing && !reduceMotion) {
        val transition = rememberInfiniteTransition(label = "docPulse")
        transition.animateFloat(
            initialValue = 0.88f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
            label = "docPulseAlpha",
        ).value
    } else {
        1f
    }

    if (large) {
        Box(modifier.alpha(pulseAlpha)) {
            Box(Modifier.size(width = 88.dp, height = 116.dp).then(modifier)) {
                Box(
                    Modifier
                        .size(58.dp, 88.dp)
                        .offset(x = 10.dp, y = 8.dp)
                        .rotate(5f)
                        .background(MMColors.EvidenceCard.copy(0.9f), RoundedCornerShape(10.dp)),
                )
                Box(
                    Modifier
                        .size(60.dp, 92.dp)
                        .offset(x = 5.dp, y = 4.dp)
                        .rotate(2.5f)
                        .background(MMColors.EvidenceCard.copy(0.95f), RoundedCornerShape(12.dp)),
                )
                DocumentSheet(isBright = isBright, width = 72.dp, height = 108.dp, radius = 14.dp, pad = 12.dp, compact = false)
            }
        }
    } else {
        DocumentSheet(
            modifier = modifier.alpha(pulseAlpha),
            isBright = isBright,
            width = 52.dp,
            height = 68.dp,
            radius = 10.dp,
            pad = 8.dp,
            compact = true,
        )
    }
}

@Composable
private fun DocumentSheet(
    modifier: Modifier = Modifier,
    isBright: Boolean,
    width: androidx.compose.ui.unit.Dp,
    height: androidx.compose.ui.unit.Dp,
    radius: androidx.compose.ui.unit.Dp,
    pad: androidx.compose.ui.unit.Dp,
    compact: Boolean,
) {
    Box(
        modifier
            .size(width, height)
            .background(MMColors.PaperSurface.copy(if (isBright) 0.98f else 0.9f), RoundedCornerShape(radius))
            .padding(pad),
    ) {
        Column(Modifier.size(width - pad * 2, height - pad * 2)) {
            Box(
                Modifier
                    .width(if (compact) 28.dp else 36.dp)
                    .height(if (compact) 4.dp else 5.dp)
                    .background(
                        if (isBright) MMColors.Primary.copy(0.85f) else MMColors.SemanticWarning.copy(0.75f),
                        RoundedCornerShape(2.dp),
                    ),
            )
            Spacer(Modifier.height(if (compact) 5.dp else 6.dp))
            repeat(if (compact) 2 else 3) {
                Box(
                    Modifier
                        .padding(bottom = if (compact) 3.dp else 4.dp)
                        .width(if (compact) 32.dp else if (it == 0) 44.dp else 40.dp)
                        .height(if (compact) 3.dp else 4.dp)
                        .background(Color.Black.copy(0.08f), RoundedCornerShape(2.dp)),
                )
            }
            Spacer(Modifier.weight(1f))
            Text(
                "PDF",
                color = when {
                    compact -> MMColors.TextMuted
                    isBright -> MMColors.PrimaryPressed
                    else -> Color.Black.copy(0.55f)
                },
                fontSize = if (compact) 9.sp else 10.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}
