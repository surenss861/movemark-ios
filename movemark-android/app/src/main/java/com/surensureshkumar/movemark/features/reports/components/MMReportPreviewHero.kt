package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofCard
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

    MMProofCard(modifier.mmAppearRise(appeared, reduceMotion, label = "reportHero")) {
        Row(verticalAlignment = Alignment.Top) {
            DocumentPreview(
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
                StatusPill(readiness)
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

@Composable
private fun StatusPill(readiness: ReportReadiness) {
    val text = when (readiness) {
        ReportReadiness.ReadyToMake -> "Report can be made"
        ReportReadiness.ReadyToShare -> "Report ready"
        ReportReadiness.Processing -> "Building report"
        ReportReadiness.Failed -> "Report failed"
        ReportReadiness.NotReady, ReportReadiness.NoVault -> "Needs more proof"
    }
    val (bg, fg) = when (readiness) {
        ReportReadiness.ReadyToMake, ReportReadiness.ReadyToShare ->
            MMColors.Primary.copy(0.2f) to MMColors.Primary
        ReportReadiness.Processing ->
            MMColors.SemanticWarning.copy(0.2f) to MMColors.SemanticWarning
        ReportReadiness.Failed ->
            MMColors.SemanticDanger.copy(0.2f) to MMColors.SemanticDanger
        ReportReadiness.NotReady, ReportReadiness.NoVault ->
            MMColors.SemanticWarning.copy(0.2f) to MMColors.SemanticWarning
    }
    Text(
        text,
        modifier = Modifier
            .background(bg, RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        color = fg,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable
private fun DocumentPreview(
    isBright: Boolean,
    isProcessing: Boolean,
    reduceMotion: Boolean,
) {
    val pulseAlpha = if (isProcessing && !reduceMotion) {
        val transition = rememberInfiniteTransition(label = "docPulse")
        transition.animateFloat(
            initialValue = 0.88f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
            label = "docPulseAlpha",
        ).value
    } else {
        1f
    }

    Box(
        Modifier
            .size(width = 88.dp, height = 116.dp)
            .alpha(pulseAlpha),
    ) {
        Box(
            Modifier
                .size(58.dp, 88.dp)
                .offset(x = 10.dp, y = 8.dp)
                .rotate(5f)
                .background(MMColors.EvidenceCard.copy(0.9f), RoundedCornerShape(10.dp)),
        )
        Box(
            Modifier
                .size(60.dp, 92.dp)
                .offset(x = 5.dp, y = 4.dp)
                .rotate(2.5f)
                .background(MMColors.EvidenceCard.copy(0.95f), RoundedCornerShape(12.dp)),
        )
        Box(
            Modifier
                .size(72.dp, 108.dp)
                .background(
                    MMColors.PaperSurface.copy(if (isBright) 0.98f else 0.9f),
                    RoundedCornerShape(14.dp),
                )
                .padding(12.dp),
        ) {
            Column {
                Box(
                    Modifier
                        .width(36.dp)
                        .height(5.dp)
                        .background(
                            if (isBright) MMColors.Primary.copy(0.85f) else MMColors.SemanticWarning.copy(0.75f),
                            RoundedCornerShape(2.dp),
                        ),
                )
                Spacer(Modifier.height(6.dp))
                repeat(3) {
                    Box(
                        Modifier
                            .padding(bottom = 4.dp)
                            .width(if (it == 0) 44.dp else 40.dp)
                            .height(4.dp)
                            .background(Color.Black.copy(0.08f), RoundedCornerShape(2.dp)),
                    )
                }
                Spacer(Modifier.weight(1f))
                Text(
                    "PDF",
                    color = if (isBright) MMColors.PrimaryPressed else Color.Black.copy(0.55f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}
