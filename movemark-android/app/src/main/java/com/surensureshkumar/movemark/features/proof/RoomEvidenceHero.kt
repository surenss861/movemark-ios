/**
 * @file Room hero — light page header (stage, room, recorded) with the latest photo in a rounded card and a
 *       filmstrip, or the empty capture field
 * @domain proof-capture
 * @status wip
 * @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4 composition)
 * @see [[RoomEvidenceHero.swift]] — iOS reference implementation
 */
package com.surensureshkumar.movemark.features.proof

import androidx.compose.ui.platform.testTag
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.font.FontStyle
import com.surensureshkumar.movemark.core.design.MMEyebrowStyle
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmLines
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.SubcomposeAsyncImage
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** What to photograph in an empty room — same list as iOS `RoomCapturePrompts`. */
val RoomCapturePrompts = listOf(
    "A wide shot from the doorway",
    "Walls and baseboards",
    "Floors",
    "Windows / blinds",
)

private val recordedFormat = DateTimeFormatter.ofPattern("MMM d · h:mm a", Locale.US)

/** "OCT 19 · 6:37 PM" from an ISO timestamp, in the device zone. */
fun recordedLabel(raw: String?): String? {
    if (raw.isNullOrBlank()) return null
    val instant = runCatching { OffsetDateTime.parse(raw).toInstant() }
        .recoverCatching { Instant.parse(raw) }
        .getOrNull() ?: return null
    return recordedFormat.format(instant.atZone(ZoneId.systemDefault())).uppercase(Locale.US)
}

/** Newest entry first, then each entry's photos in capture order. The viewer pages in this order too. */
fun orderedRoomPhotos(entries: List<EvidenceRecord>): List<Pair<EvidencePhoto, EvidenceRecord>> =
    entries.sortedByDescending { it.createdAt.orEmpty() }.flatMap { entry -> entry.photos.map { it to entry } }

/** Legacy full-bleed hero height (kept for callers; the light hero sizes its photo card by aspect ratio). */
fun roomHeroHeight(width: Dp, screenHeight: Dp): Dp = minOf(width * 1.35f, screenHeight * 0.66f)

/** How far the page scrolls before the room title has left and settles into the pinned bar. */
val RoomHeroTitleScrollAway: Dp = 120.dp

fun conditionLabel(rating: Int?): String =
    RoomConditionLabels.firstOrNull { it.first == rating }?.second ?: "Not rated"

/** Space the pinned [RoomTopBar] takes over the page (status bar + bar row). */
@Composable
private fun topBarClearance(): Dp = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 64.dp

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RoomEvidenceHero(
    roomName: String,
    entries: List<EvidenceRecord>,
    proofPhase: ProofPhase,
    signPhotoUrl: suspend (String) -> String?,
    onOpenPhoto: (EvidencePhoto) -> Unit,
    hasPendingPhotos: Boolean,
    isBusy: Boolean,
    onTakePhotos: () -> Unit,
    onChooseGallery: () -> Unit,
    compareLine: String?,
    /** The room's true photo total for this stage (loaded entries plus the unloaded remainder). */
    totalPhotoCount: Int? = null,
    /** Page scroll in px. Unused by the light hero (no parallax photo); kept so callers stay unchanged. */
    @Suppress("UNUSED_PARAMETER") scrollOffset: () -> Int = { 0 },
    modifier: Modifier = Modifier,
) {
    val allPhotos = orderedRoomPhotos(entries)
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val current = allPhotos.firstOrNull { it.first.id.toString() == selectedId } ?: allPhotos.firstOrNull()

    if (current == null) {
        EmptyField(roomName, proofPhase, hasPendingPhotos, isBusy, onTakePhotos, onChooseGallery, modifier)
        return
    }

    val (photo, entry) = current
    val photoCount = totalPhotoCount ?: entries.sumOf { it.photoCount }
    val issueCount = entries.flatMap { it.issueTags }.toSet().size
    val moveOut = proofPhase == ProofPhase.MoveOut

    Column(
        modifier
            .fillMaxWidth()
            .background(MMInk.Sheet)
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
            // Clears the pinned RoomTopBar.
            .padding(top = topBarClearance()),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Ink header on the light page: stage, room, provenance.
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(if (moveOut) "MOVE-OUT EVIDENCE" else "MOVE-IN EVIDENCE", style = MMEyebrowStyle, color = MMInk.Secondary)
            Text(
                roomName,
                style = mmFont(34f, FontWeight.Bold),
                lineHeight = 38.sp,
                color = MMInk.Text,
                modifier = Modifier.semantics { heading() },
            )
            recordedLabel(entry.createdAt)?.let { RecordedLine(it) }
        }

        // The latest photo, properly sized in a rounded card (never full-bleed, never behind text).
        val cardShape = RoundedCornerShape(MMMetrics.CardRadius)
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(4f / 3f)
                .clip(cardShape)
                .background(MMInk.ThumbFill)
                .border(0.75.dp, MMInk.CardStroke, cardShape)
                .clickable(role = Role.Button, onClickLabel = "Open photo full screen") { onOpenPhoto(photo) },
        ) {
            Crossfade(targetState = photo, animationSpec = tween(350), label = "heroPhoto") { shown ->
                HeroImage(shown, signPhotoUrl)
            }
        }

        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOfNotNull(
                HeroChip(conditionLabel(entry.conditionRating), Icons.Filled.CheckCircle, MMInk.Text),
                HeroChip(if (photoCount == 1) "1 photo" else "$photoCount photos", Icons.Outlined.PhotoLibrary, MMInk.Secondary),
                issueCount.takeIf { it > 0 }?.let {
                    HeroChip(if (it == 1) "1 issue" else "$it issues", Icons.Filled.Warning, MMInk.Warning)
                },
            ).forEach { InfoChip(it) }
        }

        if (allPhotos.size > 1) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(allPhotos, key = { it.first.id }) { (thumb, _) ->
                    val isSelected = thumb.id == photo.id
                    FilmstripThumb(
                        photo = thumb,
                        isSelected = isSelected,
                        signPhotoUrl = signPhotoUrl,
                        onClick = { selectedId = thumb.id.toString() },
                    )
                }
            }
        }

        AddEvidencePill(isBusy, onTakePhotos, onChooseGallery, Modifier.padding(top = 2.dp), quiet = hasPendingPhotos || isBusy)

        compareLine?.let {
            Text(it, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMInk.Secondary)
        }
    }
}

@Composable
private fun HeroImage(photo: EvidencePhoto, signPhotoUrl: suspend (String) -> String?) {
    val url by rememberSignedUrl(photo.filePath) { signPhotoUrl(photo.filePath) }
    Box(Modifier.fillMaxSize().background(MMInk.ThumbFill), contentAlignment = Alignment.Center) {
        if (url != null) {
            SubcomposeAsyncImage(
                model = url,
                contentDescription = "Latest evidence photo of this room",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                loading = { PhotoPlaceholder() },
                error = { PhotoPlaceholder("Photo unavailable") },
            )
        } else {
            PhotoPlaceholder()
        }
    }
}

/** The explicit neutral placeholder: grey fill and a photo glyph (never the brand mark posing as a photo). */
@Composable
private fun PhotoPlaceholder(caption: String? = null) {
    Column(
        Modifier.fillMaxSize().background(MMInk.ThumbFill),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Outlined.Image, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(28.dp))
        caption?.let {
            Text(it, color = MMInk.Secondary, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

/**
 * Pinned over the screen: a light bar on the page colour with an ink back button and the stage pill; once the
 * page title has scrolled away the room name settles in and a hairline appears under the bar.
 */
@Composable
fun RoomTopBar(roomName: String, phase: ProofPhase, onBack: () -> Unit, scrolledAway: Boolean) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val fill by animateFloatAsState(if (scrolledAway) 1f else 0f, tween(200), label = "barFill")
    Column(Modifier.fillMaxWidth().background(MMInk.Sheet)) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(top = top + 4.dp, start = 4.dp, end = 16.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = MMInk.Text)
            }
            Text(
                roomName,
                color = MMInk.Text,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = mmLines(2),
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 8.dp)
                    .alpha(fill),
            )
            Text(
                if (phase == ProofPhase.MoveOut) "Move-out" else "Move-in",
                color = MMInk.Text,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(MMInk.Card)
                    .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(50))
                    .padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }
        Box(Modifier.fillMaxWidth().height(0.75.dp).alpha(fill).background(MMInk.Separator))
    }
}

private data class HeroChip(val text: String, val icon: ImageVector, val tint: Color)

/** A documented room's next action: the lime pill, as on iOS RC5 (lime is the screen's one action). */
@Composable
private fun AddEvidencePill(
    isBusy: Boolean,
    onTakePhotos: () -> Unit,
    onChooseGallery: () -> Unit,
    modifier: Modifier = Modifier,
    /** Photos are waiting or uploading: the save bar carries the one lime action, so this pill goes quiet. */
    quiet: Boolean = false,
) {
    var open by remember { mutableStateOf(false) }
    val ink = if (quiet) MMInk.Text else MMInk.OnLime
    Box(modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 50.dp)
                .clip(RoundedCornerShape(50))
                .then(
                    if (quiet) Modifier.background(MMInk.Card).border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(50))
                    else Modifier.background(MMInk.Lime.copy(alpha = if (isBusy) 0.5f else 1f)),
                )
                .clickable(enabled = !isBusy, role = Role.Button) { open = true }
                .testTag(if (quiet) "room.addEvidence.quiet" else "room.addEvidence")
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.PhotoCamera, contentDescription = null, tint = ink.copy(alpha = if (isBusy) 0.5f else 1f), modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("Add evidence", color = ink.copy(alpha = if (isBusy) 0.5f else 1f), fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text("Take photos", color = MMInk.Text) },
                leadingIcon = { Icon(Icons.Outlined.PhotoCamera, contentDescription = null, tint = MMInk.Text) },
                onClick = { open = false; onTakePhotos() },
            )
            DropdownMenuItem(
                text = { Text("Choose from library", color = MMInk.Text) },
                leadingIcon = { Icon(Icons.Outlined.PhotoLibrary, contentDescription = null, tint = MMInk.Text) },
                onClick = { open = false; onChooseGallery() },
            )
        }
    }
}

/** A quiet white chip on the page: icon, ink text, hairline border. */
@Composable
private fun InfoChip(chip: HeroChip) {
    Row(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(chip.icon, contentDescription = null, tint = chip.tint, modifier = Modifier.size(14.dp))
        Text(chip.text, color = MMInk.Text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun RecordedLine(value: String) {
    // The timestamp never breaks mid-value; at large font scales it drops under its label.
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Kicker("RECORDED", MMInk.Secondary)
        Text(
            value,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = MMInk.Secondary,
            softWrap = false,
        )
    }
}

@Composable
private fun FilmstripThumb(
    photo: EvidencePhoto,
    isSelected: Boolean,
    signPhotoUrl: suspend (String) -> String?,
    onClick: () -> Unit,
) {
    val path = photo.thumbnailPath ?: photo.filePath
    val url by rememberSignedUrl(path) { signPhotoUrl(path) ?: signPhotoUrl(photo.filePath) }
    val shape = RoundedCornerShape(12.dp)
    Box(
        Modifier
            .size(64.dp)
            .clip(shape)
            .background(MMInk.ThumbFill)
            .border(BorderStroke(if (isSelected) 2.dp else 0.75.dp, if (isSelected) MMInk.Text else MMInk.CardStroke), shape)
            .alpha(if (isSelected) 1f else 0.8f)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics {
                selected = isSelected
                contentDescription = "Evidence photo"
            },
        contentAlignment = Alignment.Center,
    ) {
        if (url != null) {
            SubcomposeAsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                loading = { ThumbGlyph() },
                error = { ThumbGlyph() },
            )
        } else {
            ThumbGlyph()
        }
    }
}

@Composable
private fun ThumbGlyph() {
    Box(Modifier.fillMaxSize().background(MMInk.ThumbFill), contentAlignment = Alignment.Center) {
        Icon(Icons.Outlined.Image, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(20.dp))
    }
}

/**
 * A room with no proof yet (iOS RC5 room screen): the light header (stage, room, "No proof yet") on the page, then
 * a white viewfinder card, what to capture, and the one lime action.
 */
@Composable
private fun EmptyField(
    roomName: String,
    proofPhase: ProofPhase,
    hasPendingPhotos: Boolean,
    isBusy: Boolean,
    onTakePhotos: () -> Unit,
    onChooseGallery: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val moveOut = proofPhase == ProofPhase.MoveOut
    Column(
        modifier
            .fillMaxWidth()
            .background(MMInk.Sheet)
            .padding(horizontal = MMMetrics.Inset)
            // Clears the pinned RoomTopBar.
            .padding(top = topBarClearance())
            .padding(bottom = 24.dp),
    ) {
        Text(if (moveOut) "MOVE-OUT EVIDENCE" else "MOVE-IN EVIDENCE", style = MMEyebrowStyle, color = MMInk.Secondary)
        Text(
            roomName,
            style = mmFont(34f, FontWeight.Bold),
            color = MMInk.Text,
            modifier = Modifier
                .padding(top = 6.dp)
                .semantics { heading() },
        )
        Text("No proof yet", style = mmFont(17f), color = MMInk.Secondary, modifier = Modifier.padding(top = 4.dp))
        Spacer(Modifier.height(22.dp))
        ViewfinderField(
            if (moveOut) "This room’s move-out record starts with your first photo."
            else "This room’s record starts with your first photo.",
        )
        Text(
            if (moveOut) "Capture these before you return the keys" else "Capture these before you unpack",
            style = mmFont(14.5f),
            color = MMInk.Secondary,
            modifier = Modifier.padding(top = 22.dp, bottom = 8.dp),
        )
        RoomCapturePrompts.forEachIndexed { index, prompt ->
            Box(Modifier.fillMaxWidth().height(0.75.dp).background(MMInk.Separator))
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "%02d".format(index + 1),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    color = MMInk.Secondary,
                    modifier = Modifier.width(36.dp),
                )
                Text(prompt, style = mmFont(16.5f), color = MMInk.Text)
            }
        }
        Spacer(Modifier.height(24.dp))
        // Lime only while it's the screen's one action; once photos are picked the save bar takes it.
        if (hasPendingPhotos) {
            MMSecondaryButton(title = "Take photos", icon = Icons.Filled.PhotoCamera, onClick = onTakePhotos, enabled = !isBusy)
        } else {
            MMPrimaryButton(title = "Take photos", icon = Icons.Filled.PhotoCamera, onClick = onTakePhotos, enabled = !isBusy)
        }
        Spacer(Modifier.height(6.dp))
        MMSecondaryButton(title = "Choose from gallery", onClick = onChooseGallery, enabled = !isBusy)
    }
}

/** A white card with grey viewfinder corners and one quiet line: the room's record hasn't started yet. */
@Composable
private fun ViewfinderField(line: String) {
    val shape = RoundedCornerShape(MMMetrics.CardRadius)
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(1.8f)
            .clip(shape)
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, shape)
            .drawBehind {
                val inset = 14.dp.toPx()
                val len = 18.dp.toPx()
                val stroke = 1.5.dp.toPx()
                val c = MMInk.Secondary.copy(alpha = 0.55f)
                val w = size.width
                val h = size.height
                listOf(
                    Triple(inset, inset, 1f to 1f),
                    Triple(w - inset, inset, -1f to 1f),
                    Triple(inset, h - inset, 1f to -1f),
                    Triple(w - inset, h - inset, -1f to -1f),
                ).forEach { (x, y, dir) ->
                    drawLine(c, Offset(x, y), Offset(x + len * dir.first, y), stroke)
                    drawLine(c, Offset(x, y), Offset(x, y + len * dir.second), stroke)
                }
            },
        contentAlignment = Alignment.BottomCenter,
    ) {
        Text(
            line,
            fontFamily = FontFamily.Serif,
            fontStyle = FontStyle.Italic,
            fontSize = 17.sp,
            color = MMInk.Secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 36.dp),
        )
    }
}

@Composable
fun Kicker(text: String, color: Color) {
    Text(text, color = color, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
}

/**
 * A signed URL for [key], fetched once per key. (Replaces `produceState`, whose lint check misfires on a
 * suspend-lambda producer.)
 */
@Composable
internal fun rememberSignedUrl(key: Any?, sign: suspend () -> String?): androidx.compose.runtime.State<String?> {
    val state = androidx.compose.runtime.remember(key) { androidx.compose.runtime.mutableStateOf<String?>(null) }
    androidx.compose.runtime.LaunchedEffect(key) { state.value = sign() }
    return state
}
