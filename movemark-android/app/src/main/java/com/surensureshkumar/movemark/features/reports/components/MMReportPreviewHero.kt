package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMProofReportCard
import com.surensureshkumar.movemark.core.design.components.MMProofReportModel
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone
import com.surensureshkumar.movemark.data.export.ReportReadiness

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

    MMProofReportCard(
        model = MMProofReportModel(
            reportTitle = "Move-in report",
            metricsLine = metricsLine ?: headline,
            statusLabel = statusLabel(readiness),
            statusTone = statusTone(readiness),
            footnote = footnote?.takeIf { metricsLine != null && headline != metricsLine } ?: headline.takeIf { metricsLine == null },
        ),
        primaryTitle = primaryTitle,
        onPrimary = onPrimary,
        primaryEnabled = primaryEnabled,
        primaryLoading = primaryLoading,
        isBright = isBright,
        isProcessing = isProcessing,
        proofChips = proofChips,
        reduceMotion = reduceMotion,
        modifier = modifier.mmAppearRise(appeared, reduceMotion, label = "reportHero"),
    )
}

private fun statusLabel(readiness: ReportReadiness): String = when (readiness) {
    ReportReadiness.ReadyToMake -> "Report can be made"
    ReportReadiness.ReadyToShare -> "Ready to share"
    ReportReadiness.Processing -> "Building"
    ReportReadiness.Failed -> "Failed"
    ReportReadiness.NotReady, ReportReadiness.NoVault -> "Needs proof"
}

private fun statusTone(readiness: ReportReadiness): MMProofStatusTone = when (readiness) {
    ReportReadiness.ReadyToMake, ReportReadiness.ReadyToShare -> MMProofStatusTone.Success
    ReportReadiness.Processing -> MMProofStatusTone.Warning
    ReportReadiness.Failed -> MMProofStatusTone.Danger
    ReportReadiness.NotReady, ReportReadiness.NoVault -> MMProofStatusTone.Warning
}
