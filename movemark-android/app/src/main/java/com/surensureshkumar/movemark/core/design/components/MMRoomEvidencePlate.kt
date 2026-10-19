/**
 * @file Room hero: the room's evidence plate, with the latest photo as the star
 * @domain design-system
 * @status wip
 * @see [[ROOM_EVIDENCE_RECORD]] — screen spec
 * @see [[VISUAL_STANDARD]] — hierarchy, type voices, glass rules
 * @see [[MMRoomEvidencePlate.swift]] — iOS reference implementation
 */
package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.SubcomposeAsyncImage
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Same order and wording as iOS `RoomRecord.ConditionRating` (1 = Poor … 5 = Excellent). */
private fun conditionLabel(rating: Int?): String? = when (rating) {
    1 -> "Poor"
    2 -> "Below fair"
    3 -> "Fair"
    4 -> "Good"
    5 -> "Excellent"
    else -> null
}

private val recordedFormat = DateTimeFormatter.ofPattern("MMM d · h:mm a", Locale.US)

private fun recordedLabel(raw: String?): String? {
    if (raw.isNullOrBlank()) return null
    val instant = runCatching { OffsetDateTime.parse(raw).toInstant() }
        .recoverCatching { Instant.parse(raw) }
        .getOrNull() ?: return null
    return recordedFormat.format(instant.atZone(ZoneId.systemDefault())).uppercase(Locale.US)
}

/**
 * Room hero. With saved photos for the phase it shows the latest one large, with chips
 * (condition, photo count, issues) and a mono "recorded" time; without photos it is an empty
 * capture surface reading "Still needs proof". It never adds a green action of its own.
 *
 * @param signPhotoUrl resolves a storage path to a signed URL (null on failure).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MMRoomEvidencePlate(
    roomName: String,
    room: RoomRecord?,
    proofPhase: ProofPhase,
    shotPrompts: List<String>,
    signPhotoUrl: suspend (String) -> String?,
    modifier: Modifier = Modifier,
) {
    val moveOut = proofPhase == ProofPhase.MoveOut
    val entries: List<EvidenceRecord> = when {
        room == null -> emptyList()
        moveOut -> room.moveOutEvidence
        else -> room.moveInEvidence
    }
    val latest = entries.filter { it.photos.isNotEmpty() }.maxByOrNull { it.createdAt.orEmpty() }
    val heroPath = latest?.photos?.firstOrNull()?.filePath
    val photoCount = entries.sumOf { it.photoCount }
    val issueCount = entries.sumOf { it.issueTagCount }

    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                if (moveOut) "MOVE-OUT EVIDENCE" else "MOVE-IN EVIDENCE",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.sp,
                color = MMColors.TextMuted,
            )
            Text(
                roomName,
                fontFamily = FontFamily.Serif,
                fontSize = 32.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.TextPrimary,
                modifier = Modifier.semantics { heading() },
            )
        }

        if (latest != null && heroPath != null) {
            PhotoPlate(
                path = heroPath,
                signPhotoUrl = signPhotoUrl,
                chips = listOfNotNull(
                    conditionLabel(latest.conditionRating),
                    if (photoCount == 1) "1 photo" else "$photoCount photos",
                    issueCount.takeIf { it > 0 }?.let { if (it == 1) "1 issue" else "$it issues" },
                ),
                description = "Latest $roomName photo",
            )
            recordedLabel(latest.createdAt)?.let { recorded ->
                // The timestamp never breaks mid-value; at large font scales it drops under its label.
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("RECORDED", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp, color = MMColors.TextMuted)
                    Text(recorded, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMColors.TextSecondary, softWrap = false)
                }
            }
        } else {
            EmptyPlate(moveOut = moveOut, shotPrompts = shotPrompts)
        }

        if (room != null) {
            val moveInPhotos = room.moveInEvidence.sumOf { it.photoCount }
            val moveOutPhotos = room.moveOutEvidence.sumOf { it.photoCount }
            if (moveInPhotos > 0 && moveOutPhotos > 0) {
                Text(
                    "MOVE-IN $moveInPhotos · MOVE-OUT $moveOutPhotos PHOTOS",
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    color = MMColors.TextMuted,
                )
            }
        }
    }
}

@Composable
private fun PhotoPlate(
    path: String,
    signPhotoUrl: suspend (String) -> String?,
    chips: List<String>,
    description: String,
) {
    val url by produceState<String?>(initialValue = null, path) { value = signPhotoUrl(path) }
    val shape = RoundedCornerShape(22.dp)
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(4f / 3f)
            .clip(shape)
            .background(MMColors.Card)
            .border(1.dp, Color.White.copy(alpha = 0.08f), shape)
            .semantics { contentDescription = "$description. ${chips.joinToString(", ")}" },
    ) {
        if (url != null) {
            SubcomposeAsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                error = {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.Image, contentDescription = null, tint = MMColors.TextMuted)
                    }
                },
            )
        }
        Row(
            Modifier
                .align(Alignment.BottomStart)
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            chips.forEach { GlassChip(it) }
        }
    }
}

/** Translucent chip over evidence (Compose has no backdrop blur; a dark scrim stands in). */
@Composable
private fun GlassChip(text: String) {
    Text(
        text,
        color = Color.White,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(Color.Black.copy(alpha = 0.45f))
            .border(0.5.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
private fun EmptyPlate(moveOut: Boolean, shotPrompts: List<String>) {
    val dash = MMColors.TextMuted.copy(alpha = 0.35f)
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 240.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(MMColors.Card.copy(alpha = 0.55f))
            .drawBehind {
                drawRoundRect(
                    color = dash,
                    cornerRadius = CornerRadius(22.dp.toPx()),
                    style = Stroke(width = 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 5.dp.toPx()))),
                )
            }
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.Bottom),
    ) {
        Icon(Icons.Outlined.CameraAlt, contentDescription = null, tint = MMColors.TextSecondary)
        Text("Still needs proof", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary)
        if (moveOut) {
            Text("Photograph each surface before you return the keys.", fontSize = 13.sp, color = MMColors.TextSecondary)
        } else {
            shotPrompts.forEach { Text(it, fontSize = 13.sp, color = MMColors.TextSecondary) }
        }
        Spacer(Modifier.height(0.dp))
    }
}
