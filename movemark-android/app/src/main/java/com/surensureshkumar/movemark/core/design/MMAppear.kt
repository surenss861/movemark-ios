package com.surensureshkumar.movemark.core.design

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.offset

@Composable
fun Modifier.mmAppearRise(
    visible: Boolean,
    reduceMotion: Boolean,
    label: String = "appear",
): Modifier {
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 420),
        label = "${label}Alpha",
    )
    val offsetY by animateFloatAsState(
        targetValue = if (visible) 0f else 8f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 420),
        label = "${label}Offset",
    )
    return this
        .alpha(alpha)
        .offset(y = offsetY.dp)
}
