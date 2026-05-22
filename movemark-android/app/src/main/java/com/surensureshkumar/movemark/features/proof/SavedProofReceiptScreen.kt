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
import com.surensureshkumar.movemark.core.design.components.MMProofCard
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
        if (savedPulse > 0f) 0.14f else 0f,
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
                                .size(32.dp)
                                .scale(animatedCheck.value),
                        )
                        Spacer(Modifier.width(10.dp))
                        Column {
                            Text(
                                "Saved to your vault",
                                color = MMColors.TextPrimary,
                                fontWeight = FontWeight.Bold,
                                fontSize = 22.sp,
                            )
                            Text(
                                "Your room proof is stored with the timestamp.",
                                color = MMColors.TextSecondary,
                                fontSize = 14.sp,
                            )
                        }
                    }
                    Spacer(Modifier.height(20.dp))
                    MMProofCard(
                        modifier = Modifier.graphicsLayer { alpha = 1f - pulseAlpha.value * 0.5f },
                    ) {
                        Row(verticalAlignment = Alignment.Top) {
                            state.thumbnailJpeg?.let { bytes ->
                                val bitmap = remember(bytes) {
                                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                                }
                                bitmap?.let {
                                    Image(
                                        bitmap = it.asImageBitmap(),
                                        contentDescription = null,
                                        modifier = Modifier
                                            .size(64.dp)
                                            .background(MMColors.FieldFill, RoundedCornerShape(10.dp)),
                                        contentScale = ContentScale.Crop,
                                    )
                                    Spacer(Modifier.width(14.dp))
                                }
                            }
                            Column(Modifier.weight(1f)) {
                                Text(
                                    "${state.roomName} proof",
                                    color = MMColors.TextPrimary,
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 17.sp,
                                )
                                Spacer(Modifier.height(6.dp))
                                Text(
                                    photoLine(state.savedCount),
                                    color = MMColors.TextSecondary,
                                    fontSize = 14.sp,
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(state.timestampLabel, color = MMColors.TextMuted, fontSize = 13.sp)
                                if (state.isRoomDocumented) {
                                    Spacer(Modifier.height(8.dp))
                                    Text(
                                        "Room now documented",
                                        color = MMColors.Primary,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                }
                                state.partialMessage?.let { partial ->
                                    Spacer(Modifier.height(8.dp))
                                    Text(partial, color = MMColors.SemanticWarning, fontSize = 13.sp)
                                }
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            MMButton(
                text = "Continue next room",
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
            Spacer(Modifier.height(8.dp))
            MMButton(
                text = "Done",
                onClick = onBackSafe,
                style = MMButtonStyle.Secondary,
            )
        }
    }
}

private fun photoLine(count: Int): String {
    val photos = if (count == 1) "1 photo saved" else "$count photos saved"
    return "$photos · Move-in"
}
