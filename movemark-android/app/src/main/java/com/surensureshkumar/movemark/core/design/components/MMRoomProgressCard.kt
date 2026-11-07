package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

@Composable
fun MMRoomProgressCard(
    headline: String,
    nextLine: String,
    progress: Float,
    primaryTitle: String,
    onPrimary: () -> Unit,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    progressLabel: String? = null,
    documentedCount: Int? = null,
    totalCount: Int? = null,
) {
    val showsFigure = documentedCount != null && totalCount != null && totalCount > 0

    MMCaseFilePlate(modifier = modifier, emphasis = false) {
        if (showsFigure) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                MMCoverageFigure(
                    documented = documentedCount,
                    total = totalCount,
                    modifier = Modifier.weight(1f),
                )
                MMCoverageRing(
                    progress = progress,
                    reduceMotion = reduceMotion,
                    size = 58.dp,
                    modifier = Modifier.padding(start = 8.dp),
                )
            }
        } else {
            Text(headline, fontSize = 17.sp, color = MMColors.TextPrimary)
        }
        Spacer(Modifier.height(8.dp))
        Text(nextLine, fontSize = 14.sp, color = MMColors.TextSecondary)
        if (!progressLabel.isNullOrBlank()) {
            Spacer(Modifier.height(6.dp))
            Text(progressLabel, fontSize = 12.sp, color = MMColors.TextMuted)
        }
        Spacer(Modifier.height(14.dp))
        MMButton(text = primaryTitle, onClick = onPrimary)
    }
}
