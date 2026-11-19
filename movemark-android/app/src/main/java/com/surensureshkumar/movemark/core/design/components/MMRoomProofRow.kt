package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
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
    val issueCount = RoomProofMetrics.issueTagCount(room, proofPhase)
    val detailLine = when {
        documented -> {
            val parts = mutableListOf(if (photoCount == 1) "1 photo" else "$photoCount photos")
            if (issueCount > 0) {
                parts += if (issueCount == 1) "1 issue" else "$issueCount issues"
            }
            parts += "Documented"
            parts.joinToString(" · ")
        }
        else -> "Needs proof"
    }

    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.985f else 1f, label = "roomRowPress")

    if (isNext && !documented) {
        MMCaseFilePlate(
            modifier = modifier
                .padding(bottom = 8.dp)
                .scale(scale)
                .clickable(interactionSource = interactionSource, indication = null, onClick = onClick),
            emphasis = true,
        ) {
            Text(
                "CURRENT ROOM",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.15.sp,
                color = MMColors.Primary,
            )
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "%02d".format(index),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    color = MMColors.Primary,
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    room.name,
                    fontFamily = FontFamily.Serif,
                    fontSize = 28.sp,
                    color = MMColors.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(detailLine, fontSize = 14.sp, color = MMColors.TextSecondary)
            Spacer(Modifier.height(12.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(2.dp)
                    .clip(RoundedCornerShape(1.dp))
                    .background(Color.White.copy(alpha = 0.08f)),
            )
        }
    } else {
        Column(modifier) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .scale(scale)
                .clickable(interactionSource = interactionSource, indication = null, onClick = onClick)
                .padding(horizontal = 4.dp, vertical = if (documented) 10.dp else 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "%02d".format(index),
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                color = MMColors.TextMuted,
                modifier = Modifier.width(28.dp),
            )
            Column(Modifier.weight(1f)) {
                Text(
                    room.name,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (documented) MMColors.TextPrimary.copy(alpha = 0.82f) else MMColors.TextSecondary,
                    maxLines = 2,
                )
                AnimatedContent(
                    targetState = detailLine,
                    transitionSpec = { fadeIn() togetherWith fadeOut() },
                    label = "roomStatus",
                ) { line ->
                    Text(line, fontSize = 12.sp, color = MMColors.TextMuted, maxLines = 2)
                }
            }
            Icon(
                imageVector = if (documented) Icons.Default.CheckCircle else Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = if (documented) MMColors.Primary else MMColors.TextMuted.copy(alpha = 0.7f),
                modifier = Modifier.padding(start = 8.dp),
            )
        }
        if (documented) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(start = 32.dp, bottom = 6.dp)
                    .height(2.dp)
                    .clip(RoundedCornerShape(1.dp))
                    .background(MMColors.Primary.copy(alpha = 0.85f)),
            )
        }
        }
    }
}
