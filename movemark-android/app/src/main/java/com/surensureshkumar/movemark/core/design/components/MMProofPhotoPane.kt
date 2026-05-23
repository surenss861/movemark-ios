package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Icon
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

enum class MMProofPhotoPaneSize {
    /** Welcome demo — large evidence pane inside case card. */
    Large,
    /** Vault hero — medium preview when proof exists. */
    Medium,
    /** Receipt — strongest real-photo moment. */
    Receipt,
    /** Room rows / compact evidence thumbnail. */
    Thumbnail,
}

data class MMProofIssueTag(
    val id: String,
    val label: String,
    val priorDamage: Boolean = false,
    val leadingInset: Dp = 0.dp,
)

@Composable
fun MMProofPhotoPane(
    modifier: Modifier = Modifier,
    size: MMProofPhotoPaneSize,
    imageBitmap: ImageBitmap? = null,
    drawableResId: Int? = null,
    roomName: String? = null,
    phaseLabel: String? = null,
    phaseBadge: String? = null,
    issueTags: List<MMProofIssueTag> = emptyList(),
    tagsVisible: Boolean = true,
    showScanCorners: Boolean = false,
    reduceMotion: Boolean = false,
) {
    when (size) {
        MMProofPhotoPaneSize.Thumbnail -> ThumbnailPane(
            modifier = modifier,
            imageBitmap = imageBitmap,
            drawableResId = drawableResId,
        )
        else -> EvidencePane(
            modifier = modifier,
            size = size,
            imageBitmap = imageBitmap,
            drawableResId = drawableResId,
            roomName = roomName,
            phaseLabel = phaseLabel,
            phaseBadge = phaseBadge,
            issueTags = issueTags,
            tagsVisible = tagsVisible,
            showScanCorners = showScanCorners,
            reduceMotion = reduceMotion,
        )
    }
}

@Composable
private fun ThumbnailPane(
    modifier: Modifier,
    imageBitmap: ImageBitmap?,
    drawableResId: Int?,
) {
    Box(
        modifier = modifier
            .size(72.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MMColors.FieldFill)
            .border(1.dp, MMColors.CardStroke, RoundedCornerShape(14.dp)),
        contentAlignment = Alignment.Center,
    ) {
        when {
            imageBitmap != null -> Image(bitmap = imageBitmap, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            drawableResId != null -> Image(painter = painterResource(drawableResId), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            else -> Icon(Icons.Default.PhotoCamera, null, tint = MMColors.TextMuted.copy(0.7f), modifier = Modifier.size(26.dp))
        }
    }
}

@Composable
private fun EvidencePane(
    modifier: Modifier,
    size: MMProofPhotoPaneSize,
    imageBitmap: ImageBitmap?,
    drawableResId: Int?,
    roomName: String?,
    phaseLabel: String?,
    phaseBadge: String?,
    issueTags: List<MMProofIssueTag>,
    tagsVisible: Boolean,
    showScanCorners: Boolean,
    reduceMotion: Boolean,
) {
    val inspectionGreen = Color(0xFF1A7A52)
    val contentScale = if (size == MMProofPhotoPaneSize.Large) ContentScale.FillWidth else ContentScale.Crop

    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.35f)),
    ) {
        when {
            imageBitmap != null -> Image(bitmap = imageBitmap, contentDescription = null, contentScale = contentScale, modifier = Modifier.fillMaxWidth())
            drawableResId != null -> Image(painter = painterResource(drawableResId), contentDescription = null, contentScale = contentScale, modifier = Modifier.fillMaxWidth())
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (size == MMProofPhotoPaneSize.Medium) 72.dp else 96.dp)
                .align(Alignment.BottomCenter)
                .background(
                    androidx.compose.ui.graphics.Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(0.22f), Color.Black.copy(0.45f)),
                    ),
                ),
        )
        if (showScanCorners) MMProofFocusBrackets(Modifier.fillMaxSize())
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp, vertical = 12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column {
                    roomName?.let {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(MMColors.Primary)
                                    .border(0.5.dp, Color.White.copy(0.4f), CircleShape),
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(it, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                    phaseLabel?.let {
                        Text(it, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(0.88f))
                    }
                }
                phaseBadge?.let {
                    Text(
                        it,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(0.95f),
                        modifier = Modifier
                            .background(Color.Black.copy(0.55f), CircleShape)
                            .border(0.8.dp, Color.White.copy(0.22f), CircleShape)
                            .padding(horizontal = 8.dp, vertical = 5.dp),
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            if (issueTags.isNotEmpty() && size != MMProofPhotoPaneSize.Medium) {
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    issueTags.forEachIndexed { index, tag ->
                        val tagScale by animateFloatAsState(
                            if (tagsVisible) 1f else 0.9f,
                            MMMotion.welcomeTagEnterSpec(reduceMotion),
                            label = "tag$index",
                        )
                        MMProofIssueMarker(
                            label = tag.label,
                            priorDamage = tag.priorDamage,
                            inspectionGreen = inspectionGreen,
                            modifier = Modifier.scale(tagScale).padding(start = tag.leadingInset),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MMProofIssueMarker(
    label: String,
    priorDamage: Boolean,
    inspectionGreen: Color,
    modifier: Modifier = Modifier,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                Modifier
                    .size(if (priorDamage) 7.dp else 5.dp)
                    .clip(CircleShape)
                    .background(if (priorDamage) Color.White else inspectionGreen),
            )
            Box(Modifier.width(1.dp).height(if (priorDamage) 10.dp else 7.dp).background(Color.White.copy(0.65f)))
        }
        Spacer(Modifier.width(5.dp))
        Text(
            label,
            fontSize = if (priorDamage) 12.sp else 11.sp,
            fontWeight = if (priorDamage) FontWeight.Bold else FontWeight.SemiBold,
            color = Color.White.copy(if (priorDamage) 1f else 0.96f),
            modifier = Modifier
                .background(
                    if (priorDamage) Color.Black.copy(0.82f) else inspectionGreen.copy(0.92f),
                    CircleShape,
                )
                .border(
                    if (priorDamage) 1.15.dp else 0.5.dp,
                    if (priorDamage) Color.White.copy(0.9f) else Color.White.copy(0.18f),
                    CircleShape,
                )
                .padding(horizontal = if (priorDamage) 10.dp else 9.dp, vertical = 5.dp),
        )
    }
}

@Composable
fun MMProofFocusBrackets(modifier: Modifier = Modifier) {
    val len = 18.dp
    val pad = 12.dp
    Box(modifier.padding(pad)) {
        listOf(Alignment.TopStart, Alignment.TopEnd, Alignment.BottomStart, Alignment.BottomEnd).forEach { corner ->
            MMProofFocusBracket(len, corner, Modifier.align(corner))
        }
    }
}

@Composable
private fun MMProofFocusBracket(length: Dp, corner: Alignment, modifier: Modifier = Modifier) {
    val stroke = Color.White.copy(0.58f)
    Box(modifier.size(length)) {
        when (corner) {
            Alignment.TopStart -> {
                Box(Modifier.width(length).height(1.5.dp).background(stroke))
                Box(Modifier.width(1.5.dp).height(length).background(stroke))
            }
            Alignment.TopEnd -> {
                Box(Modifier.width(length).height(1.5.dp).background(stroke).align(Alignment.TopEnd))
                Box(Modifier.width(1.5.dp).height(length).background(stroke).align(Alignment.TopEnd))
            }
            Alignment.BottomStart -> {
                Box(Modifier.width(length).height(1.5.dp).background(stroke).align(Alignment.BottomStart))
                Box(Modifier.width(1.5.dp).height(length).background(stroke).align(Alignment.BottomStart))
            }
            Alignment.BottomEnd -> {
                Box(Modifier.width(length).height(1.5.dp).background(stroke).align(Alignment.BottomEnd))
                Box(Modifier.width(1.5.dp).height(length).background(stroke).align(Alignment.BottomEnd))
            }
            else -> Unit
        }
    }
}
