package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.scale
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.domain.RoomProofMetrics

@Composable
fun MMRoomProofRow(
    room: RoomRecord,
    index: Int,
    isNext: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    proofPhase: ProofPhase = ProofPhase.MoveIn,
) {
    val photoCount = RoomProofMetrics.photoCount(room, proofPhase)
    val documented = RoomProofMetrics.isDocumented(room, proofPhase)
    val detailLine = when {
        documented -> {
            val photos = if (photoCount == 1) "1 photo" else "$photoCount photos"
            "Ready to review · $photos"
        }
        isNext -> "Needs photos — tap to capture proof"
        else -> "Needs photos"
    }
    val statusColor = when {
        documented -> MMColors.Primary
        isNext -> MMColors.SemanticWarning
        else -> MMColors.TextMuted
    }

    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, label = "roomRowPress")

    MMProofCard(
        modifier = modifier
            .padding(bottom = 12.dp)
            .scale(scale)
            .clickable(interactionSource = interactionSource, indication = null, onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(
                        if (isNext) MMColors.Primary.copy(alpha = 0.16f)
                        else MMColors.TextMuted.copy(alpha = 0.12f),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "$index",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isNext) MMColors.Primary else MMColors.TextMuted,
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        room.name,
                        style = androidx.compose.material3.MaterialTheme.typography.titleMedium,
                        color = MMColors.TextPrimary,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    if (isNext && !documented) {
                        Spacer(Modifier.width(8.dp))
                        Text(
                            "Next",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.SemanticWarning,
                            modifier = Modifier
                                .background(
                                    MMColors.SemanticWarning.copy(alpha = 0.14f),
                                    CircleShape,
                                )
                                .border(
                                    0.85.dp,
                                    MMColors.SemanticWarning.copy(alpha = 0.45f),
                                    CircleShape,
                                )
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                        )
                    }
                }
                Spacer(Modifier.height(6.dp))
                AnimatedContent(
                    targetState = detailLine,
                    transitionSpec = { fadeIn() togetherWith fadeOut() },
                    label = "roomStatus",
                ) { line ->
                    Text(
                        line,
                        fontSize = 13.sp,
                        color = statusColor,
                    )
                }
            }
            Icon(
                imageVector = if (documented) Icons.Default.CheckCircle else Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = if (documented) MMColors.Primary else MMColors.TextSecondary,
                modifier = Modifier.size(if (documented) 22.dp else 18.dp),
            )
        }
    }
}
