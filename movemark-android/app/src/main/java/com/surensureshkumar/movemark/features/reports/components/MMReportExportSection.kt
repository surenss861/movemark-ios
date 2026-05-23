package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.mmAppearRise
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
    footnote: String?,
    primaryTitle: String,
    primaryEnabled: Boolean,
    primaryLoading: Boolean,
    onPrimary: () -> Unit,
    appeared: Boolean,
    reduceMotion: Boolean,
    isProcessing: Boolean = false,
    isProLocked: Boolean = false,
    legalNote: String? = null,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        Text(
            sectionTitle,
            color = MMColors.TextMuted,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 2.dp, bottom = 8.dp),
        )
        sectionSubtitle?.let {
            Text(it, color = MMColors.TextSecondary, fontSize = 14.sp)
            Spacer(Modifier.height(8.dp))
        }
        MMProofReportCard(
            model = MMProofReportModel(
                reportTitle = sectionTitle,
                metricsLine = metricsLine,
                statusLabel = if (isProLocked) "Pro feature" else statusLine,
                statusTone = if (isProLocked) MMProofStatusTone.Neutral else statusTone(statusColor, primaryEnabled),
                footnote = when {
                    isProLocked -> "Unlock with MoveMark Pro"
                    else -> footnote
                },
            ),
            primaryTitle = primaryTitle,
            onPrimary = onPrimary,
            primaryEnabled = primaryEnabled,
            primaryLoading = primaryLoading,
            isBright = !isProLocked && statusColor == MMColors.Primary,
            isProcessing = isProcessing,
            isCompact = true,
            legalNote = legalNote,
            reduceMotion = reduceMotion,
            modifier = Modifier.mmAppearRise(appeared, reduceMotion, label = "export_$sectionTitle"),
        )
    }
}

private fun statusTone(statusColor: Color, primaryEnabled: Boolean): MMProofStatusTone = when {
    statusColor == MMColors.Primary -> MMProofStatusTone.Success
    statusColor == MMColors.SemanticDanger -> MMProofStatusTone.Danger
    statusColor == MMColors.SemanticWarning -> MMProofStatusTone.Warning
    statusColor == MMColors.TextSecondary -> MMProofStatusTone.Warning
    primaryEnabled -> MMProofStatusTone.Neutral
    else -> MMProofStatusTone.Neutral
}
