package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMProofReportCard
import com.surensureshkumar.movemark.core.design.components.MMProofReportModel
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone

@Composable
fun MMReportExportSection(
    sectionTitle: String,
    sectionSubtitle: String?,
    statusLine: String,
    statusColor: Color,
    metricsLine: String?,
    primaryTitle: String,
    primaryEnabled: Boolean,
    primaryLoading: Boolean,
    onPrimary: () -> Unit,
    legalNote: String? = null,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        sectionSubtitle?.let {
            Text(it, color = MMColors.TextSecondary, fontSize = 14.sp)
            Spacer(Modifier.height(8.dp))
        }
        MMProofReportCard(
            model = MMProofReportModel(
                reportTitle = sectionTitle,
                metricsLine = metricsLine,
                statusLabel = statusLine,
                statusTone = statusTone(statusColor, primaryEnabled),
            ),
            primaryTitle = primaryTitle,
            onPrimary = onPrimary,
            primaryEnabled = primaryEnabled,
            primaryLoading = primaryLoading,
            isBright = primaryEnabled,
            legalNote = legalNote,
        )
    }
}

private fun statusTone(statusColor: Color, primaryEnabled: Boolean): MMProofStatusTone = when {
    statusColor == MMColors.Primary -> MMProofStatusTone.Success
    statusColor == MMColors.SemanticDanger -> MMProofStatusTone.Danger
    statusColor == MMColors.SemanticWarning -> MMProofStatusTone.Warning
    primaryEnabled -> MMProofStatusTone.Success
    else -> MMProofStatusTone.Neutral
}
