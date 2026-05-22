package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.export.ReportReadinessMapper
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun ExportHistorySection(
    exports: List<ExportRow>,
    modifier: Modifier = Modifier,
) {
    if (exports.isEmpty()) return
    Column(modifier) {
        Text(
            "Export history",
            color = MMColors.TextPrimary,
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.sp,
            modifier = Modifier.padding(bottom = 10.dp),
        )
        exports.forEach { row ->
            ExportHistoryRow(row)
            Spacer(Modifier.height(10.dp))
        }
    }
}

@Composable
private fun ExportHistoryRow(row: ExportRow) {
    MMProofCard {
        Text(exportTypeLabel(row.type), color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        Spacer(Modifier.height(4.dp))
        Text(formatExportDate(row.requestedAt), color = MMColors.TextSecondary, fontSize = 13.sp)
        Spacer(Modifier.height(6.dp))
        Text(
            row.verification.displayLabel,
            color = when (row.verification) {
                ExportVerificationStatus.Ready -> MMColors.Primary
                ExportVerificationStatus.ServerFailed -> MMColors.SemanticDanger
                else -> MMColors.TextMuted
            },
            fontSize = 12.sp,
        )
        row.filePath?.substringAfterLast('/')?.takeIf { it.isNotBlank() }?.let { short ->
            Spacer(Modifier.height(4.dp))
            Text(short, color = MMColors.TextSecondary.copy(0.78f), fontSize = 11.sp, maxLines = 1)
        }
    }
}

private fun exportTypeLabel(type: String): String = when (type) {
    ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> "Move-in report"
    "move_out_report" -> "Move-out report"
    "dispute_packet" -> "Dispute packet"
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
