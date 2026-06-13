package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMProofCard

enum class ChecklistItemState { Complete, Incomplete, Locked }

data class ReportChecklistItem(
    val title: String,
    val detail: String,
    val state: ChecklistItemState,
)

@Composable
fun MMReportReadinessChecklist(
    items: List<ReportChecklistItem>,
    appeared: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        Text(
            "Proof checklist",
            color = MMColors.TextMuted,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 2.dp, bottom = 10.dp),
        )
        MMProofCard {
            items.forEachIndexed { index, item ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(vertical = 6.dp),
                        color = Color.White.copy(alpha = 0.06f),
                    )
                }
                ChecklistRow(
                    item = item,
                    modifier = Modifier.mmAppearRise(
                        visible = appeared,
                        reduceMotion = reduceMotion,
                        label = "checklist$index",
                    ),
                )
            }
        }
    }
}

@Composable
private fun ChecklistRow(
    item: ReportChecklistItem,
    modifier: Modifier = Modifier,
) {
    val iconColor = when (item.state) {
        ChecklistItemState.Complete -> MMColors.Primary.copy(0.9f)
        ChecklistItemState.Incomplete -> MMColors.SemanticWarning.copy(0.85f)
        ChecklistItemState.Locked -> MMColors.TextMuted.copy(0.45f)
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 1.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = when (item.state) {
                ChecklistItemState.Complete -> Icons.Filled.CheckCircle
                ChecklistItemState.Locked -> Icons.Filled.Lock
                ChecklistItemState.Incomplete -> Icons.Outlined.Circle
            },
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(
                item.title,
                color = if (item.state == ChecklistItemState.Locked) {
                    MMColors.TextMuted
                } else {
                    MMColors.TextPrimary.copy(0.92f)
                },
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
            )
            Text(item.detail, color = MMColors.TextMuted, fontSize = 12.sp)
        }
    }
}
