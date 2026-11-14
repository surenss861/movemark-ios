package com.surensureshkumar.movemark.features.proof

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
import androidx.compose.ui.graphics.Color
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

/** The room screen's dark field and the receipt's own ink (iOS `ProofSavedReceiptView.Ink`). */
private object SlipInk {
    val Field = MMInk.Evidence
    val Text = Color.White
    val Secondary = Color.White.copy(alpha = 0.62f)
    val Rule = Color.White.copy(alpha = 0.12f)
    val Warning = Color(0xFFF2BC57)
    val PhotoFill = Color.White.copy(alpha = 0.06f)
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
    MMLightSystemBars(lightNavigationBar = false, lightStatusBar = false)
    val pending = (state.attemptedCount - state.savedCount).coerceAtLeast(0)
    val isPartial = state.hadPartialFailure && pending > 0
    val teen = PhotoPrivacyPolicy.current == PhotoPrivacy.Teen

    Column(
        Modifier.fillMaxSize().background(SlipInk.Field).verticalScroll(rememberScrollState())
            .statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = 20.dp).padding(top = 28.dp, bottom = 32.dp),
    ) {
        // What was recorded
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
            Icon(
                if (isPartial) Icons.Filled.Error else Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = if (isPartial) SlipInk.Warning else MMInk.Lime,
                modifier = Modifier.size(20.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                if (isPartial) "PROOF PARTLY SAVED" else "PROOF SAVED",
                style = mmFont(12f, FontWeight.SemiBold, tracking = 0.6f),
                color = SlipInk.Secondary,
            )
        }
        Text(
            state.roomName,
            style = mmFont(32f, FontWeight.SemiBold),
            color = SlipInk.Text,
            maxLines = 3,
            modifier = Modifier.padding(top = 12.dp).semantics { heading() },
        )
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text("${receiptCount(state.savedCount, "photo")} saved", style = mmFont(16f, FontWeight.Medium), color = SlipInk.Text)
            if (isPartial) {
                Text(
                    "${receiptCount(pending, "photo")} ${if (pending == 1) "needs" else "need"} a retry",
                    style = mmFont(16f, FontWeight.Medium),
                    color = SlipInk.Warning,
                )
            }
            if (state.issueCount > 0) {
                Text("${receiptCount(state.issueCount, "issue")} recorded", style = mmFont(16f, FontWeight.Medium), color = SlipInk.Text)
            }
        }
        Text(state.timestampLabel, style = mmFont(14f), color = SlipInk.Secondary, modifier = Modifier.padding(top = 8.dp))

        // One saved photo, by itself: no text over it.
        val bitmap = state.thumbnailJpeg?.let { bytes -> remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() } }
        Box(
            Modifier.padding(top = 24.dp).fillMaxWidth().height(if (mmIsLargeFont()) 160.dp else 220.dp)
                .clip(RoundedCornerShape(16.dp)).background(SlipInk.PhotoFill),
            contentAlignment = Alignment.Center,
        ) {
            if (bitmap != null) {
                Image(bitmap, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            } else {
                Icon(Icons.Outlined.Image, contentDescription = null, tint = SlipInk.Secondary, modifier = Modifier.size(28.dp))
            }
        }

        // Assurances
        Column(Modifier.padding(top = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(SlipInk.Rule))
            if (teen) Assurance(Icons.Outlined.LocationOff, "Location and camera details removed for privacy")
            else Assurance(Icons.Outlined.Shield, "Source files preserved")
            Assurance(Icons.Outlined.Inventory2, "Recorded in your proof vault")
            Box(Modifier.fillMaxWidth().height(1.dp).background(SlipInk.Rule))
        }

        // What next: one lime action, quiet text secondaries.
        Column(Modifier.padding(top = 28.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            MMPrimaryButton(
                title = state.primaryActionLabel,
                onClick = {
                    if (isPartial) onAddMorePhotos(roomId) else onContinueNextRoom(viewModel.nextUndocumentedRoomId())
                },
                modifier = Modifier.testTag("receipt.primary"),
            )
            QuietButton("View proof vault", Modifier.padding(top = 8.dp), onViewVault)
            if (!isPartial) QuietButton("Add more photos", Modifier, onClick = { onAddMorePhotos(roomId) })
        }
    }
}

@Composable
private fun Assurance(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
        Icon(icon, contentDescription = null, tint = SlipInk.Text.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Text(text, style = mmFont(14.5f), color = SlipInk.Text.copy(alpha = 0.85f))
    }
}

@Composable
private fun QuietButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = modifier.fillMaxWidth().heightIn(min = 48.dp)) {
        Text(title, style = mmFont(15f, FontWeight.Medium), color = SlipInk.Text)
    }
}
