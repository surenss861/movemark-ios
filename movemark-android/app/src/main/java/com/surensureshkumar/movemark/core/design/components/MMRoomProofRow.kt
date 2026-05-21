package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.RoomProofMetrics

@Composable
fun MMRoomProofRow(
    room: RoomRecord,
    index: Int,
    isNext: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val photoCount = RoomProofMetrics.photoCount(room)
    val documented = RoomProofMetrics.isDocumented(room)
    val status = when {
        documented -> "Ready to review"
        isNext -> "Next — needs photos"
        else -> "Needs photos"
    }
    val statusColor = when {
        documented -> MMColors.Primary
        isNext -> MMColors.SemanticWarning
        else -> MMColors.TextMuted
    }

    MMProofCard(
        modifier = modifier.padding(bottom = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "$index",
                    style = androidx.compose.material3.MaterialTheme.typography.labelMedium,
                    color = if (isNext) MMColors.Primary else MMColors.TextMuted,
                    modifier = Modifier.padding(end = 12.dp),
                )
                Column {
                    Text(room.name, style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
                    Text(
                        status,
                        style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
                        color = statusColor,
                    )
                }
            }
            Text(
                text = if (photoCount > 0) "$photoCount photos" else "0 photos",
                style = androidx.compose.material3.MaterialTheme.typography.labelMedium,
                color = MMColors.TextSecondary,
            )
        }
    }
}
