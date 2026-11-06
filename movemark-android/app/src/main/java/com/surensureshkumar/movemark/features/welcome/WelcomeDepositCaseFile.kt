package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMMotion

/**
 * Welcome hero: the kitchen photograph with its archival example caption (WelcomeEvidenceCaption).
 */
@Composable
fun WelcomeDepositCaseFile(
    cardVisible: Boolean,
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    /** Short screens: the photo crops wider and the caption drops its separate "illustrative" line. */
    compact: Boolean = false,
) {
    val cardAlpha by animateFloatAsState(
        targetValue = if (cardVisible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardAlpha",
    )
    val cardOffsetY by animateFloatAsState(
        targetValue = if (cardVisible) 0f else 14f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardOffset",
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .alpha(cardAlpha)
            .offset(y = cardOffsetY.dp)
            .padding(top = 8.dp),
    ) {
        WelcomeEvidenceCaption(
            captionVisible = tagsVisible,
            reduceMotion = reduceMotion,
            compact = compact,
        )
    }
}
