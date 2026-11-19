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
    // ONE light system (owner, 2026-11-18): every legacy dark token now resolves to the light palette, so screens
    // still drawn with these names turn light without a per-screen port. The only dark surface left in the app is the
    // full-screen photo viewer backdrop (MMInk.Evidence).
    val AppBackground = Color(0xFFF8F8F8)        // = MMInk.Sheet
    val AppBackgroundRaised = Color(0xFFFFFFFF)
    val Surface = Color(0xFFFFFFFF)
    val Card = Color(0xFFFFFFFF)
    val CardRaised = Color(0xFFFFFFFF)
    val SurfaceRaised = Color(0xFFFFFFFF)
    val SurfaceInteractive = Color(0xFFF3F3F2)   // = MMInk.Field
    val EvidenceCard = Color(0xFFFFFFFF)
    val EvidenceCardRaised = Color(0xFFFFFFFF)
    val TabBarFill = Color(0xF0161817)           // the floating dock stays the dark pill
    val Primary = Color(0xFFCAE36C)              // = MMInk.Lime: primary buttons and progress only
    val ActionPrimary = Color(0xFFCAE36C)
    val OnActionPrimary = Color(0xFF111608)
    val PrimaryPressed = Color(0xFFB5CE58)
    val TextPrimary = Color(0xFF141415)          // = MMInk.Text
    val TextSecondary = Color(0xFF6D6E6F)        // = MMInk.Secondary (AA on off-white)
    val TextMuted = Color(0xFF6D6E6F)
    val SemanticWarning = Color(0xFF8F6112)      // warning text on light (unslop audit pair)
    val SemanticInfo = Color(0xFF2F6F9F)
    val SemanticDanger = Color(0xFFC63E34)       // = MMInk.Danger
    val CardStroke = Color(0xFFECECEC)           // = MMInk.CardStroke
    val FieldFill = Color(0xFFF3F3F2)            // = MMInk.Field
    val PaperSurface = Color(0xFFF2F2F0)         // = MMInk.Paper
}
