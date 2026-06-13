package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

private val stripRaised = Color(0xFF1A1C1B)
private val trustItems = listOf(
    "Private proof vault",
    "Move-in report included",
    "Upgrade later for move-out and disputes",
)

/**
 * Compact auth proof context — vault strip or trust rows. No dashboard card.
 */
@Composable
fun AuthProofVaultStrip(
    mode: AuthMode,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(stripRaised)
            .border(0.75.dp, MMColors.CardStroke.copy(alpha = 0.55f), shape)
            .padding(horizontal = 12.dp, vertical = 11.dp),
    ) {
        if (mode == AuthMode.SignIn) {
            Row(Modifier.fillMaxWidth()) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = MMColors.Primary.copy(alpha = 0.9f),
                    modifier = Modifier
                        .size(15.dp)
                        .padding(top = 1.dp),
                )
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(
                        "Proof vault ready",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMColors.TextPrimary,
                        maxLines = 1,
                    )
                    Text(
                        "Pick up where your room proof left off.",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = MMColors.TextSecondary,
                        modifier = Modifier.padding(top = 3.dp),
                        maxLines = 2,
                    )
                    Text(
                        "Move-in proof · Reports when needed",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MMColors.TextMuted,
                        modifier = Modifier.padding(top = 4.dp),
                        maxLines = 1,
                    )
                }
            }
        } else {
            trustItems.forEachIndexed { index, label ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = if (index == 0) 0.dp else 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = MMColors.Primary.copy(alpha = 0.88f),
                        modifier = Modifier.size(13.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        label,
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = MMColors.TextSecondary,
                        maxLines = 2,
                    )
                }
            }
        }
    }
}
