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
import com.surensureshkumar.movemark.core.design.components.MMProofStatusBadge
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone
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
    Column(modifier) {
        Text(
            "EXPORT HISTORY",
            color = MMColors.TextMuted,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.05.sp,
            modifier = Modifier.padding(start = 2.dp, bottom = 10.dp),
        )
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(MMColors.SurfaceRaised),
        ) {
            exports.forEachIndexed { index, row ->
                if (index > 0) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(start = 16.dp)
                            .height(1.dp)
                            .background(MMColors.CardStroke),
                    )
                }
                ExportHistoryRow(row = row, onShare = { onShare(row) }, onRetry = { onRetry(row) })
            }
        }
    }
}

@Composable
private fun ExportHistoryRow(
    row: ExportRow,
    onShare: () -> Unit,
    onRetry: () -> Unit,
) {
    val canShare = row.verification == ExportVerificationStatus.Ready
    val canRetry = row.verification == ExportVerificationStatus.ServerFailed
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = canShare || canRetry, onClick = { if (canShare) onShare() else onRetry() })
            .padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                exportTypeLabel(row.type),
                color = MMColors.TextPrimary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                shortExportDate(row.requestedAt),
                color = MMColors.TextMuted,
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier.padding(top = 2.dp),
            )
            Text(
                "MM-RP-" + row.id.toString().take(4).uppercase(),
                color = MMColors.TextMuted,
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
            )
        }
        if (!canShare) {
            MMProofStatusBadge(
                text = if (canRetry) "Failed · Retry" else row.verification.displayLabel,
                tone = historyStatusTone(row.verification),
            )
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MMColors.TextMuted.copy(alpha = if (canShare || canRetry) 1f else 0f),
        )
    }
}

private fun historyStatusTone(status: ExportVerificationStatus): MMProofStatusTone = when (status) {
    ExportVerificationStatus.Ready -> MMProofStatusTone.Success
    ExportVerificationStatus.ServerFailed -> MMProofStatusTone.Danger
    ExportVerificationStatus.Queued,
    ExportVerificationStatus.Processing,
    ExportVerificationStatus.Verifying,
    -> MMProofStatusTone.Warning
    ExportVerificationStatus.MissingPath -> MMProofStatusTone.Neutral
}

private fun exportTypeLabel(type: String): String = when (type) {
    ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> "Move-in report"
    ReportReadinessMapper.MOVE_OUT_REPORT_TYPE -> "Move-out report"
    ReportReadinessMapper.DISPUTE_PACKET_TYPE -> "Dispute packet"
    else -> type.replace('_', ' ').replaceFirstChar { it.titlecase(Locale.getDefault()) }
}

private fun shortExportDate(raw: String?): String {
    if (raw.isNullOrBlank()) return "Unknown date"
    return runCatching {
        val instant = Instant.parse(raw)
        DateTimeFormatter.ofPattern("MMM d · h:mm a", Locale.US)
            .withZone(ZoneId.systemDefault())
            .format(instant)
    }.getOrElse { raw }
}
