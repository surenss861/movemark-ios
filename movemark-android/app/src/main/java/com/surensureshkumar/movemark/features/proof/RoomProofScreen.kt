package com.surensureshkumar.movemark.features.proof

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import java.util.UUID

@Composable
fun RoomProofScreen(
    roomId: UUID,
    onBack: () -> Unit,
    onProofSaved: (UUID) -> Unit,
    onOpenCamera: () -> Unit,
    viewModel: RoomProofViewModel = hiltViewModel(),
) {
    val room by viewModel.room.collectAsState()
    val photoCount by viewModel.photoCount.collectAsState()
    val uploading by viewModel.uploading.collectAsState()
    val message by viewModel.message.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var cameraDenied by remember { mutableStateOf(false) }

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

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
        ) {
            TextButton(onClick = onBack) { Text("Back", color = MMColors.TextSecondary) }
            Text(
                text = room?.name ?: "Room",
                style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
            )
            Spacer(Modifier.height(8.dp))
            val documented = room?.let { RoomProofMetrics.isDocumented(it) } == true
            Text(
                text = when {
                    photoCount > 0 -> "$photoCount photos selected"
                    documented -> "Room has saved proof on file"
                    else -> "No photos yet"
                },
                color = MMColors.TextSecondary,
            )
            message?.let {
                Spacer(Modifier.height(8.dp))
                val partial = it.contains(" of ") && it.contains("uploaded")
                val isSuccess = it.startsWith("Proof saved") || partial
                Text(it, color = if (isSuccess) MMColors.Primary else MMColors.SemanticDanger)
            }

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

            Spacer(Modifier.height(24.dp))
            MMButton(
                text = "Take photos",
                onClick = ::launchCamera,
                enabled = !uploading,
            )
            Spacer(Modifier.height(12.dp))
            MMButton(
                text = "Choose from gallery",
                onClick = {
                    picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
                style = MMButtonStyle.Secondary,
                enabled = !uploading,
            )
            Spacer(Modifier.height(12.dp))
            MMButton(
                text = if (uploading) "Saving…" else "Save proof",
                onClick = viewModel::save,
                loading = uploading,
                enabled = photoCount > 0 && !uploading,
            )
        }
    }
}
