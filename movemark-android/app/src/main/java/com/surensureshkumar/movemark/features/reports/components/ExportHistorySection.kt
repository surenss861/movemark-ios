package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmPressable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.semantics
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.export.ReportReadinessMapper
import com.surensureshkumar.movemark.data.export.isActiveJob
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun ExportHistoryEmptyState(modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(
            "Export history",
            color = MMColors.TextMuted,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 2.dp, bottom = 10.dp),
        )
        Text(
            "Create your first move-in report once proof is ready.",
            color = MMColors.TextSecondary,
            fontSize = 14.sp,
        )
    }
}

@Composable
fun ExportHistorySection(
    exports: List<ExportRow>,
    onShare: (ExportRow) -> Unit,
    onRetry: (ExportRow) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    if (exports.isEmpty()) return
    // iOS `ReportsHomeView.historyList`: a quiet list, newest first, five shown until expanded.
    var showAll by remember { mutableStateOf(false) }
    val shown = if (showAll) exports else exports.take(HISTORY_PREVIEW_LIMIT)
    Column(modifier) {
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(MMMetrics.CardRadius))
                .background(MMInk.Card)
                .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.CardRadius)),
        ) {
            shown.forEachIndexed { index, row ->
                if (index > 0) MMRowDivider(leading = 50.dp)
                ExportHistoryRow(
                    row = row,
                    onShare = { onShare(row) },
                    onRetry = { onRetry(row) },
                )
            }
        }
        if (exports.size > HISTORY_PREVIEW_LIMIT) {
            Text(
                if (showAll) "Show fewer" else "Show all ${exports.size}",
                style = mmFont(13.5f, FontWeight.Medium),
                color = MMInk.Secondary,
                modifier = Modifier
                    .heightIn(min = 48.dp)
                    .mmPressable(onClick = { showAll = !showAll })
                    .padding(start = 4.dp, top = 14.dp),
            )
        }
    }
}

private const val HISTORY_PREVIEW_LIMIT = 5

@Composable
private fun ExportHistoryRow(
    row: ExportRow,
    onShare: () -> Unit,
    onRetry: () -> Unit,
) {
    val canShare = row.verification == ExportVerificationStatus.Ready
    // Android has always offered Retry on any failed attempt; kept (iOS offers it on the newest only).
    val canRetry = row.verification == ExportVerificationStatus.ServerFailed
    val generating = row.verification in setOf(
        ExportVerificationStatus.Queued,
        ExportVerificationStatus.Processing,
        ExportVerificationStatus.Verifying,
    )
    val status = when {
        canShare -> "Ready"
        generating -> "Generating…"
        row.verification == ExportVerificationStatus.ServerFailed -> "Couldn't generate"
        else -> "Unavailable"
    }
    val date = shortExportDate(row.requestedAt)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .mmPressable(
                enabled = canShare || canRetry,
                onClickLabel = if (canShare) "Share" else "Retry",
                onClick = { if (canShare) onShare() else onRetry() },
            )
            .semantics(mergeDescendants = true) {}
            .heightIn(min = 56.dp)
            .padding(start = 14.dp, end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(Icons.Outlined.Description, contentDescription = null, tint = MMInk.Text.copy(alpha = 0.75f), modifier = Modifier.size(20.dp))
        Column(Modifier.weight(1f).padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                exportTypeLabel(row.type),
                style = mmFont(14.5f),
                color = MMInk.Text,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (date.isBlank()) status else "$date · $status",
                style = mmFont(12f),
                color = MMInk.Secondary,
            )
        }
        Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
            when {
                canShare -> Icon(Icons.Filled.Share, contentDescription = "Share ${exportTypeLabel(row.type)}", tint = MMInk.Text.copy(alpha = 0.8f), modifier = Modifier.size(18.dp))
                generating -> CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                canRetry -> Text("Retry", style = mmFont(14f, FontWeight.SemiBold), color = MMInk.Text)
                else -> Unit
            }
        }
    }
}

private fun exportTypeLabel(type: String): String = when (type) {
    ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> "Move-in report"
    ReportReadinessMapper.MOVE_OUT_REPORT_TYPE -> "Move-out report"
    ReportReadinessMapper.DISPUTE_PACKET_TYPE -> "Dispute packet"
    else -> type.replace('_', ' ').replaceFirstChar { it.titlecase(Locale.getDefault()) }
}

private fun shortExportDate(raw: String?): String {
    if (raw.isNullOrBlank()) return ""
    return runCatching {
        val instant = Instant.parse(raw)
        DateTimeFormatter.ofPattern("MMM d · h:mm a", Locale.US)
            .withZone(ZoneId.systemDefault())
            .format(instant)
    }.getOrElse { raw }
}
