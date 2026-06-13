package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

@Composable
fun MMProofCaseMetadataRow(
    eyebrow: String,
    statusLabel: String? = null,
    statusTone: MMProofStatusTone = MMProofStatusTone.Neutral,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            eyebrow.uppercase(),
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.8.sp,
            color = MMColors.TextMuted,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
        statusLabel?.let {
            Spacer(Modifier.width(8.dp))
            if (statusTone == MMProofStatusTone.Success || statusTone == MMProofStatusTone.Warning) {
                MMProofStatusBadge(text = it, tone = statusTone)
            } else {
                Text(
                    it.uppercase(),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.6.sp,
                    color = statusTextColor(statusTone),
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
fun MMProofCaseDivider(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(MMColors.CardStroke.copy(alpha = 0.65f)),
    )
}

@Composable
fun MMProofCaseDetailSection(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            title,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextPrimary,
            maxLines = 2,
        )
        subtitle?.takeIf { it.isNotBlank() }?.let {
            Text(
                it,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = MMColors.TextSecondary.copy(alpha = 0.85f),
                modifier = Modifier.padding(top = 4.dp),
                maxLines = 2,
            )
        }
    }
}

enum class MMProofCaseAccentRail {
    None,
    Saved,
    NeedsProof,
}

@Composable
fun MMProofCaseAccentRailOverlay(
    rail: MMProofCaseAccentRail,
    cornerRadius: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier,
) {
    if (rail == MMProofCaseAccentRail.None) return
    val color = when (rail) {
        MMProofCaseAccentRail.Saved -> MMColors.Primary.copy(alpha = 0.72f)
        MMProofCaseAccentRail.NeedsProof -> MMColors.SemanticWarning.copy(alpha = 0.72f)
        MMProofCaseAccentRail.None -> return
    }
    Box(
        modifier = modifier
            .width(2.dp)
            .fillMaxHeight()
            .padding(start = 0.dp)
            .clip(RoundedCornerShape(topStart = cornerRadius, bottomStart = cornerRadius))
            .background(color),
    )
}

private fun statusTextColor(tone: MMProofStatusTone) = when (tone) {
    MMProofStatusTone.Success -> MMColors.Primary.copy(alpha = 0.92f)
    MMProofStatusTone.Warning -> MMColors.SemanticWarning
    MMProofStatusTone.Danger -> MMColors.SemanticDanger
    MMProofStatusTone.Neutral -> MMColors.TextMuted
}

@Composable
fun MMProofCaseReceiptRow(
    savedTitle: String,
    timestampLabel: String? = null,
    statusBadge: String? = null,
    statusTone: MMProofStatusTone = MMProofStatusTone.Success,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            tint = MMColors.Primary,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.width(8.dp))
        Column(Modifier.weight(1f)) {
            Text(savedTitle, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = MMColors.TextPrimary)
            timestampLabel?.let {
                Text(it, fontSize = 11.sp, color = MMColors.TextMuted, modifier = Modifier.padding(top = 2.dp))
            }
        }
        statusBadge?.let { MMProofStatusBadge(text = it, tone = statusTone) }
    }
}
