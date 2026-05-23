package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCard
import com.surensureshkumar.movemark.core.design.components.MMProofDocumentPreview
import com.surensureshkumar.movemark.core.design.components.MMProofStatusBadge
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone
import com.surensureshkumar.movemark.data.export.ReportReadiness

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MMReportPreviewHero(
    readiness: ReportReadiness,
    metricsLine: String?,
    headline: String,
    footnote: String?,
    proofChips: List<String>,
    primaryTitle: String,
    primaryEnabled: Boolean,
    primaryLoading: Boolean,
    onPrimary: () -> Unit,
    appeared: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val isBright = readiness == ReportReadiness.ReadyToMake || readiness == ReportReadiness.ReadyToShare
    val isProcessing = readiness == ReportReadiness.Processing

    MMProofCaseCard(modifier.mmAppearRise(appeared, reduceMotion, label = "reportHero")) {
        Text(
            "Your move-in report",
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextSecondary,
        )
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = androidx.compose.ui.Alignment.Top) {
            MMProofDocumentPreview(
                large = true,
                isBright = isBright,
                isProcessing = isProcessing,
                reduceMotion = reduceMotion,
            )
            Spacer(Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                metricsLine?.takeIf { it.isNotBlank() }?.let {
                    Text(it, color = MMColors.TextSecondary, fontSize = 12.sp)
                    Spacer(Modifier.height(6.dp))
                }
                Text(headline, color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                footnote?.takeIf { it.isNotBlank() }?.let {
                    Spacer(Modifier.height(4.dp))
                    Text(it, color = MMColors.TextMuted, fontSize = 12.sp)
                }
                Spacer(Modifier.height(8.dp))
                MMProofStatusBadge(text = statusLabel(readiness), tone = statusTone(readiness))
            }
        }
        if (proofChips.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                proofChips.forEach { chip ->
                    Text(
                        chip,
                        modifier = Modifier
                            .background(MMColors.FieldFill.copy(alpha = 0.85f), RoundedCornerShape(50))
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                        color = MMColors.TextSecondary,
                        fontSize = 11.sp,
                    )
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        MMButton(
            text = primaryTitle,
            onClick = onPrimary,
            enabled = primaryEnabled,
            loading = primaryLoading,
            modifier = Modifier.mmAppearRise(appeared, reduceMotion, label = "reportCta"),
        )
    }
}

private fun statusLabel(readiness: ReportReadiness): String = when (readiness) {
    ReportReadiness.ReadyToMake -> "Report can be made"
    ReportReadiness.ReadyToShare -> "Report ready"
    ReportReadiness.Processing -> "Building report"
    ReportReadiness.Failed -> "Report failed"
    ReportReadiness.NotReady, ReportReadiness.NoVault -> "Needs more proof"
}

private fun statusTone(readiness: ReportReadiness): MMProofStatusTone = when (readiness) {
    ReportReadiness.ReadyToMake, ReportReadiness.ReadyToShare -> MMProofStatusTone.Success
    ReportReadiness.Processing -> MMProofStatusTone.Warning
    ReportReadiness.Failed -> MMProofStatusTone.Danger
    ReportReadiness.NotReady, ReportReadiness.NoVault -> MMProofStatusTone.Warning
}
