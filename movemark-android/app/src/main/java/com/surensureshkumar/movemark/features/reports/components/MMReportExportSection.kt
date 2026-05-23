package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCard
import com.surensureshkumar.movemark.core.design.components.MMProofDocumentPreview

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
        MMProofCaseCard {
            Row(verticalAlignment = androidx.compose.ui.Alignment.Top) {
                MMProofDocumentPreview(large = false, isBright = primaryEnabled)
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
