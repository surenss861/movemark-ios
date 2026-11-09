package com.surensureshkumar.movemark.features.main

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.components.MMFloatingPillDock
import kotlinx.coroutines.launch
import com.surensureshkumar.movemark.core.navigation.MainTab
import com.surensureshkumar.movemark.features.account.AccountScreen
import com.surensureshkumar.movemark.features.paywall.ProPaywallScreen
import com.surensureshkumar.movemark.features.reports.ReportsScreen
import com.surensureshkumar.movemark.features.rooms.RoomsScreen
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import com.surensureshkumar.movemark.features.vault.VaultScreen
import com.surensureshkumar.movemark.domain.ProofPhase
import java.util.UUID

@Composable
fun MainShellScreen(
    onOpenRoom: (UUID) -> Unit,
    onOpenRoomPhase: (UUID, ProofPhase) -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onOpenDisputePacket: () -> Unit = {},
    onSignOut: () -> Unit,
    onAddProperty: () -> Unit,
    onOpenMaintenance: () -> Unit,
    onOpenDocuments: () -> Unit,
    viewModel: MainShellViewModel = hiltViewModel(),
) {
    var tab by rememberSaveable { mutableStateOf(MainTab.Vault) }
    var paywallReason by remember { mutableStateOf<PaywallReason?>(null) }
    val pendingTab by viewModel.pendingTab.collectAsState()

    LaunchedEffect(pendingTab) {
        pendingTab?.let { tab = it }
        if (pendingTab != null) viewModel.clearTabRequest()
    }

    val vaultScroll = rememberScrollState()
    val reportsScroll = rememberScrollState()
    val accountScroll = rememberScrollState()
    val scope = rememberCoroutineScope()

    // The rental's rooms open from Proof as a pushed page (iOS has three root tabs: Proof, Reports, Account).
    // System back returns to Proof; the dock stays hidden there as on any pushed screen.
    BackHandler(enabled = tab == MainTab.Rooms) { tab = MainTab.Vault }
    // The paywall overlay closes on system back instead of leaving the app.
    BackHandler(enabled = paywallReason != null) { paywallReason = null }

    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().background(MMInk.Sheet)) {
            when (tab) {
                MainTab.Vault -> VaultScreen(
                    onOpenRoom = onOpenRoom,
                    onOpenRoomPhase = onOpenRoomPhase,
                    onOpenMoveOutProof = onOpenMoveOutProof,
                    onAddProperty = onAddProperty,
                    onShowPaywall = { paywallReason = it },
                    onOpenReports = { tab = MainTab.Reports },
                    onOpenMaintenance = onOpenMaintenance,
                    onOpenDocuments = onOpenDocuments,
                    onOpenRooms = { tab = MainTab.Rooms },
                    scrollState = vaultScroll,
                )
                MainTab.Rooms -> RoomsScreen(
                    onOpenRoom = onOpenRoom,
                    onBack = { tab = MainTab.Vault },
                    onOpenReports = { tab = MainTab.Reports },
                )
                MainTab.Reports -> ReportsScreen(
                    onContinueRoomProof = { tab = MainTab.Rooms },
                    onOpenMoveOutProof = onOpenMoveOutProof,
                    onOpenVault = { tab = MainTab.Vault },
                    onShowPaywall = { paywallReason = it },
                    onOpenDisputePacket = onOpenDisputePacket,
                    scrollState = reportsScroll,
                )
                MainTab.Account -> AccountScreen(
                    onSignOut = onSignOut,
                    onShowPaywall = { paywallReason = it },
                    scrollState = accountScroll,
                )
            }
            if (tab != MainTab.Rooms) {
                MMFloatingPillDock(
                    selected = tab,
                    onSelect = { tab = it },
                    onReselect = { reselected ->
                        val state = when (reselected) {
                            MainTab.Reports -> reportsScroll
                            MainTab.Account -> accountScroll
                            else -> vaultScroll
                        }
                        scope.launch { state.animateScrollTo(0) }
                    },
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }
        paywallReason?.let { reason ->
            ProPaywallScreen(
                reason = reason,
                onClose = { paywallReason = null },
            )
        }
    }
}
