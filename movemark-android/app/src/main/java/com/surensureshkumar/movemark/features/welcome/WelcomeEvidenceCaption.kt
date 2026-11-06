package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

/*
 * Welcome-only (iOS WelcomeEvidenceCaption, archive direction): the kitchen photograph is the hero and the example
 * record is an archival caption set beneath it (a ruled index margin, tracked index line, serif room name, the
 * date and photo count, and a plain "illustrative" note). It replaces the damage-claim / saved-proof card stack.
 * No card, no stamp, no status icons; lime stays reserved for the one action below.
 */

@Composable
fun WelcomeEvidenceCaption(
    captionVisible: Boolean,
    reduceMotion: Boolean,
    compact: Boolean,
    modifier: Modifier = Modifier,
    drawableResId: Int = R.drawable.welcome_kitchen_main,
) {
    val captionAlpha by animateFloatAsState(
        if (captionVisible) 1f else 0f,
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 340),
        label = "captionAlpha",
    )
    val captionOffsetY by animateFloatAsState(
        if (captionVisible) 0f else 6f,
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 340),
        label = "captionOffset",
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("welcome.exampleRecord")
            .clearAndSetSemantics {
                contentDescription = "Example record: Kitchen, April 14, 12 photos. An illustration, not your evidence."
            },
    ) {
        // Graded down like the iOS footage (less chroma, less brightness, a foot that falls into the background), so
        // the photograph supports the record and the actions instead of leading the page. Shorter on small screens.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(if (compact) 2.8f else 1.9f)
                .clip(RoundedCornerShape(4.dp)),
        ) {
            Image(
                painter = painterResource(drawableResId),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                colorFilter = ColorFilter.colorMatrix(PhotoGrade),
                modifier = Modifier.matchParentSize(),
            )
            Box(
                Modifier.matchParentSize().background(
                    Brush.verticalGradient(
                        0f to MMColors.AppBackground.copy(alpha = 0.10f),
                        0.55f to MMColors.AppBackground.copy(alpha = 0.25f),
                        1f to MMColors.AppBackground.copy(alpha = 0.78f),
                    ),
                ),
            )
        }

        Row(
            modifier = Modifier
                .padding(top = 14.dp)
                .height(IntrinsicSize.Min)
                .alpha(captionAlpha)
                .offset(y = captionOffsetY.dp),
        ) {
            val rule = Color.White.copy(alpha = 0.42f)
            Canvas(Modifier.width(9.dp).fillMaxHeight()) {
                val top = 2.dp.toPx()
                val bottom = size.height - 2.dp.toPx()
                drawLine(rule, Offset(0f, top), Offset(0f, bottom), strokeWidth = 1.dp.toPx())
                listOf(top, (top + bottom) / 2, bottom).forEachIndexed { i, y ->
                    drawLine(rule, Offset(0f, y), Offset(if (i == 0) size.width else size.width * 0.55f, y), strokeWidth = 1.dp.toPx())
                }
            }
            Spacer(Modifier.width(14.dp))
            Column {
                Text(
                    "01 / EXAMPLE RECORD",
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 1.3.sp,
                    color = MMColors.TextSecondary,
                )
                Text(
                    "Kitchen",
                    fontSize = if (compact) 24.sp else 27.sp,
                    fontFamily = FontFamily.Serif,
                    color = MMColors.TextPrimary,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    "Apr 14 · 12 photos",
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextPrimary.copy(alpha = 0.78f),
                )
            }
        }
    }
}

/** Saturation 0.6 and brightness 0.78: the staged kitchen calmed toward the iOS footage's grade. */
private val PhotoGrade = ColorMatrix().apply {
    setToSaturation(0.6f)
    val k = 0.78f
    timesAssign(ColorMatrix(floatArrayOf(k, 0f, 0f, 0f, 0f, 0f, k, 0f, 0f, 0f, 0f, 0f, k, 0f, 0f, 0f, 0f, 0f, 1f, 0f)))
}
