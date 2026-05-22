package com.surensureshkumar.movemark.features.main

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.components.MMNativeTabBar
import com.surensureshkumar.movemark.core.navigation.MainTab
import com.surensureshkumar.movemark.features.account.AccountScreen
import com.surensureshkumar.movemark.features.reports.ReportsScreen
import com.surensureshkumar.movemark.features.rooms.RoomsScreen
import com.surensureshkumar.movemark.features.vault.VaultScreen
import java.util.UUID

@Composable
fun MainShellScreen(
    onOpenRoom: (UUID) -> Unit,
    onSignOut: () -> Unit,
    viewModel: MainShellViewModel = hiltViewModel(),
) {
    var tab by rememberSaveable { mutableStateOf(MainTab.Vault) }

    MMBackground {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            bottomBar = {
                MMNativeTabBar(selected = tab, onSelect = { tab = it })
            },
        ) { padding ->
            when (tab) {
                MainTab.Vault -> VaultScreen(
                    modifier = Modifier.padding(padding),
                    onOpenRoom = onOpenRoom,
                )
                MainTab.Rooms -> RoomsScreen(
                    modifier = Modifier.padding(padding),
                    onOpenRoom = onOpenRoom,
                )
                MainTab.Reports -> ReportsScreen(
                    modifier = Modifier.padding(padding),
                    onContinueRoomProof = { tab = MainTab.Rooms },
                )
                MainTab.Account -> AccountScreen(
                    modifier = Modifier.padding(padding),
                    onSignOut = onSignOut,
                )
            }
        }
    }
}
