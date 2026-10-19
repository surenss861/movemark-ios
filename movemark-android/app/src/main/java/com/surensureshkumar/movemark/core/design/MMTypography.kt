/**
 * @file Android type scale (sans / serif / mono voices)
 * @domain design-system
 * @status stable
 * @see [[VISUAL_STANDARD]] — rules these tokens implement
 * @see [[MoveMarkTheme.swift]] — iOS reference tokens
 */
package com.surensureshkumar.movemark.core.design

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val MMTypography = Typography(
    displayLarge = TextStyle(fontSize = 36.sp, fontWeight = FontWeight.Bold, color = MMColors.TextPrimary),
    headlineLarge = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Bold, color = MMColors.TextPrimary),
    headlineMedium = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary),
    titleMedium = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary),
    bodyLarge = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Normal, color = MMColors.TextPrimary),
    bodyMedium = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Normal, color = MMColors.TextSecondary),
    labelLarge = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary),
    labelMedium = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MMColors.TextMuted),
    labelSmall = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MMColors.TextMuted),
)
