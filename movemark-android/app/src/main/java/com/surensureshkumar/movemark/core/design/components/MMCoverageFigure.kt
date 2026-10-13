package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

@Composable
fun MMCoverageFigure(
    documented: Int,
    total: Int,
    modifier: Modifier = Modifier,
    kicker: String = "Move-in coverage",
    caption: String = "Rooms documented",
) {
    Column(
        modifier.semantics {
            contentDescription = "$kicker, $documented of $total ${caption.lowercase()}"
        },
    ) {
        Text(
            kicker.uppercase(),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.1.sp,
            color = MMColors.TextMuted,
        )
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                "%02d".format(documented),
                fontFamily = FontFamily.Serif,
                fontSize = 44.sp,
                color = MMColors.TextPrimary,
            )
            Text(
                "/",
                fontFamily = FontFamily.Serif,
                fontSize = 28.sp,
                color = MMColors.TextMuted,
                modifier = Modifier.padding(start = 6.dp, end = 6.dp, bottom = 6.dp),
            )
            Text(
                "%02d".format(total),
                fontFamily = FontFamily.Serif,
                fontSize = 44.sp,
                color = MMColors.TextSecondary.copy(alpha = 0.72f),
            )
        }
        Text(
            caption.uppercase(),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.9.sp,
            color = MMColors.TextMuted,
        )
    }
}

@Composable
fun MMCoverageRing(
    progress: Float,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 68.dp,
) {
    val clamped = progress.coerceIn(0f, 1f)
    val animated by animateFloatAsState(
        targetValue = clamped,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 420),
        label = "coverageRing",
    )
    Canvas(modifier.size(size)) {
        val stroke = Stroke(width = 3.5.dp.toPx(), cap = StrokeCap.Round)
        drawArc(
            color = Color.White.copy(alpha = 0.08f),
            startAngle = 0f,
            sweepAngle = 360f,
            useCenter = false,
            style = stroke,
        )
        if (animated > 0f) {
            drawArc(
                color = MMColors.Primary,
                startAngle = -90f,
                sweepAngle = 360f * animated,
                useCenter = false,
                style = stroke,
            )
        }
    }
}
