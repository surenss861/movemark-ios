package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
)

/**
 * Report artifact card — document/PDF preview, honest status, proof metrics. No room photos.
 */
@OptIn(ExperimentalLayoutApi::class)
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
    val cardPadding = if (isCompact) 12.dp else 14.dp
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(if (isCompact) 16.dp else 20.dp),
        color = MMColors.EvidenceCard,
        border = BorderStroke(1.dp, MMColors.CardStroke),
    ) {
        Column(Modifier.padding(cardPadding)) {
            Text(
                model.reportTitle.uppercase(),
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.7.sp,
                color = MMColors.TextMuted,
            )
            model.metricsLine?.takeIf { it.isNotBlank() }?.let {
                Text(
                    it,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextSecondary,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp),
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
                    MMProofStatusBadge(text = model.statusLabel, tone = model.statusTone)
                    model.footnote?.takeIf { it.isNotBlank() }?.let {
                        Text(
                            it,
                            fontSize = 12.sp,
                            color = MMColors.TextMuted,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }
                }
            }
            if (proofChips.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
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
}
