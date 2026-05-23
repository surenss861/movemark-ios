package com.surensureshkumar.movemark.features.proof

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import android.graphics.BitmapFactory
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCard
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoPane
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoPaneSize
import com.surensureshkumar.movemark.core.design.components.MMProofReceiptStrip
import com.surensureshkumar.movemark.core.design.components.MMProofReceiptStripLayout
import com.surensureshkumar.movemark.core.design.components.MMProofReceiptStripModel
import com.surensureshkumar.movemark.core.design.components.MMProofCaseAccentRail
import com.surensureshkumar.movemark.core.design.components.MMProofCaseHeader
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone
import com.surensureshkumar.movemark.domain.ProofPhase
import kotlinx.coroutines.delay
import java.util.UUID

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
    val reduceMotion = MMMotion.rememberReduceMotion()
    var visible by remember { mutableStateOf(reduceMotion) }
    var checkScale by remember { mutableStateOf(if (reduceMotion) 1f else 0.4f) }
    var savedPulse by remember { mutableStateOf(0f) }

    LaunchedEffect(Unit) {
        if (!reduceMotion) {
            visible = true
            delay(80)
            checkScale = 1f
            delay(200)
            savedPulse = 1f
            delay(400)
            savedPulse = 0f
        }
    }

    val animatedCheck = animateFloatAsState(checkScale, MMMotion.checkPopSpec(reduceMotion), label = "check")
    val pulseAlpha = animateFloatAsState(
        if (savedPulse > 0f) 0.18f else 0f,
        MMMotion.receiptEnterSpec(reduceMotion),
        label = "pulse",
    )

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
        ) {
            AnimatedVisibility(
                visible = visible,
                enter = if (reduceMotion) fadeIn() else fadeIn() + slideInVertically { it / 4 },
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = MMColors.Primary,
                            modifier = Modifier
                                .size(36.dp)
                                .scale(animatedCheck.value),
                        )
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(
                                state.receiptTitle,
                                color = MMColors.TextPrimary,
                                fontWeight = FontWeight.Bold,
                                fontSize = 24.sp,
                            )
                            Text(
                                "${state.roomName} proof",
                                color = MMColors.TextSecondary,
                                fontSize = 15.sp,
                            )
                            Text(
                                state.receiptSubtitle,
                                color = MMColors.Primary.copy(alpha = 0.9f),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(top = 2.dp),
                            )
                        }
                    }
                    Spacer(Modifier.height(20.dp))
                    Box(modifier = Modifier.fillMaxWidth()) {
                        if (savedPulse > 0f && !reduceMotion) {
                            Box(
                                modifier = Modifier
                                    .matchParentSize()
                                    .graphicsLayer { alpha = pulseAlpha.value }
                                    .background(MMColors.Primary.copy(alpha = 0.12f), RoundedCornerShape(22.dp)),
                            )
                        }
                        MMProofCaseCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .graphicsLayer { alpha = 1f - pulseAlpha.value * 0.3f },
                            header = MMProofCaseHeader(
                                eyebrow = if (state.proofPhase == ProofPhase.MoveOut) "Move-out proof" else "Move-in proof",
                                statusLabel = "Saved",
                                statusTone = MMProofStatusTone.Success,
                                accentRail = MMProofCaseAccentRail.Saved,
                            ),
                            footer = {
                                MMProofReceiptStrip(
                                    model = MMProofReceiptStripModel(
                                        detailTitle = state.roomName,
                                        detailSubtitle = state.receiptSubtitle,
                                        savedTitle = "Saved to your vault",
                                        timestampLabel = state.timestampLabel,
                                        statusBadge = "Ready",
                                        statusTone = MMProofStatusTone.Success,
                                    ),
                                    layout = MMProofReceiptStripLayout.CaseFile,
                                )
                            },
                        ) {
                            val bitmap = state.thumbnailJpeg?.let { bytes ->
                                remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
                            }
                            MMProofPhotoPane(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(180.dp),
                                size = MMProofPhotoPaneSize.Receipt,
                                imageBitmap = bitmap?.asImageBitmap(),
                                roomName = state.roomName,
                                phaseLabel = state.receiptSubtitle,
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            MMButton(
                text = state.continueNextRoomLabel,
                onClick = { onContinueNextRoom(viewModel.nextUndocumentedRoomId()) },
            )
            Spacer(Modifier.height(10.dp))
            MMButton(
                text = "View proof vault",
                onClick = onViewVault,
                style = MMButtonStyle.Secondary,
            )
            Spacer(Modifier.height(10.dp))
            MMButton(
                text = "Add more photos",
                onClick = { onAddMorePhotos(roomId) },
                style = MMButtonStyle.Secondary,
            )
        }
    }
}

private fun proofMetaTitle(state: SavedProofReceiptUiState): String =
    if (state.proofPhase == ProofPhase.MoveOut) {
        "${state.roomName} · Move-out"
    } else {
        "${state.roomName} proof"
    }
