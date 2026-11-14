/**
 * @file The final MoveMark visual system on Android, ported from the locked iOS screens (Proof, Reports,
 *       Account): a quiet dark header over a light working sheet, grouped rows, lime only on the one primary
 *       action, calm notices. Screens outside the locked set are built from these so the product reads as one
 *       system on both platforms.
 * @domain design-system
 * @see [[MMSystem.swift]] — iOS reference (MMInk, MMMetrics, MMScreen, MMGroup, MMRow, MMPrimaryButton)
 * @see [[VISUAL_STANDARD]]
 */
package com.surensureshkumar.movemark.core.design

import android.app.Activity
import androidx.compose.foundation.Image
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Bed
import androidx.compose.material.icons.outlined.DesktopWindows
import androidx.compose.material.icons.outlined.LocalLaundryService
import androidx.compose.material.icons.outlined.MeetingRoom
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.Shower
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material.icons.outlined.Weekend
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import com.surensureshkumar.movemark.R

/** Colour tokens of the final system (iOS `MMInk`). */
object MMInk {
    val Hero = Color(0xFF161817)            // header / evidence dark
    val HeroSecondary = Color.White.copy(alpha = 0.62f)
    val Track = Color.White.copy(alpha = 0.16f)
    val Sheet = Color(0xFFF8F8F8)           // working surface
    val Card = Color.White
    val CardStroke = Color(0xFFECECEC)
    val Text = Color(0xFF141415)
    val Secondary = Color(0xFF6D6E6F)       // 5.1:1 on white, 4.8:1 on Sheet (was #7E7F80: 4.0:1 / 3.8:1)
    val Separator = Color(0xFFEAEAEB)
    val Field = Color(0xFFF3F3F2)
    val Lime = Color(0xFFCAE36C)            // the one action
    val LimeMark = Color(0xFFC1E94C)        // status signal
    val OnLime = Color(0xFF111608)
    val Danger = Color(0xFFC63E34)
    val Warning = Color(0xFFB97E19)         // amber readable on white
    val Paper = Color(0xFFF2F2F0)           // document tile
    val ThumbFill = Color(0xFFE8E8E6)
    /** Dark (evidence) surfaces. */
    val Evidence = Color(0xFF111312)
    val EvidenceRaised = Color.White.copy(alpha = 0.06f)
    val EvidenceStroke = Color.White.copy(alpha = 0.12f)
}

/** Geometry of the final system (iOS `MMMetrics`). */
object MMMetrics {
    val Inset = 20.dp
    val SheetRadius = 22.dp
    val GroupRadius = 14.dp
    val CardRadius = 16.dp
    val RowHeight = 50.dp
    val CtaHeight = 50.dp
    /** Scroll tail that clears the floating dock on a root tab (dock 54 + gap 12 + breathing room). */
    val RootTabTail = 110.dp
}

/**
 * iOS `mmFont(size, weight)`: one design size per role, in sp so it follows the system font scale. Android uses
 * its own sans (Roboto / the device font) where iOS uses SF Pro — the hierarchy, not the face, is the contract.
 */
fun mmFont(size: Float, weight: FontWeight = FontWeight.Normal, tracking: Float = 0f): TextStyle =
    TextStyle(
        fontSize = size.sp,
        fontWeight = weight,
        letterSpacing = if (tracking == 0f) TextStyle.Default.letterSpacing else tracking.sp,
    )

/** The eyebrow over a header title: 11 semibold, tracked, uppercase. */
val MMEyebrowStyle: TextStyle get() = mmFont(11f, FontWeight.SemiBold, tracking = 0.6f)

/** Light or dark navigation-bar icons while a screen with a light bottom is shown. */
@Composable
fun MMLightSystemBars(lightNavigationBar: Boolean = true, lightStatusBar: Boolean = false) {
    val view = LocalView.current
    if (view.isInEditMode) return
    DisposableEffect(lightNavigationBar, lightStatusBar) {
        val window = (view.context as? Activity)?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val prevNav = controller?.isAppearanceLightNavigationBars
        val prevStatus = controller?.isAppearanceLightStatusBars
        controller?.isAppearanceLightNavigationBars = lightNavigationBar
        controller?.isAppearanceLightStatusBars = lightStatusBar
        onDispose {
            prevNav?.let { controller.isAppearanceLightNavigationBars = it }
            prevStatus?.let { controller.isAppearanceLightStatusBars = it }
        }
    }
}

// region Wordmark

/** The compact lockup on dark headers: the mark at cap height, then "MoveMark". Read once by TalkBack. */
@Composable
fun MMWordmark(modifier: Modifier = Modifier, size: Float = 17f) {
    Row(
        modifier = modifier.semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy((size * 0.38f).dp),
    ) {
        Image(
            painter = painterResource(R.drawable.movemark_mark),
            contentDescription = null,
            modifier = Modifier.size((size * 0.86f).dp),
        )
        Text("MoveMark", style = mmFont(size, FontWeight.SemiBold), color = Color.White.copy(alpha = 0.85f))
    }
}

// endregion

// region Screen scaffold

/**
 * A screen in the system: the dark header (wordmark, eyebrow, title, optional lines and accessory) running under
 * the status bar, then the light working sheet with 22dp top corners. Root tabs pass no [onBack]; pushed screens
 * get a back arrow in the header (system back still works through the NavHost / BackHandler).
 */
@Composable
fun MMScreen(
    title: String,
    modifier: Modifier = Modifier,
    eyebrow: String? = null,
    lines: List<String> = emptyList(),
    onBack: (() -> Unit)? = null,
    showsWordmark: Boolean = onBack == null,
    tail: Dp = 32.dp,
    scrollState: ScrollState = rememberScrollState(),
    trailing: @Composable RowScope.() -> Unit = {},
    headerAccessory: (@Composable ColumnScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    MMLightSystemBars()
    Box(
        modifier
            .fillMaxSize()
            .background(MMInk.Sheet),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(scrollState),
        ) {
            MMHeader(
                title = title,
                eyebrow = eyebrow,
                lines = lines,
                onBack = onBack,
                showsWordmark = showsWordmark,
                trailing = trailing,
                accessory = headerAccessory,
            )
            MMSheet {
                content()
                Spacer(Modifier.height(tail))
                Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
            }
        }
        // A solid band of the header colour under the status bar: scrolled content never runs under the clock.
        Box(
            Modifier
                .fillMaxWidth()
                .windowInsetsTopHeight(WindowInsets.statusBars)
                .background(MMInk.Hero),
        )
    }
}

/** The dark header block. Its bottom carries the sheet's radius so the sheet can overlap it. */
@Composable
fun MMHeader(
    title: String,
    eyebrow: String? = null,
    lines: List<String> = emptyList(),
    onBack: (() -> Unit)? = null,
    showsWordmark: Boolean = onBack == null,
    trailing: @Composable RowScope.() -> Unit = {},
    accessory: (@Composable ColumnScope.() -> Unit)? = null,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MMInk.Hero)
            .statusBarsPadding()
            .padding(horizontal = MMMetrics.Inset)
            .padding(bottom = 26.dp + MMMetrics.SheetRadius),
    ) {
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) {
                IconButton(onClick = onBack, modifier = Modifier.offset(x = (-12).dp)) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
            }
            if (showsWordmark) {
                MMWordmark(size = if (onBack != null) 15f else 17f, modifier = if (onBack != null) Modifier.offset(x = (-8).dp) else Modifier)
            }
            Spacer(Modifier.weight(1f))
            trailing()
        }
        if (eyebrow != null && !mmIsLargeFont()) {
            Text(
                eyebrow.uppercase(),
                style = MMEyebrowStyle,
                color = MMInk.HeroSecondary,
                modifier = Modifier.padding(top = if (onBack != null) 10.dp else 18.dp),
            )
        }
        if (title.isNotEmpty()) {
            Text(
                title,
                style = mmFont(27f, FontWeight.SemiBold),
                color = Color.White,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .padding(top = 6.dp)
                    .semantics { heading() },
            )
        }
        lines.forEachIndexed { index, line ->
            Text(
                line,
                style = mmFont(if (index == 0) 14.5f else 13.5f),
                color = MMInk.HeroSecondary,
                modifier = Modifier.padding(top = if (index == 0) 4.dp else 2.dp),
            )
        }
        accessory?.let {
            Spacer(Modifier.height(22.dp))
            it()
        }
    }
}

/** The light working sheet, pulled up over the header by its radius. */
@Composable
fun MMSheet(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .mmPullUp(MMMetrics.SheetRadius)
            .clip(RoundedCornerShape(topStart = MMMetrics.SheetRadius, topEnd = MMMetrics.SheetRadius))
            .background(MMInk.Sheet)
            .padding(horizontal = MMMetrics.Inset)
            .padding(top = 20.dp),
    ) {
        // The app typography carries the dark theme's light text colour; on the sheet, text without its own colour
        // (and text-field input) is ink.
        androidx.compose.runtime.CompositionLocalProvider(
            androidx.compose.material3.LocalTextStyle provides androidx.compose.material3.LocalTextStyle.current.copy(color = MMInk.Text),
            androidx.compose.material3.LocalContentColor provides MMInk.Text,
        ) { content() }
    }
}

/** Large text (font scale ≥ 1.5): drop eyebrows and decorative glyphs, as iOS does at accessibility sizes. */
@Composable
fun mmIsLargeFont(): Boolean = androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.5f

// endregion

// region Header progress

/** Move-in proof on the dark header: label and percentage, a thin lime line on a dark track, and the count. */
@Composable
fun MMHeaderProofProgress(
    done: Int,
    total: Int,
    modifier: Modifier = Modifier,
    label: String = "Move-in proof",
    showsChevron: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val fraction = if (total == 0) 0f else done.toFloat() / total
    val description = if (total == 0) "$label: add rooms to start" else "$label: $done of $total rooms documented"
    Column(
        modifier
            .fillMaxWidth()
            .then(
                if (onClick != null) Modifier.clickable(onClickLabel = "Open rental", role = Role.Button, onClick = onClick)
                else Modifier,
            )
            .semantics(mergeDescendants = true) { this.contentDescription = description },
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, style = mmFont(12.5f, FontWeight.Medium), color = Color.White, modifier = Modifier.weight(1f))
            if (total > 0) {
                Text("${kotlin.math.round(fraction * 100).toInt()}%", style = mmFont(12.5f, FontWeight.Medium), color = MMInk.HeroSecondary)
            }
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(CircleShape)
                .background(MMInk.Track),
        ) {
            if (done > 0) {
                Box(
                    Modifier
                        .fillMaxWidth(fraction.coerceIn(0.02f, 1f))
                        .height(4.dp)
                        .clip(CircleShape)
                        .background(MMInk.LimeMark),
                )
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (total == 0) "Add rooms to start" else "$done of $total rooms documented",
                style = mmFont(12.5f),
                color = MMInk.HeroSecondary,
            )
            if (showsChevron) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MMInk.HeroSecondary,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}

// endregion

// region Actions

/** Press feedback on the light sheet: a slight scale and dim, no ripple flood (iOS `MMLightPressStyle`). */
@Composable
fun Modifier.mmPressable(
    enabled: Boolean = true,
    onClickLabel: String? = null,
    role: Role = Role.Button,
    onClick: () -> Unit,
): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val reduceMotion = MMMotion.rememberReduceMotion()
    return this
        .scale(if (pressed && !reduceMotion) 0.985f else 1f)
        .alpha(if (pressed) 0.82f else 1f)
        .clickable(
            interactionSource = interaction,
            indication = null,
            enabled = enabled,
            onClickLabel = onClickLabel,
            role = role,
            onClick = onClick,
        )
}

/** The one primary action on a screen: lime capsule, ink text. */
@Composable
fun MMPrimaryButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    isLoading: Boolean = false,
    enabled: Boolean = true,
    height: Dp = MMMetrics.CtaHeight,
) {
    val active = enabled && !isLoading
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = height)
            .clip(CircleShape)
            .background(MMInk.Lime.copy(alpha = if (enabled) 1f else 0.45f))
            .mmPressable(enabled = active, onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isLoading) {
            CircularProgressIndicator(color = MMInk.OnLime, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
        } else if (icon != null) {
            Icon(icon, contentDescription = null, tint = MMInk.OnLime, modifier = Modifier.size(17.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(
            title,
            style = mmFont(15.5f, FontWeight.SemiBold),
            color = MMInk.OnLime.copy(alpha = if (enabled) 1f else 0.6f),
            textAlign = TextAlign.Center,
            maxLines = mmLines(1),
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** A secondary action: plain ink text, full width, no fill. */
@Composable
fun MMSecondaryButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    tint: Color = MMInk.Text,
    enabled: Boolean = true,
) {
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .mmPressable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = tint.copy(alpha = if (enabled) 1f else 0.4f), modifier = Modifier.size(17.dp))
            Spacer(Modifier.width(7.dp))
        }
        Text(title, style = mmFont(15.5f, FontWeight.Medium), color = tint.copy(alpha = if (enabled) 1f else 0.4f))
    }
}

// endregion

// region Grouped content

/** A titled group of rows on the sheet: caption, white rounded container, optional footer. */
@Composable
fun MMGroup(
    modifier: Modifier = Modifier,
    title: String? = null,
    footer: String? = null,
    footerColor: Color = MMInk.Secondary,
    radius: Dp = MMMetrics.GroupRadius,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        title?.let {
            Text(
                it.uppercase(),
                style = mmFont(12f, FontWeight.Medium, tracking = 0.3f),
                color = MMInk.Secondary,
                modifier = Modifier
                    .padding(start = 16.dp)
                    .semantics { heading() },
            )
        }
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(radius))
                .background(MMInk.Card)
                .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(radius)),
            content = content,
        )
        footer?.let {
            Text(it, style = mmFont(12.5f), color = footerColor, modifier = Modifier.padding(horizontal = 16.dp))
        }
    }
}

/** A white container without a caption (a card of content, never nested in another). */
@Composable
fun MMPanel(
    modifier: Modifier = Modifier,
    padding: PaddingValues = PaddingValues(16.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MMMetrics.CardRadius))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.CardRadius))
            .padding(padding),
        content = content,
    )
}

@Composable
fun MMRowDivider(leading: Dp = 16.dp) {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(start = leading)
            .height(0.75.dp)
            .background(MMInk.Separator),
    )
}

enum class MMRowAccessory { Chevron, External, None }

/** A row: optional icon, title + optional subtitle, optional value / trailing, chevron or external mark. */
@Composable
fun MMRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    icon: ImageVector? = null,
    value: String? = null,
    tint: Color = MMInk.Text,
    accessory: MMRowAccessory = MMRowAccessory.Chevron,
    enabled: Boolean = true,
    titleSize: Float = 16f,
    trailing: (@Composable RowScope.() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.45f)
            .then(if (onClick != null) Modifier.mmPressable(enabled = enabled, onClick = onClick) else Modifier)
            .semantics(mergeDescendants = true) {}
            .heightIn(min = MMMetrics.RowHeight)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (icon != null && !mmIsLargeFont()) {
            Icon(icon, contentDescription = null, tint = tint.copy(alpha = 0.75f), modifier = Modifier.size(20.dp).width(24.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = mmFont(titleSize), color = tint, maxLines = mmLines(2), overflow = TextOverflow.Ellipsis)
            if (!subtitle.isNullOrEmpty()) {
                Text(subtitle, style = mmFont(13f), color = MMInk.Secondary, maxLines = mmLines(2), overflow = TextOverflow.Ellipsis)
            }
        }
        value?.let { Text(it, style = mmFont(15f), color = MMInk.Secondary, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        trailing?.invoke(this)
        when {
            accessory == MMRowAccessory.External -> Icon(
                Icons.AutoMirrored.Filled.OpenInNew,
                contentDescription = null,
                tint = MMInk.Secondary.copy(alpha = 0.75f),
                modifier = Modifier.size(15.dp),
            )
            accessory == MMRowAccessory.Chevron && onClick != null -> MMRowChevron()
            else -> Unit
        }
    }
}

@Composable
fun MMRowChevron() {
    Icon(
        Icons.AutoMirrored.Filled.KeyboardArrowRight,
        contentDescription = null,
        tint = MMInk.Secondary.copy(alpha = 0.6f),
        modifier = Modifier.size(20.dp),
    )
}

/** Section title on the sheet (sentence case, semibold) with an optional quiet action or fact on the right. */
@Composable
fun MMSectionTitle(
    title: String,
    modifier: Modifier = Modifier,
    trailing: String? = null,
    detail: String? = null,
    onTrailing: (() -> Unit)? = null,
) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            title,
            style = mmFont(16f, FontWeight.SemiBold),
            color = MMInk.Text,
            modifier = Modifier
                .weight(1f)
                .semantics { heading() },
        )
        if (trailing != null && onTrailing != null) {
            Row(
                Modifier
                    .heightIn(min = 48.dp)
                    .mmPressable(onClick = onTrailing)
                    .padding(start = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(trailing, style = mmFont(13f), color = MMInk.Secondary)
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(16.dp))
            }
        } else if (detail != null) {
            Text(detail, style = mmFont(13f), color = MMInk.Secondary)
        }
    }
}

// endregion

// region States

enum class MMNoticeTone { Error, Warning, Info, Success }

/** A calm inline notice with an optional action (iOS `MMNotice`). */
@Composable
fun MMNotice(
    message: String,
    modifier: Modifier = Modifier,
    tone: MMNoticeTone = MMNoticeTone.Error,
    actionTitle: String? = null,
    onAction: (() -> Unit)? = null,
) {
    val (icon, tint) = when (tone) {
        MMNoticeTone.Error -> Icons.Filled.Error to MMInk.Danger
        MMNoticeTone.Warning -> Icons.Filled.Warning to MMInk.Warning
        MMNoticeTone.Info -> Icons.Filled.Info to MMInk.Secondary
        MMNoticeTone.Success -> Icons.Filled.CheckCircle to MMInk.Text
    }
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(17.dp))
        Text(message, style = mmFont(14f), color = MMInk.Text, modifier = Modifier.weight(1f))
        if (actionTitle != null && onAction != null) {
            Box(
                Modifier
                    .heightIn(min = 48.dp)
                    .mmPressable(onClick = onAction)
                    .padding(horizontal = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(actionTitle, style = mmFont(14f, FontWeight.SemiBold), color = MMInk.Text)
            }
        }
    }
}

/** An empty state on the sheet: a quiet glyph, what's missing, why, and one action. */
@Composable
fun MMEmptyBlock(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    message: String? = null,
    actionTitle: String? = null,
    onAction: (() -> Unit)? = null,
) {
    MMPanel(modifier, padding = PaddingValues(18.dp)) {
        Icon(icon, contentDescription = null, tint = MMInk.Text.copy(alpha = 0.55f), modifier = Modifier.size(24.dp))
        Spacer(Modifier.height(8.dp))
        Text(title, style = mmFont(17f, FontWeight.SemiBold), color = MMInk.Text)
        message?.let {
            Spacer(Modifier.height(6.dp))
            Text(it, style = mmFont(14f), color = MMInk.Secondary)
        }
        if (actionTitle != null && onAction != null) {
            Spacer(Modifier.height(16.dp))
            MMPrimaryButton(title = actionTitle, onClick = onAction)
        }
    }
}

/** A loading state on the light surface. */
@Composable
fun MMLoadingBlock(modifier: Modifier = Modifier, message: String? = null) {
    Column(
        modifier
            .fillMaxWidth()
            .padding(vertical = 40.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.5.dp, modifier = Modifier.size(28.dp))
        message?.let { Text(it, style = mmFont(14f), color = MMInk.Secondary) }
    }
}

/** A small outlined capsule tag ("PRO"). */
@Composable
fun MMTag(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        style = mmFont(10.5f, FontWeight.SemiBold, tracking = 0.5f),
        color = MMInk.Secondary,
        modifier = modifier
            .border(1.dp, MMInk.CardStroke, CircleShape)
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}

// endregion

/** Bottom padding for a pushed screen with nothing floating over it. */
fun Modifier.mmNavigationBarTail(): Modifier = this.navigationBarsPadding()

/** A quiet glyph for a room by its name (iOS `RoomGlyph`): the next room has no photo yet, so it gets its kind. */
fun mmRoomGlyph(name: String): ImageVector {
    val n = name.lowercase()
    return when {
        "bed" in n -> Icons.Outlined.Bed
        "kitchen" in n || "dining" in n -> Icons.Outlined.Restaurant
        "bath" in n || "ensuite" in n || "washroom" in n -> Icons.Outlined.Shower
        "living" in n || "family" in n || "lounge" in n -> Icons.Outlined.Weekend
        "balcony" in n || "patio" in n || "terrace" in n -> Icons.Outlined.WbSunny
        "laundry" in n -> Icons.Outlined.LocalLaundryService
        "office" in n || "study" in n -> Icons.Outlined.DesktopWindows
        else -> Icons.Outlined.MeetingRoom
    }
}

/** Pulls a block up by [dy] and gives the space back, so a sheet overlaps the header's bottom by its radius. */
fun Modifier.mmPullUp(dy: Dp): Modifier = this.then(
    Modifier.layout { measurable, constraints ->
        val placeable = measurable.measure(constraints)
        val shift = dy.roundToPx()
        layout(placeable.width, (placeable.height - shift).coerceAtLeast(0)) { placeable.place(0, -shift) }
    },
)
