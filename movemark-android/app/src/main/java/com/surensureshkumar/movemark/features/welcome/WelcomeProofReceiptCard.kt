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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

private val welcomeIssueTags = listOf("Already there", "Chipped paint")

/**
 * Welcome-only saved proof receipt — photo-first, no report peek or stacked layers.
 */
@Composable
fun WelcomeProofReceiptCard(
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    photoHeight: Dp = 186.dp,
    cornerRadius: Dp = 28.dp,
    drawableResId: Int = R.drawable.welcome_kitchen_main,
) {
    val shape = RoundedCornerShape(cornerRadius)
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = shape,
        color = MMColors.EvidenceCard,
        border = androidx.compose.foundation.BorderStroke(1.dp, MMColors.CardStroke),
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "MOVE-IN PROOF",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.8.sp,
                    color = MMColors.TextMuted,
                    maxLines = 1,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Text(
                    "SAVED",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.5.sp,
                    color = MMColors.Primary.copy(alpha = 0.88f),
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .height(photoHeight),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(22.dp))
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
                            .height(52.dp)
                            .align(Alignment.BottomCenter)
                            .background(
                                androidx.compose.ui.graphics.Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.38f)),
                                ),
                            ),
                    )
                }
                if (tagsVisible) {
                    Row(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(start = 14.dp, bottom = 14.dp, end = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        welcomeIssueTags.forEachIndexed { index, tag ->
                            val tagScale by animateFloatAsState(
                                if (tagsVisible) 1f else 0.92f,
                                MMMotion.welcomeTagEnterSpec(reduceMotion),
                                label = "welcomeReceiptTag$index",
                            )
                            Box(
                                modifier = Modifier
                                    .scale(tagScale)
                                    .clip(RoundedCornerShape(8.dp))
                                    .then(
                                        if (index == 0) {
                                            Modifier
                                                .background(Color.Black.copy(alpha = 0.72f))
                                                .border(0.5.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(8.dp))
                                        } else {
                                            Modifier
                                                .background(MMColors.Primary.copy(alpha = 0.22f))
                                                .border(0.5.dp, MMColors.Primary.copy(alpha = 0.32f), RoundedCornerShape(8.dp))
                                        },
                                    )
                                    .padding(horizontal = 8.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    tag,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color.White.copy(alpha = 0.95f),
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(76.dp)
                    .background(MMColors.FieldFill.copy(alpha = 0.45f))
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(MMColors.CardStroke.copy(alpha = 0.55f)),
                )
                Row(
                    modifier = Modifier.padding(top = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = MMColors.Primary.copy(alpha = 0.9f),
                        modifier = Modifier.size(22.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Column {
                        Text(
                            "Kitchen documented",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.TextPrimary,
                            maxLines = 1,
                        )
                        Text(
                            "12 photos · Verified Apr 14",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = MMColors.TextMuted,
                            modifier = Modifier.padding(top = 2.dp),
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
