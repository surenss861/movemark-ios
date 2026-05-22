package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

@Composable
fun MMSettingsSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    footer: String? = null,
) {
    Column(modifier = modifier.padding(start = 2.dp, bottom = 8.dp)) {
        Text(
            title.uppercase(),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextMuted,
            letterSpacing = 0.5.sp,
        )
        footer?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(6.dp))
            Text(it, fontSize = 13.sp, color = MMColors.TextMuted)
        }
    }
}

@Composable
fun MMSettingsGroup(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        color = MMColors.Card,
        border = androidx.compose.foundation.BorderStroke(1.dp, MMColors.CardStroke),
    ) {
        Column { content() }
    }
}

@Composable
fun MMSettingsDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 14.dp),
        color = Color.White.copy(alpha = 0.06f),
    )
}

enum class MMSettingsAccessory {
    None,
    Chevron,
    External,
    Value,
    Pill,
}

@Composable
fun MMSettingsRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    value: String? = null,
    pillText: String? = null,
    pillIsActive: Boolean = false,
    accessory: MMSettingsAccessory = if (value != null || pillText != null) {
        MMSettingsAccessory.None
    } else {
        MMSettingsAccessory.Chevron
    },
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed && onClick != null && enabled) 0.97f else 1f,
        label = "settingsRowPress",
    )
    val clickableModifier = if (onClick != null && enabled) {
        Modifier.clickable(
            interactionSource = interactionSource,
            indication = null,
            onClick = onClick,
        )
    } else {
        Modifier
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .scale(scale)
            .alpha(if (enabled) 1f else 0.5f)
            .then(clickableModifier)
            .padding(horizontal = 14.dp, vertical = if (subtitle.isNullOrBlank()) 12.dp else 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 16.sp, color = MMColors.TextPrimary)
            subtitle?.takeIf { it.isNotBlank() }?.let {
                Spacer(Modifier.height(2.dp))
                Text(it, fontSize = 13.sp, color = MMColors.TextMuted, lineHeight = 16.sp)
            }
        }
        Spacer(Modifier.width(8.dp))
        when {
            pillText != null -> StatusPill(text = pillText, active = pillIsActive)
            value != null -> Text(value, fontSize = 15.sp, color = MMColors.TextSecondary, maxLines = 1)
            accessory == MMSettingsAccessory.External -> {
                Icon(
                    Icons.AutoMirrored.Filled.OpenInNew,
                    contentDescription = null,
                    tint = MMColors.TextMuted.copy(0.7f),
                    modifier = Modifier.height(14.dp),
                )
            }
            accessory == MMSettingsAccessory.Chevron && onClick != null -> {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MMColors.TextMuted.copy(0.7f),
                    modifier = Modifier.height(16.dp),
                )
            }
            else -> Unit
        }
    }
}

@Composable
private fun StatusPill(text: String, active: Boolean) {
    Text(
        text,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(
                if (active) MMColors.Primary.copy(0.18f) else MMColors.FieldFill.copy(0.9f),
            )
            .padding(horizontal = 9.dp, vertical = 4.dp),
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = if (active) MMColors.Primary else MMColors.TextMuted,
    )
}
