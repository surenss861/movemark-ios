package com.surensureshkumar.movemark.features.welcome

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors

/*
 * Welcome-only (iOS WelcomeHero / WelcomeGrade): the Proof Aperture. The room is full-bleed and graded down; inside
 * one soft-edged frame the same photograph shows through in true colour, so what MoveMark records reads as the room
 * as it really was. Same poster, grade, veil and caption as iOS. Android uses the still poster rather than the video:
 * two images and a mask, no media library, no continuous effect. One reveal, then static; Reduce Motion skips it.
 */

private val HeroInk = Color(0xFF161817)
private const val FEATHER_DP = 16f

/** Keeps 40% of the chroma (iOS: a 0.6 neutral grade). */
private val Grade = ColorMatrix().apply { setToSaturation(0.4f) }

@Composable
fun WelcomeBackdrop(aperture: Rect?, reveal: Float, modifier: Modifier = Modifier) {
    val poster = painterResource(R.drawable.welcome_background_poster)
    Box(modifier.fillMaxSize()) {
        Image(
            painter = poster,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            colorFilter = ColorFilter.colorMatrix(Grade),
            modifier = Modifier.fillMaxSize(),
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to HeroInk.copy(alpha = 0.34f),
                    0.12f to HeroInk.copy(alpha = 0.14f),
                    0.22f to HeroInk.copy(alpha = 0.30f),
                    0.34f to HeroInk.copy(alpha = 0.44f),
                    0.52f to HeroInk.copy(alpha = 0.54f),
                    0.68f to HeroInk.copy(alpha = 0.70f),
                    0.84f to HeroInk.copy(alpha = 0.84f),
                    1f to HeroInk.copy(alpha = 0.92f),
                ),
            ),
        )
        if (aperture != null && reveal > 0.01f) {
            Image(
                painter = poster,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        compositingStrategy = CompositingStrategy.Offscreen
                        alpha = 0.78f * reveal
                    }
                    .drawWithContent {
                        val f = FEATHER_DP.dp.toPx()
                        // Only the aperture and its feather are ever visible, so nothing else is rasterised.
                        clipRect(aperture.left - f, aperture.top - f, aperture.right + f, aperture.bottom + f) {
                            this@drawWithContent.drawContent()
                            // The product of two gradients is a soft-edged rectangle.
                            drawRect(softBand(aperture.left, aperture.right, f, size.width, horizontal = true), blendMode = BlendMode.DstIn)
                            drawRect(softBand(aperture.top, aperture.bottom, f, size.height, horizontal = false), blendMode = BlendMode.DstIn)
                        }
                    },
            )
        }
    }
}

private fun softBand(start: Float, end: Float, feather: Float, length: Float, horizontal: Boolean): Brush {
    fun at(v: Float) = (v / length).coerceIn(0f, 1f)
    val stops = arrayOf(
        at(start - feather) to Color.Transparent,
        at(start + feather) to Color.Black,
        at(end - feather) to Color.Black,
        at(end + feather) to Color.Transparent,
    )
    return if (horizontal) Brush.horizontalGradient(*stops) else Brush.verticalGradient(*stops)
}

/** Four fine registration marks at the corners of the aperture. */
@Composable
fun ApertureMarks(modifier: Modifier = Modifier, alpha: Float) {
    Canvas(modifier) {
        val l = 12.dp.toPx()
        val w = 1.dp.toPx()
        val c = Color.White.copy(alpha = 0.85f * alpha)
        listOf(
            Triple(Offset(0f, 0f), 1f, 1f),
            Triple(Offset(size.width, 0f), -1f, 1f),
            Triple(Offset(0f, size.height), 1f, -1f),
            Triple(Offset(size.width, size.height), -1f, -1f),
        ).forEach { (p, dx, dy) ->
            drawLine(c, p, Offset(p.x + l * dx, p.y), strokeWidth = w)
            drawLine(c, p, Offset(p.x, p.y + l * dy), strokeWidth = w)
        }
    }
}

@Composable
fun ApertureCaption(modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(
            "01 — MOVE-IN",
            fontSize = 10.5.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.4.sp,
            color = Color.White.copy(alpha = 0.82f),
        )
        Text(
            "Before anything changes.",
            fontSize = 15.sp,
            lineHeight = 19.sp,
            fontFamily = FontFamily.Serif,
            fontStyle = FontStyle.Italic,
            color = Color.White.copy(alpha = 0.94f),
            modifier = Modifier.padding(top = 5.dp),
        )
    }
}
