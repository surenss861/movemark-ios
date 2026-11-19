package com.surensureshkumar.movemark.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

/** One light scheme: native dialogs, menus, sheets and pickers come out white with ink text (owner, 2026-11-18). */
private val MoveMarkColorScheme = lightColorScheme(
    primary = MMInk.Text,
    onPrimary = Color.White,
    primaryContainer = MMInk.Lime,
    onPrimaryContainer = MMInk.OnLime,
    secondary = MMInk.Text,
    onSecondary = Color.White,
    background = MMInk.Sheet,
    onBackground = MMInk.Text,
    surface = MMInk.Card,
    onSurface = MMInk.Text,
    surfaceVariant = MMInk.Field,
    onSurfaceVariant = MMInk.Secondary,
    surfaceContainer = MMInk.Card,
    surfaceContainerHigh = MMInk.Card,
    surfaceContainerHighest = MMInk.Card,
    surfaceContainerLow = MMInk.Card,
    surfaceContainerLowest = MMInk.Card,
    outline = MMInk.CardStroke,
    outlineVariant = MMInk.Separator,
    error = MMInk.Danger,
    onError = Color.White,
)

object MMSpacing {
    const val ScreenHorizontal = 22
    const val CardStack = 16
    const val CornerRadius = 22
    const val ButtonHeight = 58
    /** Scroll content clearance above floating evidence dock. */
    const val TabScrollBottom = 168
    /** Reports tab — extra clearance for move-out/dispute cards above the dock. */
    const val ReportsTabScrollBottom = 210
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
