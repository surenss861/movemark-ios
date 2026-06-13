package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

enum class MMCompactProofRowStyle {
    Standard,
    Settings,
}

@Composable
fun MMCompactProofRow(
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    meta: String? = null,
    style: MMCompactProofRowStyle = MMCompactProofRowStyle.Standard,
    leading: @Composable (() -> Unit)? = null,
    trailingIcon: ImageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
    trailingTint: Color = MMColors.TextSecondary,
    badge: String? = null,
    badgeTone: MMProofStatusTone = MMProofStatusTone.Warning,
    onClick: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, label = "compactRowPress")
    val cornerRadius = if (style == MMCompactProofRowStyle.Settings) 22.dp else 16.dp

    val rowModifier = modifier
        .fillMaxWidth()
        .scale(scale)
        .then(
            if (onClick != null) {
                Modifier.clickable(interactionSource = interactionSource, indication = null, onClick = onClick)
            } else {
                Modifier
            },
        )

    if (style == MMCompactProofRowStyle.Settings) {
        Row(
            modifier = rowModifier
                .background(MMColors.Card.copy(alpha = 0.96f), RoundedCornerShape(cornerRadius))
                .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(cornerRadius))
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CompactRowContent(
                title = title,
                subtitle = subtitle,
                meta = meta,
                leading = leading,
                trailingIcon = trailingIcon,
                trailingTint = trailingTint,
                badge = badge,
                badgeTone = badgeTone,
            )
        }
    } else {
        MMProofCard(modifier = rowModifier) {
            CompactRowContent(
                title = title,
                subtitle = subtitle,
                meta = meta,
                leading = leading,
                trailingIcon = trailingIcon,
                trailingTint = trailingTint,
                badge = badge,
                badgeTone = badgeTone,
            )
        }
    }
}

@Composable
private fun CompactRowContent(
    title: String,
    subtitle: String,
    meta: String?,
    leading: @Composable (() -> Unit)?,
    trailingIcon: ImageVector,
    trailingTint: Color,
    badge: String?,
    badgeTone: MMProofStatusTone,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        leading?.invoke()
        if (leading != null) {
            Spacer(Modifier.width(14.dp))
        }
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.TextPrimary,
                    modifier = Modifier.weight(1f, fill = false),
                )
                badge?.let {
                    Spacer(Modifier.width(8.dp))
                    MMProofStatusBadge(text = it, tone = badgeTone)
                }
            }
            Spacer(Modifier.height(4.dp))
            AnimatedContent(
                targetState = subtitle,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "compactRowSubtitle",
            ) { line ->
                Text(line, fontSize = 13.sp, color = MMColors.TextSecondary.copy(alpha = 0.9f))
            }
            meta?.takeIf { it.isNotBlank() }?.let {
                Spacer(Modifier.height(2.dp))
                Text(it, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MMColors.TextMuted, maxLines = 1)
            }
        }
        Icon(
            imageVector = trailingIcon,
            contentDescription = null,
            tint = trailingTint,
            modifier = Modifier.size(if (trailingIcon == Icons.Default.CheckCircle) 22.dp else 18.dp),
        )
    }
}
