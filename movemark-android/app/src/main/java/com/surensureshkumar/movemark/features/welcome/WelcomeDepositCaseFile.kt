package com.surensureshkumar.movemark.features.welcome

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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

private val CardCorner = 28.dp
private val ProofBarHeight = 72.dp
private val InspectionGreen = Color(0xFF1A7A52)

private data class IssueTag(val id: String, val label: String, val priorDamage: Boolean)

private val IssueTags = listOf(
    IssueTag("prior", "Already there", priorDamage = true),
    IssueTag("paint", "Chipped paint", priorDamage = false),
    IssueTag("stain", "Water stain", priorDamage = false),
)

@Composable
fun WelcomeDepositCaseFile(
    heroHeight: androidx.compose.ui.unit.Dp,
    cardVisible: Boolean,
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val cardAlpha by animateFloatAsState(
        targetValue = if (cardVisible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardAlpha",
    )
    val cardOffsetY by animateFloatAsState(
        targetValue = if (cardVisible) 0f else 14f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardOffset",
    )

    val photoHeight = (heroHeight - ProofBarHeight).coerceAtLeast(150.dp)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(heroHeight)
            .alpha(cardAlpha)
            .offset(y = cardOffsetY.dp)
            .clip(RoundedCornerShape(CardCorner))
            .background(MMColors.Card.copy(alpha = 0.98f))
            .border(
                width = 1.dp,
                brush = Brush.linearGradient(
                    colors = listOf(
                        MMColors.Primary.copy(alpha = 0.38f),
                        MMColors.CardStroke.copy(alpha = 0.7f),
                    ),
                ),
                shape = RoundedCornerShape(CardCorner),
            ),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            PhotoCaptureZone(
                photoHeight = photoHeight,
                tagsVisible = tagsVisible,
                reduceMotion = reduceMotion,
            )
            ProofCaptureBar()
        }
    }
}

@Composable
private fun PhotoCaptureZone(
    photoHeight: androidx.compose.ui.unit.Dp,
    tagsVisible: Boolean,
    reduceMotion: Boolean,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(photoHeight)
            .clip(RoundedCornerShape(topStart = CardCorner, topEnd = CardCorner))
            .background(Color.Black.copy(alpha = 0.35f)),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.welcome_kitchen_main),
            contentDescription = null,
            contentScale = ContentScale.FillWidth,
            alignment = Alignment.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height((photoHeight * 0.45f).coerceAtMost(96.dp))
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.22f),
                            Color.Black.copy(alpha = 0.45f),
                        ),
                    ),
                ),
        )
        FocusBrackets(modifier = Modifier.fillMaxSize())
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
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(MMColors.Primary)
                                .border(0.5.dp, Color.White.copy(alpha = 0.4f), CircleShape),
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            "Kitchen",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                        )
                    }
                    Text(
                        "Move-in proof",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.88f),
                    )
                }
                Text(
                    "Before move-in",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.95f),
                    modifier = Modifier
                        .background(Color.Black.copy(alpha = 0.55f), CircleShape)
                        .border(0.8.dp, Color.White.copy(alpha = 0.22f), CircleShape)
                        .padding(horizontal = 8.dp, vertical = 5.dp),
                )
            }
            Spacer(Modifier.weight(1f))
            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                IssueTags.forEachIndexed { index, tag ->
                    val tagScale by animateFloatAsState(
                        targetValue = if (tagsVisible) 1f else 0.9f,
                        animationSpec = MMMotion.welcomeTagEnterSpec(reduceMotion),
                        label = "tagScale$index",
                    )
                    EvidenceMarker(
                        label = tag.label,
                        priorDamage = tag.priorDamage,
                        modifier = Modifier
                            .scale(tagScale)
                            .padding(start = when (tag.id) {
                                "prior" -> 4.dp
                                "paint" -> 22.dp
                                "stain" -> 36.dp
                                else -> 0.dp
                            }),
                    )
                }
            }
        }
    }
}

@Composable
private fun EvidenceMarker(
    label: String,
    priorDamage: Boolean,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(if (priorDamage) 7.dp else 5.dp)
                    .clip(CircleShape)
                    .background(if (priorDamage) Color.White else InspectionGreen),
            )
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(if (priorDamage) 10.dp else 7.dp)
                    .background(Color.White.copy(alpha = 0.65f)),
            )
        }
        Spacer(Modifier.width(5.dp))
        Text(
            label,
            fontSize = if (priorDamage) 12.sp else 11.sp,
            fontWeight = if (priorDamage) FontWeight.Bold else FontWeight.SemiBold,
            color = Color.White.copy(alpha = if (priorDamage) 1f else 0.96f),
            modifier = Modifier
                .background(
                    if (priorDamage) Color.Black.copy(alpha = 0.82f) else InspectionGreen.copy(alpha = 0.92f),
                    CircleShape,
                )
                .border(
                    width = if (priorDamage) 1.15.dp else 0.5.dp,
                    color = if (priorDamage) Color.White.copy(alpha = 0.9f) else Color.White.copy(alpha = 0.18f),
                    shape = CircleShape,
                )
                .padding(
                    horizontal = if (priorDamage) 10.dp else 9.dp,
                    vertical = 5.dp,
                ),
        )
    }
}

@Composable
private fun ProofCaptureBar() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(ProofBarHeight)
            .background(MMColors.Card.copy(alpha = 0.98f))
            .padding(horizontal = 14.dp)
            .padding(top = 1.dp, bottom = 8.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(MMColors.CardStroke.copy(alpha = 0.55f)),
        )
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = null,
                tint = MMColors.Primary,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Saved to your vault",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = MMColors.TextPrimary,
            )
            Spacer(Modifier.weight(1f))
            Text(
                "Report ready",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.Primary.copy(alpha = 0.92f),
                modifier = Modifier
                    .background(MMColors.Primary.copy(alpha = 0.16f), CircleShape)
                    .border(0.85.dp, MMColors.Primary.copy(alpha = 0.48f), CircleShape)
                    .padding(horizontal = 9.dp, vertical = 5.dp),
            )
        }
        Text(
            "Move-in · Apr 14 · 5:42 PM",
            fontSize = 10.5.sp,
            fontWeight = FontWeight.Medium,
            color = MMColors.TextSecondary.copy(alpha = 0.78f),
            modifier = Modifier.padding(top = 5.dp),
        )
        Text(
            "12 photos · 3 issues",
            fontSize = 10.5.sp,
            color = MMColors.TextSecondary.copy(alpha = 0.72f),
            modifier = Modifier.padding(top = 1.dp),
            maxLines = 1,
        )
    }
}

@Composable
private fun FocusBrackets(modifier: Modifier = Modifier) {
    val len = 18.dp
    val pad = 12.dp
    Box(modifier = modifier.padding(pad)) {
        listOf(
            Alignment.TopStart,
            Alignment.TopEnd,
            Alignment.BottomStart,
            Alignment.BottomEnd,
        ).forEach { alignment ->
            WelcomeFocusBracket(
                length = len,
                corner = alignment,
                modifier = Modifier.align(alignment),
            )
        }
    }
}

@Composable
private fun WelcomeFocusBracket(
    length: androidx.compose.ui.unit.Dp,
    corner: Alignment,
    modifier: Modifier = Modifier,
) {
    val stroke = Color.White.copy(alpha = 0.58f)
    Box(modifier = modifier.size(length)) {
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
