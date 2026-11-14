/**
 * @file Android color tokens — near-neutral surfaces; green is a signal, not a surface
 * @domain design-system
 * @status stable
 * @see [[VISUAL_STANDARD]] — material and color rules
 * @see [[MoveMarkTheme.swift]] — iOS reference tokens
 */
package com.surensureshkumar.movemark.core.design

import androidx.compose.ui.graphics.Color

/**
 * Legacy token names, now mapped onto the 1.4 system (MMInk, the iOS palette): neutral dark surfaces instead of the
 * old dark green, and lime as the one accent and primary action instead of emerald. Screens still drawn with these
 * names lose the legacy green without a per-screen port; new and ported screens use MMInk directly.
 */
object MMColors {
    val AppBackground = Color(0xFF161817)        // = MMInk.Hero (was legacy green #07120E)
    val AppBackgroundRaised = Color(0xFF1B1D1C)
    val Surface = Color(0xFF202221)
    val Card = Color(0xFF202221)
    val CardRaised = Color(0xFF262827)
    /** Near-neutral plate. Green is a signal, not a surface. */
    val SurfaceRaised = Color(0xFF121815)
    val SurfaceInteractive = Color(0xFF171D1A)
    val EvidenceCard = Color(0xFF151716)
    val EvidenceCardRaised = Color(0xFF1A1C1B)
    val TabBarFill = Color(0xF0161817)
    val Primary = Color(0xFFCAE36C)              // = MMInk.Lime (was emerald #21B866)

    /**
     * The primary action, matching iOS's lime (MMInk.lime / onLime). Used through MMButtonStyle.Action; Welcome adopts
     * it first. The app-wide move is a later token change; green stays for genuine success and saved states.
     */
    val ActionPrimary = Color(0xFFCAE36C)
    val OnActionPrimary = Color(0xFF111608)
    val PrimaryPressed = Color(0xFFB5CE58)
    val TextPrimary = Color(0xFFF2F8F1)
    val TextSecondary = Color(0xFFB4B5B6)        // neutral (was green-tinted #A8B8AD)
    val TextMuted = Color(0xFF999A9B)            // neutral, 6.3:1 on AppBackground, 5.7:1 on Card
    val SemanticWarning = Color(0xFFD89A1E)
    val SemanticInfo = Color(0xFF80BAE2)
    val SemanticDanger = Color(0xFFEF5B5B)
    val CardStroke = Color.White.copy(alpha = 0.08f)
    val FieldFill = Color(0xFF1C1E1D)
    val PaperSurface = Color(0xFFF2F2F0)         // = MMInk.Paper
}
