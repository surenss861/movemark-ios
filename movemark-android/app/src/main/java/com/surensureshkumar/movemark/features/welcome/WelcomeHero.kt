package com.surensureshkumar.movemark.features.welcome

import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMEyebrowStyle
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.mmFont

/*
 * Welcome-only: the move-in visual. One light system (owner, 2026-11-18): no full-screen photo behind text or
 * buttons. The poster (an empty room, boxes still packed) sits in one properly sized rounded image card on the light
 * page, with its caption beneath it on the page, never over the photograph. Read by TalkBack as one line.
 */

/** Keeps the packed boxes and the doorway in frame when the portrait poster is cropped to a landscape card. */
private val PosterFocus = BiasAlignment(horizontalBias = -0.15f, verticalBias = 0.35f)

@Composable
fun WelcomeProofCard(compact: Boolean, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(MMMetrics.CardRadius)
    Column(
        modifier
            .fillMaxWidth()
            .testTag("welcome.aperture")
            .clearAndSetSemantics { contentDescription = "Move-in: before anything changes." },
    ) {
        Image(
            painter = painterResource(R.drawable.welcome_background_poster),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alignment = PosterFocus,
            modifier = Modifier
                .fillMaxWidth()
                .height(if (compact) 150.dp else 200.dp)
                .clip(shape)
                .border(0.75.dp, MMInk.CardStroke, shape),
        )
        ApertureCaption(Modifier.padding(top = 12.dp))
    }
}

@Composable
fun ApertureCaption(modifier: Modifier = Modifier) {
    Column(modifier) {
        Text("01 — MOVE-IN", style = MMEyebrowStyle, color = MMInk.Secondary)
        Text(
            "Before anything changes.",
            style = mmFont(15f, FontWeight.Medium),
            color = MMInk.Text,
            modifier = Modifier.padding(top = 3.dp),
        )
    }
}
