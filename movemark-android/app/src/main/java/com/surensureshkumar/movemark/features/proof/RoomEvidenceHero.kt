/**
 * @file Room hero — full-bleed evidence photo with filmstrip, or the empty capture field
 * @domain proof-capture
 * @status wip
 * @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4 composition)
 * @see [[RoomEvidenceHero.swift]] — iOS reference implementation
 */
package com.surensureshkumar.movemark.features.proof

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.CenterFocusWeak
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
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
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
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

/** About two-thirds of the screen — shared with the screen so the bar knows when the hero has left. */
fun roomHeroHeight(width: Dp, screenHeight: Dp): Dp = minOf(width * 1.35f, screenHeight * 0.66f)

fun conditionLabel(rating: Int?): String =
    RoomConditionLabels.firstOrNull { it.first == rating }?.second ?: "Not rated"

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
    /** Page scroll in px, for parallax. */
    scrollOffset: () -> Int = { 0 },
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
    val reduceMotion = MMMotion.rememberReduceMotion()
    val photoCount = entries.sumOf { it.photoCount }
    val issueCount = entries.flatMap { it.issueTags }.toSet().size

    Column(modifier.fillMaxWidth()) {
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val screenHeight = LocalConfiguration.current.screenHeightDp.dp
            val heroHeight = roomHeroHeight(maxWidth, screenHeight)
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(heroHeight)
                    .clipToBounds()
                    .clickable(role = Role.Button, onClickLabel = "Open photo full screen") { onOpenPhoto(photo) },
            ) {
                // Scrolling up, the photo drifts slower than the page (parallax). Off under Reduce Motion.
                Box(Modifier.fillMaxSize().graphicsLayer { translationY = if (reduceMotion) 0f else scrollOffset() * 0.4f }) {
                    Crossfade(targetState = photo, animationSpec = tween(350), label = "heroPhoto") { shown ->
                        HeroImage(shown, signPhotoUrl)
                    }
                }
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                0f to Color.Black.copy(alpha = 0.35f),
                                0.2f to Color.Transparent,
                                0.4f to Color.Black.copy(alpha = 0.18f),
                                0.72f to MMColors.AppBackground.copy(alpha = 0.78f),
                                0.9f to MMColors.AppBackground.copy(alpha = 0.95f),
                                1f to MMColors.AppBackground,
                            ),
                        ),
                )
                HeroTitle(
                    roomName = roomName,
                    recorded = recordedLabel(entry.createdAt),
                    chips = listOfNotNull(
                        HeroChip(conditionLabel(entry.conditionRating), Icons.Filled.CheckCircle, MMColors.Primary),
                        HeroChip(if (photoCount == 1) "1 photo" else "$photoCount photos", Icons.Outlined.PhotoLibrary, Color.White),
                        issueCount.takeIf { it > 0 }?.let {
                            HeroChip(if (it == 1) "1 issue" else "$it issues", Icons.Filled.Warning, MMColors.SemanticWarning)
                        },
                    ),
                    isBusy = isBusy,
                    onTakePhotos = onTakePhotos,
                    onChooseGallery = onChooseGallery,
                    modifier = Modifier.align(Alignment.BottomStart),
                )
            }
        }

        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 6.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
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
            compareLine?.let {
                Text(it, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMColors.TextMuted)
            }
        }
    }
}

@Composable
private fun HeroImage(photo: EvidencePhoto, signPhotoUrl: suspend (String) -> String?) {
    val url by produceState<String?>(initialValue = null, photo.filePath) { value = signPhotoUrl(photo.filePath) }
    Box(Modifier.fillMaxSize().background(MMColors.Card)) {
        if (url != null) {
            SubcomposeAsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                error = {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Photo unavailable", color = MMColors.TextMuted, fontSize = 13.sp)
                    }
                },
            )
        }
    }
}

/**
 * Pinned over the screen (not inside the scrolling hero): back and phase sit on the photo as
 * translucent controls; once the hero has scrolled away the bar fills and the room name settles in.
 */
@Composable
fun RoomTopBar(roomName: String, phase: ProofPhase, onBack: () -> Unit, scrolledAway: Boolean) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val fill by animateFloatAsState(if (scrolledAway) 0.98f else 0f, tween(200), label = "barFill")
    Row(
        Modifier
            .fillMaxWidth()
            .background(MMColors.AppBackground.copy(alpha = fill))
            .padding(top = top + 4.dp, start = 8.dp, end = 16.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.35f * (1f - fill))),
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
        }
        Text(
            roomName,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 8.dp)
                .alpha(fill / 0.98f),
        )
        Text(
            if (phase == ProofPhase.MoveOut) "Move-out" else "Move-in",
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(Color.Black.copy(alpha = 0.35f))
                .padding(horizontal = 12.dp, vertical = 7.dp),
        )
    }
}

private data class HeroChip(val text: String, val icon: ImageVector, val tint: Color)

/** Layered on the poster: state first, then the room, then provenance, then the action. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun HeroTitle(
    roomName: String,
    recorded: String?,
    chips: List<HeroChip>,
    isBusy: Boolean,
    onTakePhotos: () -> Unit,
    onChooseGallery: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
            .padding(bottom = 18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            chips.forEach { GlassChip(it) }
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                roomName,
                color = Color.White,
                fontSize = 34.sp,
                lineHeight = 38.sp,
                fontWeight = FontWeight.Bold,
                style = LocalTextStyle.current.copy(shadow = Shadow(Color.Black.copy(alpha = 0.35f), blurRadius = 20f)),
                modifier = Modifier.semantics { heading() },
            )
            recorded?.let { RecordedLine(it, onPhoto = true) }
        }
        AddEvidencePill(isBusy, onTakePhotos, onChooseGallery, Modifier.padding(top = 6.dp))
    }
}

/** A documented room's next action isn't urgent: a white pill, not green (green is for saving). */
@Composable
private fun AddEvidencePill(isBusy: Boolean, onTakePhotos: () -> Unit, onChooseGallery: () -> Unit, modifier: Modifier = Modifier) {
    var open by remember { mutableStateOf(false) }
    Box(modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 50.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = if (isBusy) 0.5f else 1f))
                .clickable(enabled = !isBusy, role = Role.Button) { open = true },
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.PhotoCamera, contentDescription = null, tint = Color.Black, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("Add evidence", color = Color.Black, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text("Take photos") },
                leadingIcon = { Icon(Icons.Outlined.PhotoCamera, contentDescription = null) },
                onClick = { open = false; onTakePhotos() },
            )
            DropdownMenuItem(
                text = { Text("Choose from library") },
                leadingIcon = { Icon(Icons.Outlined.PhotoLibrary, contentDescription = null) },
                onClick = { open = false; onChooseGallery() },
            )
        }
    }
}

/** Translucent chip over evidence (Compose has no backdrop blur; a dark scrim stands in). */
@Composable
private fun GlassChip(chip: HeroChip) {
    Row(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(Color.Black.copy(alpha = 0.45f))
            .border(0.5.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(chip.icon, contentDescription = null, tint = chip.tint, modifier = Modifier.size(14.dp))
        Text(chip.text, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun RecordedLine(value: String, onPhoto: Boolean = false) {
    // The timestamp never breaks mid-value; at large font scales it drops under its label.
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Kicker("RECORDED", if (onPhoto) Color.White.copy(alpha = 0.7f) else MMColors.TextMuted)
        Text(
            value,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = if (onPhoto) Color.White.copy(alpha = 0.9f) else MMColors.TextSecondary,
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
    val url by produceState<String?>(initialValue = null, path) {
        value = signPhotoUrl(path) ?: signPhotoUrl(photo.filePath)
    }
    val shape = RoundedCornerShape(12.dp)
    Box(
        Modifier
            .size(64.dp)
            .clip(shape)
            .background(MMColors.CardRaised)
            .border(BorderStroke(if (isSelected) 2.dp else 1.dp, if (isSelected) Color.White else Color.White.copy(alpha = 0.08f)), shape)
            .alpha(if (isSelected) 1f else 0.72f)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics {
                selected = isSelected
                contentDescription = "Evidence photo"
            },
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
    }
}

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
    Box(modifier.fillMaxWidth()) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(420.dp)
                .background(Brush.verticalGradient(listOf(MMColors.CardRaised.copy(alpha = 0.85f), MMColors.AppBackground))),
        )
        Column(Modifier.fillMaxWidth()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                    // Clears the pinned RoomTopBar.
                    .padding(top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 84.dp, bottom = 8.dp),
            ) {
                Kicker(if (moveOut) "MOVE-OUT EVIDENCE" else "MOVE-IN EVIDENCE", MMColors.TextMuted)
                Spacer(Modifier.height(10.dp))
                Text(
                    roomName,
                    color = MMColors.TextPrimary,
                    fontSize = 34.sp,
                    lineHeight = 38.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.semantics { heading() },
                )
                Spacer(Modifier.height(10.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(7.dp).clip(CircleShape).background(MMColors.SemanticWarning))
                    Spacer(Modifier.padding(start = 8.dp))
                    Text("Still needs proof", color = MMColors.TextPrimary, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    if (moveOut) "Photograph each surface before you return the keys." else "Photograph it before boxes cover anything.",
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                )
                Spacer(Modifier.height(30.dp))
                Kicker("WHAT TO CAPTURE", MMColors.TextMuted)
                Spacer(Modifier.height(12.dp))
                RoomCapturePrompts.forEach { prompt ->
                    Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.CenterFocusWeak, contentDescription = null, tint = MMColors.TextMuted, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.padding(start = 12.dp))
                        Text(prompt, color = MMColors.TextPrimary.copy(alpha = 0.92f), fontSize = 17.sp)
                    }
                }
                Spacer(Modifier.height(30.dp))
                // Green only while it's the screen's one action; once photos are picked the save
                // bar takes the green.
                MMButton(
                    text = "Take photos",
                    onClick = onTakePhotos,
                    style = if (hasPendingPhotos) MMButtonStyle.Secondary else MMButtonStyle.Primary,
                    enabled = !isBusy,
                )
                Spacer(Modifier.height(10.dp))
                MMButton(text = "Choose from gallery", onClick = onChooseGallery, style = MMButtonStyle.Secondary, enabled = !isBusy)
            }
        }
    }
}

@Composable
fun Kicker(text: String, color: Color) {
    Text(text, color = color, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
}
