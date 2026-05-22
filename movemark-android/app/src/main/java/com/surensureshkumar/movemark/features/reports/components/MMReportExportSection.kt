package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofCard

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
        Text(
            sectionTitle,
            style = androidx.compose.material3.MaterialTheme.typography.titleLarge,
            color = MMColors.TextPrimary,
        )
        sectionSubtitle?.let {
            Spacer(Modifier.height(4.dp))
            Text(it, color = MMColors.TextSecondary, fontSize = 14.sp)
        }
        Spacer(Modifier.height(10.dp))
        MMProofCard {
            Row(verticalAlignment = Alignment.Top) {
                MiniDocumentPreview()
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        statusLine,
                        color = statusColor,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                    )
                    metricsLine?.let {
                        Spacer(Modifier.height(6.dp))
                        Text(it, color = MMColors.TextMuted, fontSize = 13.sp)
                    }
                }
            }
            legalNote?.let {
                Spacer(Modifier.height(10.dp))
                Text(it, color = MMColors.TextMuted, fontSize = 12.sp)
            }
            Spacer(Modifier.height(12.dp))
            MMButton(
                text = primaryTitle,
                onClick = onPrimary,
                enabled = primaryEnabled,
                loading = primaryLoading,
            )
        }
    }
}

@Composable
private fun MiniDocumentPreview() {
    Box(
        modifier = Modifier
            .size(width = 52.dp, height = 68.dp)
            .background(MMColors.PaperSurface.copy(0.92f), RoundedCornerShape(10.dp))
            .padding(8.dp),
    ) {
        Column {
            Box(
                Modifier
                    .width(28.dp)
                    .height(4.dp)
                    .background(MMColors.Primary.copy(0.7f), RoundedCornerShape(2.dp)),
            )
            Spacer(Modifier.height(5.dp))
            repeat(2) {
                Box(
                    Modifier
                        .padding(bottom = 3.dp)
                        .width(32.dp)
                        .height(3.dp)
                        .background(Color.Black.copy(0.08f), RoundedCornerShape(2.dp)),
                )
            }
        }
        Text(
            "PDF",
            color = MMColors.TextMuted,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.align(Alignment.BottomStart),
        )
    }
}
