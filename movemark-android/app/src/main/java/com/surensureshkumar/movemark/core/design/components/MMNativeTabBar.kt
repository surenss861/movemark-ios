package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Description
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.navigation.MainTab

@Composable
fun MMNativeTabBar(selected: MainTab, onSelect: (MainTab) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MMColors.TabBarFill)
            .navigationBarsPadding()
            .padding(vertical = 10.dp, horizontal = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TabItem(MainTab.Vault, "Vault", Icons.Default.Home, selected, onSelect)
        TabItem(MainTab.Rooms, "Rooms", Icons.Default.PhotoCamera, selected, onSelect)
        TabItem(MainTab.Reports, "Report", Icons.Default.Description, selected, onSelect)
        TabItem(MainTab.Account, "Account", Icons.Default.AccountCircle, selected, onSelect)
    }
}

@Composable
private fun TabItem(
    tab: MainTab,
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: MainTab,
    onSelect: (MainTab) -> Unit,
) {
    val active = tab == selected
    ColumnTab(
        modifier = Modifier.clickable { onSelect(tab) },
        active = active,
        label = label,
        icon = icon,
    )
}

@Composable
private fun ColumnTab(
    modifier: Modifier,
    active: Boolean,
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
) {
    androidx.compose.foundation.layout.Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(icon, contentDescription = label, tint = if (active) MMColors.Primary else MMColors.TextMuted)
        Text(
            label,
            style = androidx.compose.material3.MaterialTheme.typography.labelSmall,
            color = if (active) MMColors.Primary else MMColors.TextMuted,
        )
    }
}
