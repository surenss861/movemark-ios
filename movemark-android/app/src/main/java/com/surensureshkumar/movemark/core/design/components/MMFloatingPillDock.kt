/**
 * @file The root dock (iOS `MMFloatingPillDock`): two charcoal capsules side by side that read as one object.
 *       Left, the expanded active capsule — a lime circle holding the active tab's icon in charcoal, then its
 *       title. Right, the compact capsule — the other destinations as icon-only 44dp buttons. Selecting a tab
 *       makes it the expanded capsule and the previous one drops into the slot it left; each icon travels rather
 *       than fading, the lime circle never moves. Icons, capsule width and title change on one spring.
 *       Navigation never waits for the dock: the shell swaps pages at once and the dock retargets.
 * @domain design-system
 * @see [[MMFloatingPillDock.swift]] — iOS reference (MMPillDockSpec)
 */
package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.navigation.MainTab

/** Every visual parameter of the pill dock (iOS `MMPillDockSpec`). */
object MMPillDockSpec {
    val Lime = MMInk.Lime
    val Charcoal = Color(0xFF292E29)
    val Ivory = Color(0xFFF5F7F0)

    val Button = 44.dp
    val CapsulePadding = 5.dp
    val CapsuleSpacing = 10.dp
    val IconTitleSpacing = 12.dp
    val CompactSpacing = 4.dp
    val TitleTrailingPadding = 14.dp
    val IconSize = 20.dp
    const val TITLE_SIZE = 15f
    val BottomInset = 12.dp
    val ShadowElevation = 10.dp
    val MaxTitleWidth = 120.dp

    /** iOS spring(response 0.24, damping 0.88): stiffness = (2π / response)². */
    fun <T> spring(reduceMotion: Boolean): FiniteAnimationSpec<T> =
        if (reduceMotion) snap() else spring(dampingRatio = 0.88f, stiffness = 685f)
}

private val DockOrder = listOf(MainTab.Vault, MainTab.Reports, MainTab.Account)

private val MainTab.dockTitle: String
    get() = when (this) {
        MainTab.Vault, MainTab.Rooms -> "Proof"
        MainTab.Reports -> "Reports"
        MainTab.Account -> "Account"
    }

private val MainTab.dockIcon: ImageVector
    get() = when (this) {
        MainTab.Vault, MainTab.Rooms -> Icons.Filled.Home
        MainTab.Reports -> Icons.Filled.Description
        MainTab.Account -> Icons.Filled.Person
    }

/**
 * The floating root dock. [selected] is the shell's real selection (the Rooms page counts as Proof); taps call
 * [onSelect] at once, a tap on the active tab calls [onReselect] (scroll to top). Hidden while the keyboard is up.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MMFloatingPillDock(
    selected: MainTab,
    onSelect: (MainTab) -> Unit,
    modifier: Modifier = Modifier,
    onReselect: (MainTab) -> Unit = {},
) {
    if (WindowInsets.isImeVisible) return
    val spec = MMPillDockSpec
    val reduceMotion = MMMotion.rememberReduceMotion()
    val haptics = LocalHapticFeedback.current
    val shown = if (selected == MainTab.Rooms) MainTab.Vault else selected

    // Which tab sits in each compact slot. A selection swaps exactly two tabs: the new one leaves its slot for the
    // lime circle and the previous one drops into that same slot; the third icon never changes slot.
    var slots by remember { mutableStateOf(DockOrder.filter { it != shown }) }
    var lastShown by remember { mutableStateOf(shown) }
    LaunchedEffect(shown) {
        if (shown != lastShown) {
            slots = slots.toMutableList().also { list ->
                val i = list.indexOf(shown)
                if (i >= 0) list[i] = lastShown
            }.takeIf { it.size == 2 && !it.contains(shown) } ?: DockOrder.filter { it != shown }
            lastShown = shown
        }
    }

    // Measured title widths at the current font scale, capped so the dock never leaves the screen.
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val titleStyle = androidx.compose.ui.text.TextStyle(fontSize = spec.TITLE_SIZE.sp, fontWeight = FontWeight.SemiBold)
    val titleWidths: Map<MainTab, Dp> = remember(density.fontScale, density.density) {
        DockOrder.associateWith { tab ->
            with(density) { measurer.measure(tab.dockTitle, titleStyle).size.width.toDp() }.coerceAtMost(spec.MaxTitleWidth) + 1.dp
        }
    }

    val rowHeight = spec.Button + spec.CapsulePadding * 2
    fun activeWidth(tab: MainTab): Dp =
        spec.CapsulePadding + spec.Button + spec.IconTitleSpacing + (titleWidths[tab] ?: 60.dp) + spec.TitleTrailingPadding + spec.CapsulePadding
    val compactWidth = spec.CapsulePadding * 2 + spec.Button * 2 + spec.CompactSpacing
    val activeW by animateDpAsState(activeWidth(shown), spec.spring(reduceMotion), label = "dockActiveWidth")
    val compactX = activeW + spec.CapsuleSpacing
    val totalWidth = activeW + spec.CapsuleSpacing + compactWidth

    Box(
        modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(bottom = spec.BottomInset),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Box(Modifier.width(totalWidth).height(rowHeight)) {
            // Structure: two charcoal capsules and the lime circle.
            Box(
                Modifier
                    .width(activeW)
                    .height(rowHeight)
                    .shadow(spec.ShadowElevation, CircleShape, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f))
                    .background(spec.Charcoal, CircleShape)
                    // The rest of the active capsule (its title) also reselects: it is one control visually.
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onReselect(selected) }
                    .semantics { },
            )
            Box(
                Modifier
                    .offset(x = compactX)
                    .width(compactWidth)
                    .height(rowHeight)
                    .shadow(spec.ShadowElevation, CircleShape, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f))
                    .background(spec.Charcoal, CircleShape),
            )
            Box(
                Modifier
                    .offset(x = spec.CapsulePadding, y = spec.CapsulePadding)
                    .size(spec.Button)
                    .background(spec.Lime, CircleShape),
            )

            // Titles: the old one leaves before the new one arrives, so two never overlap.
            DockOrder.forEach { tab ->
                val visible = tab == shown
                val alpha by animateFloatAsState(
                    targetValue = if (visible) 1f else 0f,
                    animationSpec = if (reduceMotion) tween(0) else if (visible) tween(130, delayMillis = 90) else tween(70),
                    label = "dockTitle$tab",
                )
                Box(
                    Modifier
                        .offset(x = spec.CapsulePadding + spec.Button + spec.IconTitleSpacing)
                        .width(titleWidths[tab] ?: 60.dp)
                        .height(rowHeight)
                        .alpha(alpha),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Text(
                        tab.dockTitle,
                        style = titleStyle,
                        color = spec.Ivory,
                        maxLines = 1,
                        overflow = TextOverflow.Clip,
                        softWrap = false,
                    )
                }
            }

            // One persistent button per tab; it travels with its icon.
            DockOrder.forEachIndexed { index, tab ->
                val onLime = tab == shown
                val targetX = if (onLime) {
                    spec.CapsulePadding
                } else {
                    val slot = slots.indexOf(tab).coerceAtLeast(0)
                    compactX + spec.CapsulePadding + (spec.Button + spec.CompactSpacing) * slot
                }
                val x by animateDpAsState(targetX, spec.spring(reduceMotion), label = "dockIconX$tab")
                val tint by animateColorAsState(
                    if (onLime) spec.Charcoal else spec.Ivory,
                    if (reduceMotion) tween(0) else tween(160),
                    label = "dockIconTint$tab",
                )
                val interaction = remember { MutableInteractionSource() }
                val pressed by interaction.collectIsPressedAsState()
                val isSelected = tab == shown
                Box(
                    Modifier
                        .zIndex(1f)
                        .offset(x = x, y = spec.CapsulePadding)
                        .size(spec.Button)
                        .scale(if (pressed && !reduceMotion) 0.96f else 1f)
                        .clickable(interactionSource = interaction, indication = null) {
                            if (tab == selected) {
                                onReselect(tab)
                            } else {
                                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onSelect(tab)
                            }
                        }
                        .semantics {
                            role = Role.Tab
                            this.selected = isSelected
                            contentDescription = tab.dockTitle
                            traversalIndex = index.toFloat()
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(tab.dockIcon, contentDescription = null, tint = tint, modifier = Modifier.size(spec.IconSize))
                }
            }
        }
    }
}
