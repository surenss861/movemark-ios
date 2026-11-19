package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.ui.semantics.contentDescription
import android.graphics.BitmapFactory
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.LocationOff
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.data.evidence.PhotoPrivacy
import com.surensureshkumar.movemark.data.evidence.PhotoPrivacyPolicy
import java.util.UUID

/** The receipt's ink on the light page (owner's one light system, 2026-11-18): ink headings, #6D6E6F secondary. */
private object SlipInk {
    val Field = MMInk.Sheet
    val Text = MMInk.Text
    val Secondary = MMInk.Secondary
    val Tertiary = MMInk.Secondary
    val Rule = MMInk.Separator
    val Warning = MMInk.Warning
    val PhotoFill = MMInk.ThumbFill
    val Outline = MMInk.CardStroke
    val Check = MMInk.Text
}

/**
 * The receipt after every room save, as the iOS Proof Slip (`ProofSavedReceiptView`): states only what was confirmed
 * (photos saved, photos that need a retry, issues, when), shows one saved photo, and offers one lime action with quiet
 * text secondaries. System back returns to safety, as before.
 */
@Composable
fun SavedProofReceiptScreen(
    roomId: UUID,
    onContinueNextRoom: (UUID?) -> Unit,
    onViewVault: () -> Unit,
    onAddMorePhotos: (UUID) -> Unit,
    onBackSafe: () -> Unit,
    viewModel: SavedProofReceiptViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    BackHandler { onBackSafe() }
    SavedProofReceiptContent(
        state = state,
        teen = PhotoPrivacyPolicy.current == PhotoPrivacy.Teen,
        onPrimary = { isPartial -> if (isPartial) onAddMorePhotos(roomId) else onContinueNextRoom(viewModel.nextUndocumentedRoomId()) },
        // "View evidence" opens this room's saved entries; "Add more photos" opens the same room to capture more.
        onViewEvidence = { onAddMorePhotos(roomId) },
        onAddMorePhotos = { onAddMorePhotos(roomId) },
    )
}

/**
 * The receipt itself, from its state alone (also rendered by the debug fixture gallery). The polished iOS Proof Slip:
 * a header (state, phase, room), the confirmed facts on one ruled line (photos saved, issues, when it was saved: the
 * server's time once known), the saved photo by itself taking the spare height, the preservation lines as a quiet
 * caption, then one lime action, an outlined "View evidence" and a text "Add more photos".
 */
@Composable
internal fun SavedProofReceiptContent(
    state: SavedProofReceiptUiState,
    teen: Boolean,
    onPrimary: (isPartial: Boolean) -> Unit,
    onViewEvidence: () -> Unit,
    onAddMorePhotos: () -> Unit,
) {
    MMLightSystemBars(lightNavigationBar = true, lightStatusBar = true)
    val pending = (state.attemptedCount - state.savedCount).coerceAtLeast(0)
    val isPartial = state.hadPartialFailure && pending > 0
    val large = mmIsLargeFont()

    BoxWithConstraints(Modifier.fillMaxSize().background(SlipInk.Field)) {
        // The photo takes the spare height (iOS: min 220/160 at large text, max 400), so the actions sit low
        // without a dead zone; on small screens or large text the receipt scrolls with the photo at its minimum.
        val photoHeight = (maxHeight * 0.34f).coerceIn(if (mmIsLargeFont()) 160.dp else 220.dp, 400.dp)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                .statusBarsPadding().navigationBarsPadding()
                .padding(horizontal = 20.dp).padding(top = 24.dp, bottom = 16.dp),
        ) {
            // What was recorded
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
                Icon(
                    if (isPartial) Icons.Filled.Error else Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = if (isPartial) SlipInk.Warning else SlipInk.Check,
                    modifier = Modifier.size(17.dp),
                )
                Spacer(Modifier.width(7.dp))
                Text(
                    if (isPartial) "PROOF PARTLY SAVED" else "PROOF SAVED",
                    style = mmFont(12f, FontWeight.SemiBold, tracking = 0.6f),
                    color = SlipInk.Secondary,
                )
                Spacer(Modifier.weight(1f))
                Text(state.phaseLabel.uppercase(), style = mmFont(12f, FontWeight.SemiBold, tracking = 0.6f), color = SlipInk.Tertiary)
            }
            Text(
                state.roomName,
                style = mmFont(32f, FontWeight.SemiBold),
                color = SlipInk.Text,
                modifier = Modifier.padding(top = 10.dp).semantics { heading() },
            )

            // The confirmed facts on one ruled line, like a receipt.
            Column(Modifier.padding(top = 16.dp).testTag("receipt.facts")) {
                Box(Modifier.fillMaxWidth().height(0.5.dp).background(SlipInk.Rule))
                val cells: @Composable (Modifier) -> Unit = { m ->
                    Fact("Photos", "${state.savedCount} saved", "${receiptCount(state.savedCount, "photo")} saved", m)
                    if (state.issueCount > 0) Fact("Issues", "${state.issueCount} recorded", "${receiptCount(state.issueCount, "issue")} recorded", m)
                    // Server time once the save's entry is read back; until then it is honestly this phone's clock.
                    // Polished iOS: "Saved" only for the server's time; this phone's clock reads "Confirmed … on this device".
                    if (state.savedTimeFromServer) {
                        Fact("Saved", state.savedTimeLabel, "Saved ${state.savedTimeLabel}", m)
                    } else {
                        val local = "${state.savedTimeLabel} on this device"
                        Fact("Confirmed", local, "Confirmed $local", m)
                    }
                }
                if (large) {
                    Column(Modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { cells(Modifier) }
                } else {
                    Row(Modifier.padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) { cells(Modifier) }
                }
                Box(Modifier.fillMaxWidth().height(0.5.dp).background(SlipInk.Rule))
            }
            if (isPartial) {
                Row(Modifier.padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Refresh, contentDescription = null, tint = SlipInk.Warning, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "${receiptCount(pending, "photo")} only on this phone · ${if (pending == 1) "needs" else "need"} a retry",
                        style = mmFont(14.5f, FontWeight.Medium),
                        color = SlipInk.Warning,
                    )
                }
            }

            // One saved photo, by itself: no text over it. It takes the spare height (220-400dp).
            val bitmap = state.thumbnailJpeg?.let { bytes -> remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() } }
            Box(
                Modifier.padding(top = 22.dp).fillMaxWidth()
                    .height(photoHeight)
                    .clip(RoundedCornerShape(16.dp)).background(SlipInk.PhotoFill)
                    .border(0.75.dp, SlipInk.Outline, RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center,
            ) {
                if (bitmap != null) {
                    Image(bitmap, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                } else {
                    Icon(Icons.Outlined.Image, contentDescription = null, tint = SlipInk.Secondary, modifier = Modifier.size(28.dp))
                }
            }

            // How the proof is kept: a quiet caption under the photo.
            Column(Modifier.padding(top = 12.dp, start = 2.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                if (teen) Assurance(Icons.Outlined.LocationOff, "Location and camera details removed for privacy")
                else Assurance(Icons.Outlined.Shield, "Source files preserved")
                Assurance(Icons.Outlined.Inventory2, "Recorded in your proof vault")
            }

            Spacer(Modifier.height(24.dp))

            // What next: one lime action, an outlined secondary, a text tertiary.
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                MMPrimaryButton(
                    title = state.primaryActionLabel,
                    onClick = { onPrimary(isPartial) },
                    height = 52.dp,
                    modifier = Modifier.testTag("receipt.primary"),
                )
                OutlinedButton(
                    onClick = onViewEvidence,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("receipt.viewEvidence"),
                    shape = RoundedCornerShape(50),
                    border = BorderStroke(1.dp, MMInk.Separator),
                    colors = ButtonDefaults.outlinedButtonColors(containerColor = MMInk.Card, contentColor = SlipInk.Text),
                ) { Text("View evidence", style = mmFont(15.5f, FontWeight.SemiBold), color = SlipInk.Text) }
                if (!isPartial) {
                    TextButton(onClick = onAddMorePhotos, modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp)) {
                        Text("Add more photos", style = mmFont(15f, FontWeight.Medium), color = SlipInk.Secondary)
                    }
                }
            }
        }
    }
}

@Composable
private fun Fact(label: String, value: String, spoken: String, modifier: Modifier) {
    Column(modifier.semantics(mergeDescendants = true) { contentDescription = spoken }, verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(label.uppercase(), style = mmFont(11f, FontWeight.SemiBold, tracking = 0.6f), color = SlipInk.Tertiary)
        Text(value, style = mmFont(15.5f, FontWeight.Medium), color = SlipInk.Text)
    }
}

@Composable
private fun Assurance(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
        Icon(icon, contentDescription = null, tint = SlipInk.Secondary, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(7.dp))
        Text(text, style = mmFont(13f), color = SlipInk.Secondary)
    }
}

