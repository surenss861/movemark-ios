package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing

enum class MMProofCaseCardStyle {
    Standard,
    Marketing,
}

data class MMProofCaseHeader(
    val eyebrow: String,
    val statusLabel: String? = null,
    val statusTone: MMProofStatusTone = MMProofStatusTone.Neutral,
    val accentRail: MMProofCaseAccentRail = MMProofCaseAccentRail.None,
)

@Composable
fun MMProofCaseCard(
    modifier: Modifier = Modifier,
    style: MMProofCaseCardStyle = MMProofCaseCardStyle.Standard,
    cornerRadius: Dp = MMSpacing.CornerRadius.dp,
    header: MMProofCaseHeader? = null,
    contentPadding: Dp = 0.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(cornerRadius)
    val surfaceColor = when (style) {
        MMProofCaseCardStyle.Standard -> MMColors.CardRaised
        MMProofCaseCardStyle.Marketing -> MMColors.Card.copy(alpha = 0.98f)
    }
    val border = when (style) {
        MMProofCaseCardStyle.Standard -> BorderStroke(1.dp, MMColors.CardStroke)
        MMProofCaseCardStyle.Marketing -> BorderStroke(
            1.dp,
            Brush.linearGradient(
                listOf(MMColors.Primary.copy(0.28f), MMColors.CardStroke.copy(0.75f)),
            ),
        )
    }

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = shape,
        color = surfaceColor,
        border = border,
    ) {
        Box {
            if (header?.accentRail != MMProofCaseAccentRail.None) {
                MMProofCaseAccentRailOverlay(
                    rail = header!!.accentRail,
                    cornerRadius = cornerRadius,
                    modifier = Modifier
                        .align(androidx.compose.ui.Alignment.CenterStart)
                        .fillMaxHeight(),
                )
            }
            Column {
                header?.let {
                    MMProofCaseMetadataRow(
                        eyebrow = it.eyebrow,
                        statusLabel = it.statusLabel,
                        statusTone = it.statusTone,
                    )
                    MMProofCaseDivider()
                }
                Column(
                    Modifier
                        .then(if (contentPadding > 0.dp) Modifier.padding(contentPadding) else Modifier),
                    content = content,
                )
            }
        }
    }
}

@Composable
fun MMProofCaseCard(
    modifier: Modifier = Modifier,
    style: MMProofCaseCardStyle = MMProofCaseCardStyle.Standard,
    cornerRadius: Dp = MMSpacing.CornerRadius.dp,
    header: MMProofCaseHeader? = null,
    footer: @Composable () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    MMProofCaseCard(
        modifier = modifier,
        style = style,
        cornerRadius = cornerRadius,
        header = header,
        contentPadding = 0.dp,
    ) {
        content()
        footer()
    }
}

@Composable
fun MMProofCaseSecondaryCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    MMProofCaseCard(
        modifier = modifier,
        style = MMProofCaseCardStyle.Standard,
        cornerRadius = 18.dp,
        contentPadding = 18.dp,
        content = content,
    )
}
