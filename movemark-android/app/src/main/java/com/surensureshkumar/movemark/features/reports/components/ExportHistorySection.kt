package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofDocumentPreview
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
            "Export history",
            color = MMColors.TextMuted,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 2.dp, bottom = 10.dp),
        )
        exports.forEach { row ->
            ExportHistoryRow(row = row, onShare = { onShare(row) }, onRetry = { onRetry(row) })
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ExportHistoryRow(
    row: ExportRow,
    onShare: () -> Unit,
    onRetry: () -> Unit,
) {
    val isReady = row.verification == ExportVerificationStatus.Ready
  Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 2.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        MMProofDocumentPreview(
            large = false,
            isBright = isReady,
            isProcessing = row.verification.isActiveJob,
        )
        Column(Modifier.weight(1f)) {
            Text(
                exportTypeLabel(row.type),
                color = MMColors.TextPrimary,
                fontWeight = FontWeight.Medium,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                formatExportDate(row.requestedAt),
                color = MMColors.TextMuted,
                fontSize = 12.sp,
            )
            Spacer(Modifier.height(4.dp))
            MMProofStatusBadge(
                text = row.verification.displayLabel,
                tone = historyStatusTone(row.verification),
            )
        }
        if (isReady) {
            MMButton(
                text = "Share",
                onClick = onShare,
                style = MMButtonStyle.Secondary,
                modifier = Modifier.width(88.dp),
            )
        } else if (row.verification == ExportVerificationStatus.ServerFailed) {
            MMButton(
                text = "Retry",
                onClick = onRetry,
                style = MMButtonStyle.Secondary,
                modifier = Modifier.width(88.dp),
            )
        }
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

private fun formatExportDate(raw: String?): String {
    if (raw.isNullOrBlank()) return "Unknown date"
    return runCatching {
        val instant = Instant.parse(raw)
        DateTimeFormatter.ofPattern("MMM d, yyyy · h:mm a")
            .withZone(ZoneId.systemDefault())
            .format(instant)
    }.getOrElse { raw }
}
