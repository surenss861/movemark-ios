package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.surensureshkumar.movemark.core.design.components.MMProofReportCard
import com.surensureshkumar.movemark.core.design.components.MMProofReportModel
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone

@Composable
fun MMReportNoVaultPlaceholder(
    onOpenVault: () -> Unit,
    modifier: Modifier = Modifier,
) {
    MMProofReportCard(
        model = MMProofReportModel(
            reportTitle = "Move-in report",
            metricsLine = "Pick a vault to see report readiness",
            statusLabel = "Needs proof",
            statusTone = MMProofStatusTone.Neutral,
            footnote = "Reports belong to one rental. Create or open a vault first.",
        ),
        primaryTitle = "Open vault",
        onPrimary = onOpenVault,
        primaryEnabled = true,
        isBright = false,
        modifier = modifier,
    )
}
