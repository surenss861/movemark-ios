package com.surensureshkumar.movemark.core.design

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalDensity

/** System font scale at which single-line labels wrap instead of truncating (130% and up). */
const val LARGE_FONT_SCALE = 1.3f

/**
 * Lines for a label that is one line at normal sizes: unlimited at large font scales, so 200% text wraps
 * instead of cutting off the renter's own words (room names, notes, values).
 */
@Composable
fun mmLines(normal: Int = 1): Int = if (LocalDensity.current.fontScale >= LARGE_FONT_SCALE) Int.MAX_VALUE else normal
