package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

/**
 * Single paper cover. The edge turns green only once the record is ready.
 * Matches the iOS case-file mark: MM, rules, and PDF or FILE.
 */
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
            initialValue = 1f,
            targetValue = 0.78f,
            animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
            label = "docPulseAlpha",
        ).value
    } else {
        1f
    }
    val width = if (large) 84.dp else 58.dp
    val height = if (large) 112.dp else 76.dp
    DocumentSheet(
        modifier = modifier.alpha(pulseAlpha),
        isBright = isBright,
        isProcessing = isProcessing,
        width = width,
        height = height,
        compact = !large,
    )
}

@Composable
private fun DocumentSheet(
    modifier: Modifier = Modifier,
    isBright: Boolean,
    isProcessing: Boolean,
    width: androidx.compose.ui.unit.Dp,
    height: androidx.compose.ui.unit.Dp,
    compact: Boolean,
) {
    val shape = RoundedCornerShape(6.dp)
    val edge = when {
        isBright -> MMColors.Primary
        isProcessing -> MMColors.SemanticWarning
        else -> Color.Black.copy(alpha = 0.28f)
    }
    val label = when {
        isProcessing -> "FILE"
        isBright -> "PDF"
        else -> "FILE"
    }
    Box(
        modifier
            .size(width, height)
            .clip(shape)
            .background(MMColors.PaperSurface.copy(if (isBright) 1f else 0.78f))
            .border(0.5.dp, Color.Black.copy(alpha = 0.12f), shape),
    ) {
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .width(3.dp)
                .fillMaxHeight()
                .background(edge),
        )
        Column(Modifier.fillMaxSize().padding(if (compact) 8.dp else 12.dp)) {
            Text(
                "MM",
                fontFamily = FontFamily.Monospace,
                fontSize = if (compact) 11.sp else 13.sp,
                fontWeight = FontWeight.Medium,
                color = Color.Black.copy(alpha = 0.72f),
            )
            Spacer(Modifier.height(if (compact) 5.dp else 7.dp))
            Rule(if (compact) 28.dp else 44.dp, isProcessing)
            Spacer(Modifier.height(if (compact) 4.dp else 5.dp))
            Rule(if (compact) 34.dp else 52.dp, isProcessing)
            Spacer(Modifier.height(if (compact) 4.dp else 5.dp))
            Rule(if (compact) 22.dp else 36.dp, isProcessing)
            Spacer(Modifier.weight(1f))
            Text(
                label,
                fontSize = if (compact) 9.sp else 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.6.sp,
                color = Color.Black.copy(alpha = 0.55f),
            )
        }
    }
}

@Composable
private fun Rule(width: androidx.compose.ui.unit.Dp, isProcessing: Boolean) {
    Box(
        Modifier
            .width(width)
            .height(2.dp)
            .background(
                Color.Black.copy(alpha = if (isProcessing) 0.18f else 0.28f),
                RoundedCornerShape(1.dp),
            ),
    )
}
