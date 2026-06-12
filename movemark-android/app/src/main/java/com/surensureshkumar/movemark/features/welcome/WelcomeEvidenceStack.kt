package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

private val issueCallouts = listOf("Already there", "Chipped paint")

/**
 * Welcome-only hero — saved evidence sitting on a neutral report sheet.
 */
@Composable
fun WelcomeEvidenceStack(
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    photoHeight: Dp = 196.dp,
    drawableResId: Int = R.drawable.welcome_kitchen_main,
) {
    val cardRadius = 28.dp
    val photoRadius = 23.dp
    val sheetOffset = 10.dp

    Box(modifier = modifier.fillMaxWidth()) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = sheetOffset + 6.dp, start = sheetOffset + 4.dp, end = 2.dp, bottom = 2.dp)
                .height(photoHeight + 56.dp),
            shape = RoundedCornerShape(cardRadius - 2.dp),
            color = MMColors.PaperSurface.copy(alpha = 0.12f),
            border = androidx.compose.foundation.BorderStroke(0.75.dp, MMColors.CardStroke.copy(alpha = 0.35f)),
        ) {}

        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(6.dp, RoundedCornerShape(cardRadius), ambientColor = Color.Black.copy(0.22f)),
            shape = RoundedCornerShape(cardRadius),
            color = MMColors.EvidenceCard,
            border = androidx.compose.foundation.BorderStroke(1.dp, MMColors.CardStroke.copy(alpha = 0.9f)),
        ) {
            Column {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 12.dp)
                        .height(photoHeight),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(RoundedCornerShape(photoRadius))
                            .background(MMColors.FieldFill),
                    ) {
                        Image(
                            painter = painterResource(drawableResId),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize(),
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp)
                                .align(Alignment.BottomCenter)
                                .background(
                                    androidx.compose.ui.graphics.Brush.verticalGradient(
                                        listOf(Color.Transparent, Color.Black.copy(alpha = 0.34f)),
                                    ),
                                ),
                        )
                    }

                    Text(
                        "Kitchen · Apr 14 · 5:42 PM",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        fontFamily = FontFamily.Monospace,
                        color = Color.White.copy(alpha = 0.92f),
                        maxLines = 1,
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(start = 12.dp, top = 12.dp)
                            .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(6.dp))
                            .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(6.dp))
                            .padding(horizontal = 8.dp, vertical = 5.dp),
                    )

                    if (tagsVisible) {
                        Column(
                            modifier = Modifier
                                .align(Alignment.BottomStart)
                                .padding(start = 12.dp, bottom = 12.dp, end = 8.dp),
                        ) {
                            issueCallouts.forEachIndexed { index, label ->
                                val tagScale by animateFloatAsState(
                                    if (tagsVisible) 1f else 0.94f,
                                    MMMotion.welcomeTagEnterSpec(reduceMotion),
                                    label = "evidenceCallout$index",
                                )
                                Text(
                                    label,
                                    fontSize = 9.5.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = Color.White.copy(alpha = 0.9f),
                                    maxLines = 1,
                                    modifier = Modifier
                                        .scale(tagScale)
                                        .padding(top = if (index == 0) 0.dp else 5.dp)
                                        .background(Color.Black.copy(alpha = 0.62f), RoundedCornerShape(5.dp))
                                        .border(0.5.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(5.dp))
                                        .padding(horizontal = 7.dp, vertical = 3.dp),
                                )
                            }
                        }
                    }
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MMColors.FieldFill.copy(alpha = 0.38f))
                        .padding(horizontal = 14.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = MMColors.Primary.copy(alpha = 0.85f),
                        modifier = Modifier
                            .size(18.dp)
                            .padding(top = 1.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            "Saved proof record",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.TextPrimary,
                            maxLines = 1,
                        )
                        Text(
                            "12 photos attached · Move-in inspection",
                            fontSize = 11.5.sp,
                            fontWeight = FontWeight.Medium,
                            color = MMColors.TextMuted,
                            modifier = Modifier.padding(top = 2.dp),
                            maxLines = 2,
                        )
                    }
                    Text(
                        "Report-ready",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = MMColors.TextMuted.copy(alpha = 0.85f),
                        modifier = Modifier.padding(top = 2.dp),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}
