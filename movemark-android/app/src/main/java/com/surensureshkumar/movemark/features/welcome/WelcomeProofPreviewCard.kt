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
 * Welcome-only saved proof preview — simpler than in-app [MMProofArtifactCard].
 */
@Composable
fun WelcomeProofPreviewCard(
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    photoHeight: Dp = 160.dp,
    cornerRadius: Dp = 20.dp,
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
                    .padding(horizontal = 14.dp)
                    .padding(top = 12.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "MOVE-IN PROOF",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.7.sp,
                    color = MMColors.TextMuted,
                    maxLines = 1,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Text(
                    "SAVED",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.Primary.copy(alpha = 0.95f),
                    modifier = Modifier
                        .background(MMColors.Primary.copy(alpha = 0.16f), RoundedCornerShape(50))
                        .border(0.85.dp, MMColors.Primary.copy(alpha = 0.48f), RoundedCornerShape(50))
                        .padding(horizontal = 9.dp, vertical = 5.dp),
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
                        .clip(RoundedCornerShape(14.dp))
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
                            .height(56.dp)
                            .align(Alignment.BottomCenter)
                            .background(
                                androidx.compose.ui.graphics.Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.42f)),
                                ),
                            ),
                    )
                }
                if (tagsVisible) {
                    Row(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(start = 12.dp, bottom = 12.dp, end = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        welcomeIssueTags.forEachIndexed { index, tag ->
                            val tagScale by animateFloatAsState(
                                if (tagsVisible) 1f else 0.92f,
                                MMMotion.welcomeTagEnterSpec(reduceMotion),
                                label = "welcomeTag$index",
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

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .padding(bottom = 12.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .padding(top = 12.dp)
                        .background(MMColors.CardStroke.copy(alpha = 0.65f)),
                )
                Row(
                    modifier = Modifier.padding(top = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = MMColors.Primary.copy(alpha = 0.95f),
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "Kitchen documented",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMColors.TextPrimary,
                        maxLines = 1,
                    )
                }
                Text(
                    "12 photos · Verified Apr 14",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextMuted,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
