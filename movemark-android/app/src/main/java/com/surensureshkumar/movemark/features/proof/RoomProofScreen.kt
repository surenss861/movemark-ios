package com.surensureshkumar.movemark.features.proof

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import java.util.UUID

@Composable
fun RoomProofScreen(
    roomId: UUID,
    onBack: () -> Unit,
    onProofSaved: (UUID) -> Unit,
    onOpenCamera: () -> Unit,
    viewModel: RoomProofViewModel = hiltViewModel(),
) {
    val proofPhase = viewModel.proofPhase
    val room by viewModel.room.collectAsState()
    val photos by viewModel.photos.collectAsState()
    val photoCount by viewModel.photoCount.collectAsState()
    val saveState by viewModel.saveState.collectAsState()
    val saveButtonLabel by viewModel.saveButtonLabel.collectAsState()
    val message by viewModel.message.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val reduceMotion = MMMotion.rememberReduceMotion()
    var cameraDenied by remember { mutableStateOf(false) }
    var showLeaveUploadDialog by remember { mutableStateOf(false) }

    val isBusy = saveState.isBusy
    val isPartial = saveState is RoomProofSaveState.PartialSuccess
    val isFailed = saveState is RoomProofSaveState.Failed
    val uploadingProgress = saveState as? RoomProofSaveState.Uploading

    val statusLine = when {
        message != null -> message
        uploadingProgress != null -> null
        photoCount > 0 -> "$photoCount photo${if (photoCount == 1) "" else "s"} ready to save"
        else -> null
    }

    LaunchedEffect(Unit) {
        viewModel.proofSaved.collect { payload -> onProofSaved(payload.roomId) }
    }

    DisposableEffect(lifecycleOwner, roomId) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.consumeCameraCaptures()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(12),
    ) { uris ->
        if (uris.isNotEmpty()) viewModel.addUris(uris)
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        cameraDenied = !granted
        if (granted) onOpenCamera()
    }

    fun launchCamera() {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        when {
            granted -> {
                cameraDenied = false
                onOpenCamera()
            }
            else -> cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun handleBack() {
        if (viewModel.isUploadInProgress()) {
            showLeaveUploadDialog = true
        } else {
            onBack()
        }
    }

    BackHandler { handleBack() }

    if (showLeaveUploadDialog) {
        AlertDialog(
            onDismissRequest = { showLeaveUploadDialog = false },
            title = { Text("Leave this screen?") },
            text = { Text("Upload is still running. Leave this screen?") },
            confirmButton = {
                TextButton(onClick = {
                    showLeaveUploadDialog = false
                    onBack()
                }) { Text("Leave", color = MMColors.SemanticDanger) }
            },
            dismissButton = {
                TextButton(onClick = { showLeaveUploadDialog = false }) {
                    Text("Stay", color = MMColors.Primary)
                }
            },
        )
    }

    MMBackground {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            bottomBar = {
                RoomProofBottomSaveBar(
                    saveButtonLabel = saveButtonLabel,
                    statusLine = statusLine,
                    photoCount = photoCount,
                    isBusy = isBusy,
                    isPartial = isPartial,
                    isFailed = isFailed,
                    onSave = viewModel::save,
                    onContinueWithSaved = viewModel::continueWithSavedProof,
                    onRetry = viewModel::retryFailedUploads,
                )
            },
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                    .padding(top = 16.dp, bottom = MMSpacing.TabScrollBottom.dp),
            ) {
                TextButton(onClick = { handleBack() }) {
                    Text("Back", color = MMColors.TextSecondary)
                }
                Spacer(Modifier.height(8.dp))

                RoomProofCaptureHero(
                    roomName = room?.name ?: "Room",
                    proofPhase = proofPhase,
                )
                Spacer(Modifier.height(20.dp))

                RoomProofMediaModule(
                    photos = photos,
                    isBusy = isBusy,
                    reduceMotion = reduceMotion,
                    onTakePhotos = ::launchCamera,
                    onChooseGallery = {
                        picker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                )

                if (cameraDenied) {
                    Spacer(Modifier.height(16.dp))
                    MMProofCard {
                        Text(
                            "Camera access is needed to take proof photos.",
                            color = MMColors.TextSecondary,
                        )
                        Spacer(Modifier.height(12.dp))
                        MMButton(text = "Open Settings", onClick = ::openAppSettings)
                        Spacer(Modifier.height(8.dp))
                        MMButton(
                            text = "Choose from gallery",
                            onClick = {
                                picker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                )
                            },
                            style = MMButtonStyle.Secondary,
                        )
                    }
                }
            }
        }
    }
}
