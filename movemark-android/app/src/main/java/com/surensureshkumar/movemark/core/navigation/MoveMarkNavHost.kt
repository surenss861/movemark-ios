package com.surensureshkumar.movemark.core.navigation

import com.surensureshkumar.movemark.features.account.AccountViewModel
import com.surensureshkumar.movemark.features.legal.LegalAcceptanceScreen
import com.surensureshkumar.movemark.features.legal.LegalGatePhase
import com.surensureshkumar.movemark.features.legal.LegalGateViewModel
import com.surensureshkumar.movemark.features.legal.LegalStatusUnavailableScreen
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import com.surensureshkumar.movemark.core.startup.StartupDestination
import com.surensureshkumar.movemark.core.startup.StartupOfflineScreen
import com.surensureshkumar.movemark.core.startup.StartupRouter
import com.surensureshkumar.movemark.core.startup.LegalRouting
import com.surensureshkumar.movemark.core.startup.FirstRunStatus
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.surensureshkumar.movemark.data.backend.LegalAcceptanceRequiredSignal
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.surensureshkumar.movemark.core.di.MoveMarkEntryPoints
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.features.auth.AuthMode
import com.surensureshkumar.movemark.features.auth.AuthScreen
import com.surensureshkumar.movemark.features.documents.DocumentsScreen
import com.surensureshkumar.movemark.features.firstrun.CreatePropertyScreen
import com.surensureshkumar.movemark.features.firstrun.FirstRunFlowScreen
import com.surensureshkumar.movemark.features.maintenance.MaintenanceIssueDetailScreen
import com.surensureshkumar.movemark.features.maintenance.MaintenanceLogScreen
import com.surensureshkumar.movemark.features.main.MainShellScreen
import com.surensureshkumar.movemark.features.moveout.MoveOutRoomsScreen
import com.surensureshkumar.movemark.features.dispute.DisputePacketScreen
import com.surensureshkumar.movemark.domain.DisputePacketModel
import com.surensureshkumar.movemark.features.proof.RoomProofScreen
import com.surensureshkumar.movemark.features.proof.SavedProofReceiptScreen
import com.surensureshkumar.movemark.features.auth.PasswordResetLink
import com.surensureshkumar.movemark.features.auth.PasswordResetScreen
import com.surensureshkumar.movemark.features.proof.camera.CameraCaptureScreen
import com.surensureshkumar.movemark.features.welcome.WelcomeRoute
import com.surensureshkumar.movemark.features.welcome.WelcomeViewModel
import dagger.hilt.android.EntryPointAccessors
import java.util.UUID

private val proofPhaseNavArg = navArgument(Routes.ProofPhaseArg) { type = NavType.StringType }
private val roomIdNavArg = navArgument(Routes.RoomProofArg) { type = NavType.StringType }

@Composable
fun MoveMarkNavHost() {
    val context = LocalContext.current
    val entryPoints = remember(context) {
        EntryPointAccessors.fromApplication(
            context.applicationContext,
            MoveMarkEntryPoints::class.java,
        )
    }
    val mainTabRequest = remember(entryPoints) { entryPoints.mainTabRequest() }
    val sessionManager = remember(entryPoints) { entryPoints.sessionManager() }
    val navController = rememberNavController()
    // iOS PasswordResetView: a token sets a new password; an error= link (or a rejected token) shows "Link expired".
    val resetLink by PasswordResetLink.payload.collectAsState()
    val resetAuthState by sessionManager.authState.collectAsState()
    resetLink?.let { link ->
        val token = (link as? PasswordResetLink.Payload.Token)?.value
        key(link) {
            PasswordResetScreen(
                onReset = { password, confirm -> sessionManager.completePasswordReset(token.orEmpty(), password, confirm) },
                onDone = PasswordResetLink::consume,
                linkExpired = token == null,
                signedIn = resetAuthState == AuthState.SignedIn,
                onSignIn = {
                    PasswordResetLink.consume()
                    navController.navigate(Routes.auth("signIn")) { launchSingleTop = true }
                },
                onRequestNewLink = {
                    PasswordResetLink.consume()
                    navController.navigate(Routes.auth("resetPassword")) { launchSingleTop = true }
                },
            )
        }
    }
    val welcomeVm: WelcomeViewModel = hiltViewModel()
    val authState by welcomeVm.authState.collectAsState()
    val rentalStatus by welcomeVm.rentalStatus.collectAsState()
    val firstRun by welcomeVm.firstRun.collectAsState()
    val rechecking by welcomeVm.rechecking.collectAsState()
    val legalVm: LegalGateViewModel = hiltViewModel()
    val legal by legalVm.state.collectAsState()

    LaunchedEffect(authState) {
        if (authState == AuthState.SignedIn) legalVm.refresh() else legalVm.reset()
    }
    // A document published (or enforcement switched on) while the app is open: re-check on return to the foreground
    // and when the API refuses with LEGAL_ACCEPTANCE_REQUIRED.
    LaunchedEffect(authState) {
        if (authState == AuthState.SignedIn) LegalAcceptanceRequiredSignal.signals.collect { legalVm.recheck() }
    }
    // Connection back, foreground, or "Try again": the coordinator re-checks what it couldn't confirm, and asks for the
    // legal status again here (an unavailable status retries; an answered one re-checks).
    LaunchedEffect(authState) {
        if (authState == AuthState.SignedIn) welcomeVm.legalRecheck.collect {
            if (legalVm.state.value.statusUnavailable) legalVm.retryStatus() else legalVm.recheck()
        }
    }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, authState) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START && authState == AuthState.SignedIn) {
                legalVm.recheck()
                welcomeVm.recheck()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // One decision for every launch gate (StartupRouter): a lookup that failed or hasn't answered never opens
    // first run (moment picker, rental setup, first room). The name is not a gate (iOS 1.4: identity lives in
    // Account). Only a change of decision navigates, so a renter deep in the app isn't pulled back to the top when a
    // re-check confirms what they already had.
    val destination = StartupRouter.resolve(
        auth = authState,
        // The design line's verified legal phases: only a server-confirmed "needs acceptance" shows the agreement.
        legal = when (legal.phase) {
            LegalGatePhase.Unavailable -> LegalRouting.StatusUnavailable
            LegalGatePhase.Loading -> LegalRouting.Pending
            LegalGatePhase.NeedsAcceptance -> LegalRouting.Required
            LegalGatePhase.Accepted, LegalGatePhase.OpenOnCache -> LegalRouting.Clear
        },
        rental = rentalStatus,
        firstRun = firstRun,
    )
    var lastRouted by rememberSaveable { mutableStateOf<StartupDestination?>(null) }
    LaunchedEffect(destination) {
        val route = when (destination) {
            StartupDestination.Hold -> return@LaunchedEffect
            StartupDestination.SignIn -> Routes.Welcome
            StartupDestination.LegalAcceptance -> Routes.LegalAcceptance
            StartupDestination.LegalStatusUnavailable -> Routes.LegalStatusUnavailable
            StartupDestination.Onboarding -> Routes.Onboarding
            StartupDestination.Main -> Routes.Main
            StartupDestination.Offline -> Routes.StartupOffline
        }
        val current = navController.currentDestination?.route
        // Signed out: anywhere but Welcome and its sign-in screen goes back to Welcome.
        if (destination == StartupDestination.SignIn && (current == Routes.Welcome || current == Routes.Auth)) {
            lastRouted = destination
            return@LaunchedEffect
        }
        if (destination == lastRouted && current != null && current != Routes.Welcome) return@LaunchedEffect
        lastRouted = destination
        if (current != route) {
            navController.navigate(route) {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    NavHost(navController = navController, startDestination = Routes.Welcome) {
        composable(Routes.Welcome) {
            WelcomeRoute(
                onStartMoveIn = {
                    navController.navigate(Routes.auth("signUp"))
                },
                onSignIn = {
                    navController.navigate(Routes.auth("signIn"))
                },
            )
        }
        composable(
            route = Routes.Auth,
            arguments = listOf(navArgument("mode") { defaultValue = "signIn" }),
        ) { entry ->
            val mode = entry.arguments?.getString("mode")
            AuthScreen(
                initialMode = AuthMode.fromRoute(mode),
                onDismiss = { navController.popBackStack() },
            )
        }
        composable(Routes.LegalAcceptance) {
            val accountVm: AccountViewModel = hiltViewModel()
            val deleting by accountVm.deleting.collectAsState()
            val accountNotice by accountVm.notice.collectAsState()
            LegalAcceptanceScreen(
                state = legal,
                onAccept = { band -> legalVm.accept(band) },
                onSignOut = { accountVm.signOut {} },
                onDeleteAccount = { accountVm.deleteAccount {} },
                deleting = deleting,
                deleteError = accountNotice?.takeIf { it.isError }?.message,
            )
        }
        composable(Routes.LegalStatusUnavailable) {
            val accountVm: AccountViewModel = hiltViewModel()
            LegalStatusUnavailableScreen(
                isRetrying = legal.isRetrying,
                onRetry = { legalVm.retryStatus() },
                onSignOut = { accountVm.signOut {} },
            )
        }
        composable(Routes.StartupOffline) {
            val accountVm: AccountViewModel = hiltViewModel()
            StartupOfflineScreen(
                isRetrying = rechecking,
                onRetry = { welcomeVm.recheck() },
                onSignOut = { accountVm.signOut {} },
            )
        }
        composable(Routes.Onboarding) {
            // iOS FirstRunProofFlowView: "What are you documenting?" → rental setup → first room, then its capture in
            // the moment's phase (move-out evidence for "Moving out").
            val accountVm: AccountViewModel = hiltViewModel()
            FirstRunFlowScreen(
                onStartProof = { roomId, phase ->
                    navController.navigate(Routes.roomProof(roomId.toString(), phase))
                },
                onSignOut = { accountVm.signOut {} },
            )
        }
        composable(Routes.Main) {
            MainShellScreen(
                onOpenRoom = { roomId ->
                    navController.navigate(Routes.roomProof(roomId.toString(), ProofPhase.MoveIn))
                },
                onOpenRoomPhase = { roomId, phase ->
                    navController.navigate(Routes.roomProof(roomId.toString(), phase))
                },
                onOpenMoveOutProof = {
                    navController.navigate(Routes.MoveOutRooms)
                },
                onOpenDisputePacket = { navController.navigate(Routes.DisputePacket) },
                onSignOut = {
                    navController.navigate(Routes.Welcome) {
                        popUpTo(0) { inclusive = true }
                    }
                },
                onAddProperty = { navController.navigate(Routes.AddProperty) },
                onOpenMaintenance = { navController.navigate(Routes.MaintenanceLog) },
                onOpenDocuments = { navController.navigate(Routes.Documents) },
            )
        }
        composable(Routes.Documents) {
            // Edit rental opens as a sheet over the records (iOS EditPropertyView in MMSheetScaffold).
            DocumentsScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.MaintenanceLog) {
            MaintenanceLogScreen(
                onBack = { navController.popBackStack() },
                onOpenIssue = { issueId ->
                    navController.navigate(Routes.maintenanceIssueDetail(issueId.toString()))
                },
            )
        }
        composable(
            route = Routes.MaintenanceIssueDetail,
            arguments = listOf(navArgument(Routes.MaintenanceIssueArg) { type = NavType.StringType }),
        ) { entry ->
            val issueId = entry.arguments?.getString(Routes.MaintenanceIssueArg)?.let { UUID.fromString(it) }
            if (issueId != null) {
                MaintenanceIssueDetailScreen(
                    issueId = issueId,
                    onBack = { navController.popBackStack() },
                )
            }
        }
        composable(Routes.AddProperty) {
            CreatePropertyScreen(
                onCreated = { navController.popBackStack() },
                askLease = true,
            )
        }
        composable(Routes.DisputePacket) {
            DisputePacketScreen(
                onBack = { navController.popBackStack() },
                onCaptureMoveOut = { roomId -> navController.navigate(Routes.roomProof(roomId.toString(), ProofPhase.MoveOut)) },
                onMissing = { target ->
                    when (target) {
                        DisputePacketModel.Missing.Target.RentalRecord -> navController.navigate(Routes.Documents)
                        DisputePacketModel.Missing.Target.MoveOut -> navController.navigate(Routes.MoveOutRooms)
                        DisputePacketModel.Missing.Target.Rooms -> { mainTabRequest.request(MainTab.Rooms); navController.popBackStack() }
                        DisputePacketModel.Missing.Target.Reports -> { mainTabRequest.request(MainTab.Reports); navController.popBackStack() }
                    }
                },
            )
        }
        composable(Routes.MoveOutRooms) {
            MoveOutRoomsScreen(
                onBack = { navController.popBackStack() },
                onOpenRoom = { roomId ->
                    navController.navigate(Routes.roomProof(roomId.toString(), ProofPhase.MoveOut))
                },
                onCaptureMoveIn = {
                    mainTabRequest.request(MainTab.Rooms)
                    navController.popBackStack()
                },
                onOpenReports = {
                    mainTabRequest.request(MainTab.Reports)
                    navController.popBackStack()
                },
            )
        }
        composable(
            route = Routes.RoomProof,
            arguments = listOf(proofPhaseNavArg, roomIdNavArg),
        ) { entry ->
            val roomId = entry.arguments?.getString(Routes.RoomProofArg)?.let { UUID.fromString(it) }
            val phase = ProofPhase.fromKey(entry.arguments?.getString(Routes.ProofPhaseArg))
            if (roomId != null) {
                RoomProofScreen(
                    roomId = roomId,
                    onBack = { navController.popBackStack() },
                    onOpenCamera = {
                        navController.navigate(Routes.cameraCapture(roomId.toString(), phase))
                    },
                    onProofSaved = { savedRoomId ->
                        navController.navigate(Routes.savedProofReceipt(savedRoomId.toString(), phase)) {
                            popUpTo(Routes.roomProof(savedRoomId.toString(), phase)) { inclusive = true }
                        }
                    },
                )
            }
        }
        composable(
            route = Routes.CameraCapture,
            arguments = listOf(proofPhaseNavArg, roomIdNavArg),
        ) { entry ->
            val roomId = entry.arguments?.getString(Routes.RoomProofArg)?.let { UUID.fromString(it) }
            if (roomId != null) {
                CameraCaptureScreen(
                    onClose = { navController.popBackStack() },
                    onDone = { navController.popBackStack() },
                )
            }
        }
        composable(
            route = Routes.SavedProofReceipt,
            arguments = listOf(proofPhaseNavArg, roomIdNavArg),
        ) { entry ->
            val roomId = entry.arguments?.getString(Routes.RoomProofArg)?.let { UUID.fromString(it) }
            val phase = ProofPhase.fromKey(entry.arguments?.getString(Routes.ProofPhaseArg))
            if (roomId != null) {
                // First run (either moment): the first proof is saved, so leaving the receipt finishes first run and
                // the router opens the app on the asked-for tab. Main and Move-out rooms aren't on the stack yet.
                val inFirstRun = { welcomeVm.firstRun.value != FirstRunStatus.Complete }
                val finishFirstRun = { tab: MainTab ->
                    mainTabRequest.request(tab)
                    welcomeVm.markFirstRunComplete()
                }
                SavedProofReceiptScreen(
                    roomId = roomId,
                    onContinueNextRoom = { nextRoomId ->
                        if (nextRoomId != null) {
                            navController.navigate(Routes.roomProof(nextRoomId.toString(), phase)) {
                                popUpTo(Routes.SavedProofReceipt) { inclusive = true }
                            }
                        } else if (inFirstRun()) {
                            finishFirstRun(MainTab.Reports)
                        } else if (phase == ProofPhase.MoveOut) {
                            navController.popBackStack(Routes.MoveOutRooms, false)
                        } else {
                            if (phase == ProofPhase.MoveIn) welcomeVm.markFirstRunComplete()
                            mainTabRequest.request(MainTab.Reports)
                            navController.popBackStack(Routes.Main, false)
                        }
                    },
                    onViewVault = {
                        if (phase == ProofPhase.MoveIn || inFirstRun()) welcomeVm.markFirstRunComplete()
                        mainTabRequest.request(MainTab.Vault)
                        navController.popBackStack(Routes.Main, false)
                    },
                    onAddMorePhotos = { id ->
                        navController.navigate(Routes.roomProof(id.toString(), phase)) {
                            popUpTo(Routes.SavedProofReceipt) { inclusive = true }
                        }
                    },
                    onBackSafe = {
                        if (inFirstRun()) {
                            finishFirstRun(MainTab.Vault)
                        } else if (phase == ProofPhase.MoveOut) {
                            navController.popBackStack(Routes.MoveOutRooms, false)
                        } else {
                            navController.popBackStack(Routes.Main, false)
                        }
                    },
                )
            }
        }
    }
}
