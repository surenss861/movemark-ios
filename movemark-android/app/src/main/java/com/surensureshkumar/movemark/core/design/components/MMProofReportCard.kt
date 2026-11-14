package com.surensureshkumar.movemark.core.design.components

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

data class MMProofReportModel(
    val reportTitle: String,
    val metricsLine: String? = null,
    val statusLabel: String,
    val statusTone: MMProofStatusTone = MMProofStatusTone.Neutral,
    val footnote: String? = null,
    val generatedLine: String? = null,
    val recordId: String? = null,
)

@Composable
fun MMProofReportCard(
    model: MMProofReportModel,
    primaryTitle: String,
    onPrimary: () -> Unit,
    modifier: Modifier = Modifier,
    primaryEnabled: Boolean = true,
    primaryLoading: Boolean = false,
    primaryStyle: MMButtonStyle = MMButtonStyle.Primary,
    isBright: Boolean = false,
    isProcessing: Boolean = false,
    isCompact: Boolean = false,
    proofChips: List<String> = emptyList(),
    legalNote: String? = null,
    reduceMotion: Boolean = false,
) {
    val metrics = if (proofChips.isNotEmpty()) proofChips.joinToString(" · ") else model.metricsLine
    MMCaseFilePlate(
        modifier = modifier,
        emphasis = !isCompact && isBright,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            MMProofDocumentPreview(
                large = !isCompact,
                isBright = isBright,
                isProcessing = isProcessing,
                reduceMotion = reduceMotion,
            )
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    model.reportTitle.uppercase(),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 1.05.sp,
                    color = MMColors.TextMuted,
                )
                Text(
                    model.statusLabel.uppercase(),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.4.sp,
                    color = statusColor(model.statusTone),
                    modifier = Modifier.padding(top = 4.dp),
                )
                metrics?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        it,
                        fontSize = 14.sp,
                        color = MMColors.TextSecondary,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                model.generatedLine?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        it,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = MMColors.TextMuted,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                model.footnote?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        it,
                        fontSize = 12.sp,
                        color = MMColors.TextSecondary,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                model.recordId?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        it,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = MMColors.TextMuted,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
        legalNote?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(10.dp))
            Text(it, fontSize = 12.sp, color = MMColors.TextMuted)
        }
        Spacer(Modifier.height(14.dp))
        MMButton(
            text = primaryTitle,
            onClick = onPrimary,
            enabled = primaryEnabled,
            loading = primaryLoading,
            style = primaryStyle,
        )
    }
}

private fun statusColor(tone: MMProofStatusTone): Color = when (tone) {
    MMProofStatusTone.Success -> MMColors.Primary
    MMProofStatusTone.Warning -> MMColors.SemanticWarning
    MMProofStatusTone.Danger -> MMColors.SemanticDanger
    MMProofStatusTone.Info -> MMColors.SemanticInfo
    MMProofStatusTone.Neutral -> MMColors.TextPrimary
}
