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
    loading: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val isBright = !loading && readiness == ReportReadiness.ReadyToShare
    val isProcessing = !loading && readiness == ReportReadiness.Processing

    MMProofReportCard(
        model = MMProofReportModel(
            reportTitle = "Move-in report",
            metricsLine = if (loading) "Checking saved proof…" else metricsLine ?: headline,
            statusLabel = if (loading) "Checking proof" else statusLabel(readiness),
            statusTone = if (loading) MMProofStatusTone.Neutral else statusTone(readiness),
            footnote = footnote?.takeIf { !loading && metricsLine != null && headline != metricsLine }
                ?: headline.takeIf { !loading && metricsLine == null },
        ),
        primaryTitle = primaryTitle,
        onPrimary = onPrimary,
        primaryEnabled = primaryEnabled && !loading,
        primaryLoading = primaryLoading || loading,
        isBright = isBright,
        isProcessing = isProcessing,
        proofChips = if (loading) emptyList() else proofChips,
        reduceMotion = reduceMotion,
        modifier = modifier.mmAppearRise(appeared, reduceMotion, label = "reportHero"),
    )
}

private fun statusLabel(readiness: ReportReadiness): String = when (readiness) {
    ReportReadiness.ReadyToMake -> "Report can be made"
    ReportReadiness.ReadyToShare -> "Ready to share"
    ReportReadiness.Processing -> "Building report"
    ReportReadiness.Failed -> "Failed"
    ReportReadiness.NotReady, ReportReadiness.NoVault -> "Needs proof"
}

private fun statusTone(readiness: ReportReadiness): MMProofStatusTone = when (readiness) {
    ReportReadiness.ReadyToShare -> MMProofStatusTone.Success
    ReportReadiness.ReadyToMake -> MMProofStatusTone.Neutral
    ReportReadiness.Processing -> MMProofStatusTone.Warning
    ReportReadiness.Failed -> MMProofStatusTone.Danger
    ReportReadiness.NotReady, ReportReadiness.NoVault -> MMProofStatusTone.Warning
}
