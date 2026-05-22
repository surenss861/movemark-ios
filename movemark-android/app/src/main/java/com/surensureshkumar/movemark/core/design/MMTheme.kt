package com.surensureshkumar.movemark.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

private val MoveMarkColorScheme = darkColorScheme(
    primary = MMColors.Primary,
    onPrimary = Color.White,
    background = MMColors.AppBackground,
    onBackground = MMColors.TextPrimary,
    surface = MMColors.Surface,
    onSurface = MMColors.TextPrimary,
    error = MMColors.SemanticDanger,
)

object MMSpacing {
    const val ScreenHorizontal = 22
    const val CardStack = 16
    const val CornerRadius = 22
    const val ButtonHeight = 58
    /** Scroll content clearance above native tab bar. */
    const val TabScrollBottom = 40
}

@Composable
fun MMTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MoveMarkColorScheme,
        typography = MMTypography,
        content = content,
    )
}

@Composable
fun MMBackground(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MMColors.AppBackground),
        content = { content() },
    )
}
