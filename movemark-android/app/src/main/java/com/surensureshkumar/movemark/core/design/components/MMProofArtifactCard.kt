package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

data class MMProofArtifactModel(
    val phaseEyebrow: String = "Room Proof",
    val phaseLabel: String = "Move-in",
    val roomName: String,
    val photoCount: Int,
    val issueCount: Int,
    val verifiedLabel: String,
    val savedLabel: String = "Saved to vault",
    val statusLabel: String? = null,
    val statusTone: MMProofStatusTone = MMProofStatusTone.Success,
    val issueTags: List<String> = emptyList(),
)

/**
 * MoveMark proof artifact — photo-first evidence object with metadata strip.
 * Used on Welcome, Vault hero, and Receipt.
 */
@Composable
fun MMProofArtifactCard(
    model: MMProofArtifactModel,
    modifier: Modifier = Modifier,
    photoHeight: Dp = 168.dp,
    cornerRadius: Dp = 20.dp,
    drawableResId: Int? = null,
    imageBitmap: ImageBitmap? = null,
    imageUrl: String? = null,
    showReportPeek: Boolean = false,
    tagsVisible: Boolean = true,
    reduceMotion: Boolean = false,
) {
    Box(modifier = modifier.fillMaxWidth()) {
        if (showReportPeek) {
            MMProofReportPeekLayer(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 10.dp)
                    .fillMaxWidth(0.92f),
            )
        }
        MMProofArtifactSurface(
            model = model,
            photoHeight = photoHeight,
            cornerRadius = cornerRadius,
            drawableResId = drawableResId,
            imageBitmap = imageBitmap,
            imageUrl = imageUrl,
            tagsVisible = tagsVisible,
            reduceMotion = reduceMotion,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun MMProofReportPeekLayer(modifier: Modifier = Modifier) {
    Column(modifier) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(28.dp)
                .offset(y = 6.dp)
                .clip(RoundedCornerShape(topStart = 10.dp, topEnd = 10.dp))
                .background(MMColors.PaperSurface.copy(alpha = 0.22f))
                .border(1.dp, MMColors.CardStroke, RoundedCornerShape(topStart = 10.dp, topEnd = 10.dp)),
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(36.dp)
                .offset(y = 2.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MMColors.PaperSurface.copy(alpha = 0.14f))
                .border(1.dp, MMColors.CardStroke.copy(alpha = 0.6f), RoundedCornerShape(12.dp)),
        )
    }
}

@Composable
private fun MMProofArtifactSurface(
    model: MMProofArtifactModel,
    photoHeight: Dp,
    cornerRadius: Dp,
    drawableResId: Int?,
    imageBitmap: ImageBitmap?,
    imageUrl: String?,
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(cornerRadius)
    Surface(
        modifier = modifier,
        shape = shape,
        color = MMColors.EvidenceCard,
        border = BorderStroke(1.dp, MMColors.CardStroke),
    ) {
        Column {
            MMProofArtifactHeader(model)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .height(photoHeight)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MMColors.FieldFill),
            ) {
                when {
                    imageBitmap != null -> Image(
                        bitmap = imageBitmap,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                    !imageUrl.isNullOrBlank() -> AsyncImage(
                        model = imageUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                    drawableResId != null -> Image(
                        painter = painterResource(drawableResId),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                    else -> Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        androidx.compose.material3.Icon(
                            imageVector = Icons.Default.PhotoCamera,
                            contentDescription = null,
                            tint = MMColors.TextMuted.copy(alpha = 0.65f),
                            modifier = Modifier.size(36.dp),
                        )
                    }
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(64.dp)
                        .align(Alignment.BottomCenter)
                        .background(
                            androidx.compose.ui.graphics.Brush.verticalGradient(
                                listOf(Color.Transparent, Color.Black.copy(alpha = 0.45f)),
                            ),
                        ),
                )
                if (tagsVisible && model.issueTags.isNotEmpty()) {
                    Row(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(10.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        model.issueTags.take(2).forEachIndexed { index, tag ->
                            val tagScale by animateFloatAsState(
                                if (tagsVisible) 1f else 0.92f,
                                MMMotion.welcomeTagEnterSpec(reduceMotion),
                                label = "artifactTag$index",
                            )
                            Text(
                                tag,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White.copy(alpha = 0.95f),
                                maxLines = 1,
                                modifier = Modifier
                                    .scale(tagScale)
                                    .background(Color.Black.copy(alpha = 0.72f), RoundedCornerShape(8.dp))
                                    .padding(horizontal = 8.dp, vertical = 4.dp),
                            )
                        }
                    }
                }
            }
            MMProofArtifactFooter(model)
        }
    }
}

@Composable
private fun MMProofArtifactHeader(model: MMProofArtifactModel) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "${model.phaseEyebrow.uppercase()} · ${model.phaseLabel.uppercase()}",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.7.sp,
                color = MMColors.TextMuted,
                maxLines = 1,
                modifier = Modifier.weight(1f, fill = false),
            )
            model.statusLabel?.let {
                Spacer(Modifier.width(8.dp))
                MMProofStatusBadge(text = it, tone = model.statusTone)
            }
        }
        Text(
            model.roomName,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun MMProofArtifactFooter(model: MMProofArtifactModel) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(MMColors.CardStroke.copy(alpha = 0.65f)),
        )
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "${model.photoCount} photos · ${model.issueCount} issues",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = MMColors.TextSecondary,
                modifier = Modifier.weight(1f),
            )
            Text(
                model.savedLabel,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.Primary.copy(alpha = 0.98f),
            )
        }
        Text(
            model.verifiedLabel,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = MMColors.TextMuted,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}
