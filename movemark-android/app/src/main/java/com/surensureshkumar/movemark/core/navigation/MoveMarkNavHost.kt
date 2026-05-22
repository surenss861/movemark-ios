package com.surensureshkumar.movemark.core.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.surensureshkumar.movemark.core.di.MoveMarkEntryPoints
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.features.auth.AuthMode
import com.surensureshkumar.movemark.features.auth.AuthScreen
import com.surensureshkumar.movemark.features.firstrun.CreatePropertyScreen
import com.surensureshkumar.movemark.features.main.MainShellScreen
import com.surensureshkumar.movemark.features.proof.RoomProofScreen
import com.surensureshkumar.movemark.features.proof.SavedProofReceiptScreen
import com.surensureshkumar.movemark.features.proof.camera.CameraCaptureScreen
import com.surensureshkumar.movemark.features.welcome.WelcomeScreen
import com.surensureshkumar.movemark.features.welcome.WelcomeViewModel
import dagger.hilt.android.EntryPointAccessors
import java.util.UUID

@Composable
fun MoveMarkNavHost() {
    val context = LocalContext.current
    val mainTabRequest = remember(context) {
        EntryPointAccessors.fromApplication(
            context.applicationContext,
            MoveMarkEntryPoints::class.java,
        ).mainTabRequest()
    }
    val navController = rememberNavController()
    val welcomeVm: WelcomeViewModel = hiltViewModel()
    val authState by welcomeVm.authState.collectAsState()
    val hasProperty by welcomeVm.hasProperty.collectAsState()

    LaunchedEffect(authState, hasProperty) {
        when (authState) {
            AuthState.Loading -> Unit
            AuthState.SignedOut -> {
                if (navController.currentDestination?.route != Routes.Welcome) {
                    navController.navigate(Routes.Welcome) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            }
            AuthState.SignedIn -> {
                val dest = when {
                    hasProperty == false -> Routes.CreateProperty
                    hasProperty == true -> Routes.Main
                    else -> return@LaunchedEffect
                }
                if (navController.currentDestination?.route != dest) {
                    navController.navigate(dest) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            }
        }
    }

    NavHost(navController = navController, startDestination = Routes.Welcome) {
        composable(Routes.Welcome) {
            WelcomeScreen(
                onStartMoveIn = {
                    navController.navigate(Routes.auth("signUp"))
                },
                onContinue = {
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
                initialMode = if (mode == "signUp") AuthMode.SignUp else AuthMode.SignIn,
                onDismiss = { navController.popBackStack() },
            )
        }
        composable(Routes.CreateProperty) {
            CreatePropertyScreen(
                onCreated = {
                    navController.navigate(Routes.Main) {
                        popUpTo(0) { inclusive = true }
                    }
                },
            )
        }
        composable(Routes.Main) {
            MainShellScreen(
                onOpenRoom = { roomId ->
                    navController.navigate(Routes.roomProof(roomId.toString()))
                },
                onSignOut = {
                    navController.navigate(Routes.Welcome) {
                        popUpTo(0) { inclusive = true }
                    }
                },
            )
        }
        composable(
            route = Routes.RoomProof,
            arguments = listOf(navArgument(Routes.RoomProofArg) { type = NavType.StringType }),
        ) { entry ->
            val roomId = entry.arguments?.getString(Routes.RoomProofArg)?.let { UUID.fromString(it) }
            if (roomId != null) {
                RoomProofScreen(
                    roomId = roomId,
                    onBack = { navController.popBackStack() },
                    onOpenCamera = {
                        navController.navigate(Routes.cameraCapture(roomId.toString()))
                    },
                    onProofSaved = { savedRoomId ->
                        navController.navigate(Routes.savedProofReceipt(savedRoomId.toString())) {
                            popUpTo(Routes.roomProof(savedRoomId.toString())) { inclusive = true }
                        }
                    },
                )
            }
        }
        composable(
            route = Routes.CameraCapture,
            arguments = listOf(navArgument(Routes.RoomProofArg) { type = NavType.StringType }),
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
            arguments = listOf(navArgument(Routes.SavedProofReceiptArg) { type = NavType.StringType }),
        ) { entry ->
            val roomId = entry.arguments?.getString(Routes.SavedProofReceiptArg)?.let { UUID.fromString(it) }
            if (roomId != null) {
                SavedProofReceiptScreen(
                    roomId = roomId,
                    onContinueNextRoom = { nextRoomId ->
                        if (nextRoomId != null) {
                            navController.navigate(Routes.roomProof(nextRoomId.toString())) {
                                popUpTo(Routes.SavedProofReceipt) { inclusive = true }
                            }
                        } else {
                            mainTabRequest.request(MainTab.Reports)
                            navController.popBackStack(Routes.Main, false)
                        }
                    },
                    onViewVault = {
                        mainTabRequest.request(MainTab.Vault)
                        navController.popBackStack(Routes.Main, false)
                    },
                    onAddMorePhotos = { id ->
                        navController.navigate(Routes.roomProof(id.toString())) {
                            popUpTo(Routes.SavedProofReceipt) { inclusive = true }
                        }
                    },
                    onBackSafe = {
                        navController.popBackStack(Routes.Main, false)
                    },
                )
            }
        }
    }
}
