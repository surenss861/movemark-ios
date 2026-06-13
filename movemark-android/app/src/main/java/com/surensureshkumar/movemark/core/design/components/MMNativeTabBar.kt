package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.Capsule
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.navigation.MainTab

@Composable
fun MMNativeTabBar(selected: MainTab, onSelect: (MainTab) -> Unit) {
    val reduceMotion = MMMotion.rememberReduceMotion()

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(bottom = 10.dp),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Surface(
            modifier = Modifier
                .widthIn(min = 260.dp, max = 310.dp)
                .height(70.dp),
            shape = RoundedCornerShape(26.dp),
            color = MMColors.EvidenceCardRaised.copy(alpha = 0.96f),
            border = BorderStroke(
                1.dp,
                Color(0xFF21B866).copy(alpha = 0.22f),
            ),
            shadowElevation = 8.dp,
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 6.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                DockTabItem(MainTab.Vault, "Proof", Icons.Default.Home, selected, onSelect, reduceMotion)
                DockTabItem(MainTab.Rooms, "Rooms", Icons.Default.PhotoCamera, selected, onSelect, reduceMotion)
                DockTabItem(MainTab.Reports, "Reports", Icons.Default.Description, selected, onSelect, reduceMotion)
                DockTabItem(MainTab.Account, "Account", Icons.Default.AccountCircle, selected, onSelect, reduceMotion)
            }
        }
    }
}

@Composable
private fun DockTabItem(
    tab: MainTab,
    label: String,
    icon: ImageVector,
    selected: MainTab,
    onSelect: (MainTab) -> Unit,
    reduceMotion: Boolean,
) {
    val active = tab == selected
    val iconTint by animateColorAsState(
        if (active) MMColors.TextPrimary else MMColors.TextMuted.copy(alpha = 0.62f),
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 180),
        label = "dockIconTint",
    )
    val labelAlpha by animateFloatAsState(
        if (active) 1f else 0.55f,
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 180),
        label = "dockLabelAlpha",
    )
    val iconScale by animateFloatAsState(
        if (active && !reduceMotion) 1.04f else 1f,
        MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 180),
        label = "dockIconScale",
    )

    Box(
        modifier = Modifier
            .heightIn(min = 44.dp)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) { onSelect(tab) },
        contentAlignment = Alignment.Center,
    ) {
        if (active) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .padding(horizontal = 2.dp, vertical = 6.dp)
                    .background(MMColors.Primary.copy(alpha = 0.14f), Capsule),
            )
        }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp),
        ) {
            Icon(
                icon,
                contentDescription = label,
                tint = iconTint,
                modifier = Modifier.scale(iconScale),
            )
            Text(
                label,
                fontSize = 10.sp,
                fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                color = iconTint,
                modifier = Modifier
                    .padding(top = if (active) 4.dp else 2.dp)
                    .alpha(labelAlpha),
            )
        }
    }
}
