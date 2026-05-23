package com.surensureshkumar.movemark.features.proof

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.surensureshkumar.movemark.core.design.components.MMProofArtifactCard
import com.surensureshkumar.movemark.core.design.components.MMProofArtifactModel
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
    var checkScale by remember { mutableStateOf(if (reduceMotion) 1f else 0.72f) }

    LaunchedEffect(Unit) {
        if (!reduceMotion) {
            visible = true
            delay(90)
            checkScale = 1f
        } else {
            visible = true
        }
    }

    val animatedCheck = animateFloatAsState(
        targetValue = checkScale,
        animationSpec = MMMotion.checkPopSpec(reduceMotion),
        label = "receiptCheck",
    )
    val phaseLabel = if (state.proofPhase == ProofPhase.MoveOut) "Move-out" else "Move-in"
    val verifiedLabel = buildString {
        if (state.hadPartialFailure && state.partialMessage != null) {
            append(state.partialMessage)
            append(" · ")
        }
        append(state.timestampLabel)
    }

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 20.dp, bottom = 24.dp),
        ) {
            AnimatedVisibility(
                visible = visible,
                enter = if (reduceMotion) fadeIn() else fadeIn() + slideInVertically { it / 5 },
            ) {
                Column {
                    ReceiptHeader(
                        checkScale = animatedCheck.value,
                        headerSubtitle = state.headerSubtitle,
                        documentedLabel = state.roomDocumentedLabel,
                    )
                    Spacer(Modifier.height(18.dp))
                    MMProofArtifactCard(
                        model = MMProofArtifactModel(
                            phaseEyebrow = "Room Proof",
                            phaseLabel = phaseLabel,
                            roomName = state.roomName,
                            photoCount = state.savedCount.coerceAtLeast(1),
                            issueCount = 0,
                            verifiedLabel = verifiedLabel,
                            savedLabel = "Saved to vault",
                            statusLabel = "Saved",
                            statusTone = if (state.hadPartialFailure) {
                                MMProofStatusTone.Warning
                            } else {
                                MMProofStatusTone.Success
                            },
                        ),
                        imageBitmap = state.thumbnailJpeg?.let { bytes ->
                            remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() }
                        },
                        photoHeight = 220.dp,
                        cornerRadius = 20.dp,
                        tagsVisible = false,
                        reduceMotion = reduceMotion,
                    )
                    if (state.hadPartialFailure) {
                        Spacer(Modifier.height(12.dp))
                        Text(
                            "${state.partialMessage}. You can retry the rest or continue with saved proof.",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = MMColors.SemanticWarning,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    MMColors.SemanticWarning.copy(alpha = 0.1f),
                                    RoundedCornerShape(12.dp),
                                )
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                        )
                    }
                }
            }

            Spacer(Modifier.height(20.dp))

            MMButton(
                text = state.primaryActionLabel,
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
            if (state.hadPartialFailure) {
                Spacer(Modifier.height(10.dp))
                MMButton(
                    text = RoomProofUploadMessages.RETRY_LABEL,
                    onClick = { onAddMorePhotos(roomId) },
                    style = MMButtonStyle.Secondary,
                )
            }
        }
    }
}

@Composable
private fun ReceiptHeader(
    checkScale: Float,
    headerSubtitle: String,
    documentedLabel: String,
) {
    Row(verticalAlignment = Alignment.Top) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = MMColors.Primary,
            modifier = Modifier
                .size(28.dp)
                .scale(checkScale),
        )
        Spacer(Modifier.width(10.dp))
        Column {
            Text(
                "Saved to your vault",
                color = MMColors.TextPrimary,
                fontWeight = FontWeight.Bold,
                fontSize = 24.sp,
                lineHeight = 28.sp,
            )
            Text(
                headerSubtitle,
                color = MMColors.TextSecondary,
                fontSize = 14.sp,
                modifier = Modifier.padding(top = 4.dp),
            )
            if (documentedLabel.isNotBlank()) {
                Text(
                    documentedLabel,
                    color = MMColors.TextMuted,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
