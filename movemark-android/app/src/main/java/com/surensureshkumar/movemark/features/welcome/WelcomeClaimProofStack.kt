package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion

private val artifactRaised = Color(0xFF1A1C1B)

/**
 * Welcome-only — damage claim vs saved proof artifact. No photo-card hero.
 */
@Composable
fun WelcomeClaimProofStack(
    proofVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    drawableResId: Int = R.drawable.welcome_kitchen_main,
) {
    val stackRadius = 28.dp
    val proofAlpha by animateFloatAsState(
        if (proofVisible) 1f else 0f,
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 340),
        label = "claimProofAlpha",
    )
    val proofOffsetY by animateFloatAsState(
        if (proofVisible) 0f else 6f,
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 340),
        label = "claimProofOffset",
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(14.dp, RoundedCornerShape(stackRadius), ambientColor = Color.Black.copy(0.28f))
            .clip(RoundedCornerShape(stackRadius))
            .border(1.dp, MMColors.CardStroke.copy(alpha = 0.95f), RoundedCornerShape(stackRadius))
            .background(artifactRaised),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            Text(
                "DAMAGE CLAIM",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.SemanticWarning.copy(alpha = 0.82f),
                letterSpacing = 0.6.sp,
            )
            Text(
                "Kitchen cabinet damage",
                fontSize = 15.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.TextPrimary,
                modifier = Modifier.padding(top = 5.dp),
                maxLines = 2,
            )
            Text(
                "Potential charge · $450",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = MMColors.SemanticWarning.copy(alpha = 0.88f),
                modifier = Modifier.padding(top = 5.dp),
                maxLines = 1,
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(horizontal = 16.dp),
            thickness = 1.dp,
            color = MMColors.CardStroke.copy(alpha = 0.55f),
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .alpha(proofAlpha)
                .offset(y = proofOffsetY.dp)
                .padding(horizontal = 16.dp, vertical = 13.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Image(
                painter = painterResource(drawableResId),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(width = 108.dp, height = 78.dp)
                    .clip(RoundedCornerShape(11.dp))
                    .border(0.75.dp, MMColors.CardStroke.copy(alpha = 0.9f), RoundedCornerShape(11.dp)),
            )
            Spacer(Modifier.width(12.dp))
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = MMColors.Primary.copy(alpha = 0.9f),
                        modifier = Modifier.size(14.dp),
                    )
                    Spacer(Modifier.width(5.dp))
                    Text(
                        "Already documented",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMColors.TextPrimary,
                        maxLines = 1,
                    )
                }
                Text(
                    "Kitchen · Apr 14 · 5:42 PM",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextSecondary,
                    modifier = Modifier.padding(top = 4.dp),
                    maxLines = 1,
                )
                Text(
                    "12 photos attached",
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextMuted,
                    modifier = Modifier.padding(top = 4.dp),
                    maxLines = 1,
                )
            }
        }

        HorizontalDivider(
            modifier = Modifier.padding(horizontal = 16.dp),
            thickness = 1.dp,
            color = MMColors.CardStroke.copy(alpha = 0.55f),
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Outlined.Description,
                contentDescription = null,
                tint = MMColors.TextMuted.copy(alpha = 0.9f),
                modifier = Modifier.size(15.dp),
            )
            Spacer(Modifier.width(10.dp))
            Column {
                Text(
                    "Move-in report ready",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.TextPrimary,
                    maxLines = 1,
                )
                Text(
                    "Export organized proof when you need it.",
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = MMColors.TextMuted,
                    modifier = Modifier.padding(top = 2.dp),
                    maxLines = 1,
                )
            }
        }
    }
}
