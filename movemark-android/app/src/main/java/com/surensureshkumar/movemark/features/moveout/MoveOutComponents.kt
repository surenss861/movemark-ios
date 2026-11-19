package com.surensureshkumar.movemark.features.moveout

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.domain.MoveOutComparison
import com.surensureshkumar.movemark.domain.MoveOutComparison.State
import com.surensureshkumar.movemark.features.proof.rememberSignedUrl

/*
 * MoveMark — the move-out comparison's pieces (iOS Shared/MMSystem+MoveOut.swift): state mark, photo side,
 * spread card for a changed room, missing card and row, compact expandable row, tally and header progress.
 */

enum class MoveOutSide { MoveIn, MoveOut }

internal typealias SignPhoto = suspend (String) -> String?

private val CardShape = RoundedCornerShape(18.dp)

/** True when the system font is scaled to an accessibility size (iOS `isAccessibilitySize`). */
@Composable
internal fun isLargeFont(): Boolean = LocalDensity.current.fontScale >= 1.5f

/** The state as the first thing read on a room: a small mark and a plain word. Amber for change, never red. */
@Composable
fun MoveOutStateMark(state: State) {
    val attention = state == State.NewIssue || state == State.Changed
    Row(verticalAlignment = Alignment.CenterVertically) {
        val mark = Modifier.size(9.dp)
        when (state) {
            State.NewIssue -> Box(mark.background(MMColors.SemanticWarning, CircleShape))
            State.Changed -> Box(mark.border(1.75.dp, MMColors.SemanticWarning, CircleShape))
            State.Missing, State.NoBaseline -> Box(mark.border(1.25.dp, MMColors.TextSecondary, CircleShape))
            State.Unchanged -> Box(mark.background(MMColors.TextSecondary.copy(alpha = 0.55f), CircleShape))
        }
        Spacer(Modifier.width(7.dp))
        Text(
            state.label.uppercase(),
            fontSize = 11.5.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.6.sp,
            color = if (attention) MMColors.SemanticWarning else MMColors.TextSecondary,
        )
    }
}

@Composable
private fun SideLabel(label: String, day: String?) {
    Text(
        if (day != null) "$label · ${day.uppercase()}" else label,
        fontSize = 10.5.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.8.sp,
        fontFamily = FontFamily.Monospace,
        color = MMColors.TextSecondary,
    )
}

/** One side's photo: fills its frame, opens the viewer, shows the side's photo count. */
@Composable
private fun MoveOutPhoto(
    side: MoveOutSide,
    photo: EvidencePhoto?,
    count: Int,
    height: Dp,
    sign: SignPhoto,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val sideName = if (side == MoveOutSide.MoveIn) "Move-in" else "Move-out"
    val frame = modifier
        .fillMaxWidth()
        .height(height)
        .clip(RoundedCornerShape(12.dp))
        .background(MMColors.FieldFill)
    if (photo == null) {
        Box(frame.border(1.dp, MMColors.CardStroke, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            Text(if (count > 0) "$count photos" else "No photo", fontSize = 13.sp, color = MMColors.TextSecondary)
        }
        return
    }
    val url by rememberSignedUrl(photo.thumbnailPath ?: photo.filePath) {
        sign(photo.thumbnailPath ?: photo.filePath) ?: sign(photo.filePath)
    }
    Box(
        frame
            .clickable(onClickLabel = "Open $sideName photos", role = Role.Image, onClick = onOpen)
            .semantics(mergeDescendants = true) {
                contentDescription = if (count > 1) "$sideName photo, $count photos" else "$sideName photo"
            },
    ) {
        AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        if (count > 1) {
            Text(
                "$count",
                fontSize = 11.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(8.dp)
                    .background(Color.Black.copy(alpha = 0.55f), CircleShape)
                    .padding(horizontal = 7.dp, vertical = 3.dp),
            )
        }
    }
}

/** MOVE-IN · date | MOVE-OUT · date above two photos side by side, condition under each (iOS `MMComparisonPair`). */
@Composable
private fun ComparisonPair(item: MoveOutComparison, photoHeight: Dp, sign: SignPhoto, onOpen: (MoveOutSide) -> Unit) {
    val stack = isLargeFont()
    val sides = listOf(MoveOutSide.MoveIn, MoveOutSide.MoveOut)
    @Composable
    fun Side(side: MoveOutSide, modifier: Modifier) {
        val moveIn = side == MoveOutSide.MoveIn
        Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            SideLabel(if (moveIn) "MOVE-IN" else "MOVE-OUT", MoveOutComparison.day(if (moveIn) item.moveInDate else item.moveOutDate))
            MoveOutPhoto(
                side = side,
                photo = if (moveIn) item.moveInPhoto else item.moveOutPhoto,
                count = if (moveIn) item.moveInPhotoCount else item.moveOutPhotoCount,
                height = photoHeight,
                sign = sign,
                onOpen = { onOpen(side) },
            )
            (if (moveIn) item.moveInCondition else item.moveOutCondition)?.let {
                Text(MoveOutComparison.conditionLabel(it), fontSize = 13.sp, color = MMColors.TextPrimary)
            }
        }
    }
    if (stack) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) { sides.forEach { Side(it, Modifier.fillMaxWidth()) } }
    } else {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { sides.forEach { Side(it, Modifier.weight(1f)) } }
    }
}

private fun viewerActions(item: MoveOutComparison, onOpen: (MoveOutSide) -> Unit) = buildList {
    if (item.moveInPhoto != null) add(CustomAccessibilityAction("View move-in photo") { onOpen(MoveOutSide.MoveIn); true })
    if (item.moveOutPhoto != null) add(CustomAccessibilityAction("View move-out photo") { onOpen(MoveOutSide.MoveOut); true })
}

@Composable
private fun JustCompared() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Check, contentDescription = null, tint = MMColors.TextPrimary, modifier = Modifier.size(12.dp))
        Spacer(Modifier.width(4.dp))
        Text("Compared just now", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary)
    }
}

/** A room whose move-out record differs from move-in: state, room, what changed, both sides, the move-out note. */
@Composable
fun MoveOutSpreadCard(item: MoveOutComparison, sign: SignPhoto, justCompared: Boolean, onOpen: (MoveOutSide) -> Unit) {
    val details = buildList {
        if (item.state == State.NewIssue) item.conditionLine?.let(::add)
        item.moveOutText?.let { add("Move-out note: “$it”") }
    }
    Column(
        Modifier
            .fillMaxWidth()
            .background(MMColors.EvidenceCard, CardShape)
            .border(0.75.dp, MMColors.CardStroke, CardShape)
            .semantics { customActions = viewerActions(item, onOpen) }
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            MoveOutStateMark(item.state)
            Spacer(Modifier.weight(1f))
            if (justCompared) JustCompared()
        }
        Text(
            item.roomName,
            fontSize = 21.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextPrimary,
            modifier = Modifier.padding(top = 6.dp).semantics { heading() },
        )
        item.headline?.let {
            Text(it, fontSize = 15.5.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary, modifier = Modifier.padding(top = 3.dp))
        }
        Spacer(Modifier.height(18.dp))
        ComparisonPair(item, if (isLargeFont()) 200.dp else 236.dp, sign, onOpen)
        if (details.isNotEmpty()) {
            Column(
                Modifier
                    .padding(top = 14.dp)
                    .fillMaxWidth()
                    .background(MMColors.FieldFill, RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                details.forEach { Text(it, fontSize = 13.5.sp, color = MMColors.TextPrimary) }
            }
        }
    }
}

/** A room still waiting for its move-out side: the move-in photo it will be compared with, then the capture action. */
@Composable
fun MoveOutMissingCard(item: MoveOutComparison, sign: SignPhoto, isPrimary: Boolean, onOpen: (MoveOutSide) -> Unit, onCapture: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MMColors.EvidenceCard, CardShape)
            .border(BorderStroke(1.dp, MMColors.CardStroke), CardShape)
            .semantics { customActions = viewerActions(item, onOpen) }
            .padding(14.dp),
    ) {
        MoveOutStateMark(State.Missing)
        Text(
            item.roomName,
            fontSize = 19.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextPrimary,
            modifier = Modifier.padding(top = 6.dp).semantics { heading() },
        )
        Spacer(Modifier.height(12.dp))
        SideLabel("MOVE-IN", MoveOutComparison.day(item.moveInDate))
        Spacer(Modifier.height(6.dp))
        MoveOutPhoto(MoveOutSide.MoveIn, item.moveInPhoto, item.moveInPhotoCount, 150.dp, sign, { onOpen(MoveOutSide.MoveIn) })
        item.moveInCondition?.let {
            Text(MoveOutComparison.conditionLabel(it), fontSize = 13.sp, color = MMColors.TextPrimary, modifier = Modifier.padding(top = 6.dp))
        }
        HorizontalDivider(Modifier.padding(top = 14.dp), thickness = 0.75.dp, color = MMColors.CardStroke)
        Row(Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            SideLabel("MOVE-OUT", null)
            Spacer(Modifier.width(10.dp))
            Text("No proof recorded yet", fontSize = 14.sp, color = MMColors.TextSecondary)
        }
        if (isPrimary) {
            MMButton(text = "Capture move-out proof", onClick = onCapture, modifier = Modifier.padding(top = 14.dp))
        } else {
            CaptureLink(onCapture)
        }
    }
}

@Composable
private fun CaptureLink(onCapture: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clickable(role = Role.Button, onClick = onCapture),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.PhotoCamera, contentDescription = null, tint = MMColors.TextPrimary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(7.dp))
        Text("Capture move-out proof", fontSize = 15.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MMColors.TextMuted)
    }
}

/** A further room waiting for move-out proof: a quiet row, not another empty spread. */
@Composable
fun MoveOutMissingRow(item: MoveOutComparison, onCapture: () -> Unit) {
    val moveIn = MoveOutComparison.day(item.moveInDate)?.let { "Move-in $it" } ?: "No move-in photos"
    val detail = "Move-out proof needed · $moveIn"
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clickable(onClickLabel = "Capture move-out proof", role = Role.Button, onClick = onCapture)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(item.roomName, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary)
            Text(detail, fontSize = 13.sp, color = MMColors.TextSecondary)
        }
        Icon(Icons.Filled.PhotoCamera, contentDescription = null, tint = MMColors.TextPrimary, modifier = Modifier.size(18.dp))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MMColors.TextMuted)
    }
}

/** A room that reads the same at both ends, compressed; tap to expand to the full pair. */
@Composable
fun MoveOutCompactRow(item: MoveOutComparison, sign: SignPhoto, justCompared: Boolean, onOpen: (MoveOutSide) -> Unit) {
    var expanded by rememberSaveable(item.id) { mutableStateOf(false) }
    val dates = listOfNotNull(
        MoveOutComparison.day(item.moveInDate)?.let { "Move-in $it" } ?: if (item.state == State.NoBaseline) "No move-in photos" else null,
        MoveOutComparison.day(item.moveOutDate)?.let { "Move-out $it" },
    ).joinToString(" · ")
    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 60.dp)
                .clickable(
                    onClickLabel = if (expanded) "Hide the photos" else "Show move-in and move-out photos side by side",
                    role = Role.Button,
                ) { expanded = !expanded }
                .semantics(mergeDescendants = true) {}
                .padding(horizontal = 16.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(item.roomName, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (item.state == State.Unchanged) {
                        Icon(Icons.Filled.Check, contentDescription = null, tint = MMColors.TextSecondary, modifier = Modifier.size(12.dp))
                        Spacer(Modifier.width(4.dp))
                    }
                    Text(
                        if (justCompared) "${item.state.label} · compared just now" else item.state.label,
                        fontSize = 13.sp,
                        color = MMColors.TextSecondary,
                    )
                }
                if (dates.isNotEmpty()) Text(dates, fontSize = 12.5.sp, color = MMColors.TextSecondary)
            }
            Icon(
                if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                contentDescription = null,
                tint = MMColors.TextMuted,
            )
        }
        AnimatedVisibility(expanded) {
            Box(
                Modifier
                    .padding(start = 16.dp, end = 16.dp, bottom = 16.dp)
                    .semantics { customActions = viewerActions(item, onOpen) },
            ) {
                ComparisonPair(item, 170.dp, sign, onOpen)
            }
        }
    }
}

/** The page's index: how many rooms changed, still need move-out proof, are unchanged. Tap to jump there. */
@Composable
fun MoveOutTally(changed: Int, missing: Int, unchanged: Int, onSelect: (Int) -> Unit) {
    val items = listOf("Changed" to changed, "Need proof" to missing, "Unchanged" to unchanged)
    @Composable
    fun Item(index: Int, modifier: Modifier) {
        val (label, count) = items[index]
        Column(
            modifier
                .heightIn(min = 48.dp)
                .clickable(enabled = count > 0, onClickLabel = "Move to these rooms", role = Role.Button) { onSelect(index) }
                .semantics(mergeDescendants = true) {},
        ) {
            Text("$count", fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = if (count == 0) MMColors.TextMuted else MMColors.TextPrimary)
            Text(label, fontSize = 12.5.sp, color = MMColors.TextSecondary)
        }
    }
    if (isLargeFont()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { items.indices.forEach { Item(it, Modifier.fillMaxWidth()) } }
    } else {
        Row { items.indices.forEach { Item(it, Modifier.weight(1f)) } }
    }
}

/** Move-out progress: label and percentage, a thin line, and the count it stands for. */
@Composable
fun MoveOutHeaderProgress(done: Int, total: Int) {
    val fraction = if (total == 0) 0f else done.toFloat() / total
    Column(
        Modifier.semantics(mergeDescendants = true) { contentDescription = "Move-out proof: $done of $total rooms captured" },
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Row {
            Text("Move-out proof", fontSize = 12.5.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary, modifier = Modifier.weight(1f))
            Text("${(fraction * 100).toInt()}%", fontSize = 12.5.sp, fontWeight = FontWeight.Medium, color = MMColors.TextSecondary)
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(4.dp)
                .background(Color.White.copy(alpha = 0.16f), CircleShape),
        ) {
            if (done > 0) {
                Box(
                    Modifier
                        .fillMaxWidth(fraction.coerceAtLeast(0.02f))
                        .height(4.dp)
                        .background(MMColors.Primary, CircleShape),
                )
            }
        }
        Text("$done of $total rooms captured", fontSize = 12.5.sp, color = MMColors.TextSecondary)
    }
}
