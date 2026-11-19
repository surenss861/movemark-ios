package com.surensureshkumar.movemark.features.proof.camera

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.graphics.Color
import android.content.Context
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LocalLifecycleOwner
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.features.proof.RoomCapturePrompts
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executor
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine

@Composable
fun CameraCaptureScreen(
    onClose: () -> Unit,
    onDone: () -> Unit,
    viewModel: CameraCaptureViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val roomName by viewModel.roomName.collectAsState()
    val capturedUris by viewModel.capturedUris.collectAsState()
    val capturedCount by viewModel.capturedCount.collectAsState()
    val isCapturing by viewModel.isCapturing.collectAsState()
    val notice by viewModel.notice.collectAsState()
    val cameraUnavailable by viewModel.isCameraUnavailable.collectAsState()
    var showExitDialog by remember { mutableStateOf(false) }

    val imageCapture = remember {
        ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .build()
    }
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FIT_CENTER } }
    var cameraBound by remember { mutableStateOf(false) }

    LaunchedEffect(lifecycleOwner) {
        val provider = ProcessCameraProvider.getInstance(context).awaitProvider(context)
        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }
        provider.unbindAll()
        // A camera HAL CameraX can't configure (seen: Android 17's new dynamic range profile with CameraX 1.4)
        // must not take the app down: say so and keep the photo library.
        try {
            provider.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_BACK_CAMERA,
                preview,
                imageCapture,
            )
            cameraBound = true
        } catch (e: Exception) {
            if (e is kotlinx.coroutines.CancellationException) throw e
            android.util.Log.e("CameraCapture", "camera bind failed", e)
            runCatching { provider.unbindAll() }
            viewModel.cameraUnavailable()
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            if (cameraBound) {
                runCatching {
                    ProcessCameraProvider.getInstance(context).get().unbindAll()
                }
            }
        }
    }

    val galleryPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(12),
    ) { uris -> viewModel.addGalleryUris(uris) }

    fun tryClose() {
        if (viewModel.hasCaptures()) showExitDialog = true else onClose()
    }

    BackHandler { tryClose() }

    if (showExitDialog) {
        AlertDialog(
            onDismissRequest = { showExitDialog = false },
            title = { Text("Keep these photos?") },
            text = { Text("You captured $capturedCount photo${if (capturedCount == 1) "" else "s"}. Keep them for this room proof?") },
            confirmButton = {
                TextButton(onClick = {
                    showExitDialog = false
                    viewModel.finishAndDeliver { delivered -> if (delivered) onDone() else onClose() }
                }) { Text("Keep photos", color = MMInk.Text, fontWeight = FontWeight.SemiBold) }
            },
            dismissButton = {
                TextButton(onClick = {
                    showExitDialog = false
                    viewModel.discardPending()
                    onClose()
                }) { Text("Discard", color = MMInk.Secondary) }
            },
        )
    }

    // iOS EvidenceCameraViewController: header band (room, count, next suggestion), the whole frame between it and
    // the shutter (resizeAspect), then Cancel or the latest-photo thumbnail · shutter · Done.
    // One light system (2026-11-18): the header and footer bands are the light page; only the feed between them is dark.
    MMLightSystemBars(lightNavigationBar = true, lightStatusBar = true)
    val latest = CameraCaptureUi.latestThumbnail(capturedUris)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MMInk.Sheet)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 8.dp, top = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    roomName,
                    color = MMInk.Text,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    when (capturedCount) {
                        0 -> "No photos yet"
                        1 -> "1 photo captured"
                        else -> "$capturedCount photos captured"
                    },
                    color = MMInk.Secondary,
                    fontSize = 13.sp,
                    modifier = Modifier.testTag("camera.count"),
                )
            }
            IconButton(
                modifier = Modifier.size(48.dp),
                onClick = {
                    galleryPicker.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                    )
                },
            ) {
                Icon(Icons.Filled.PhotoLibrary, contentDescription = "Gallery", tint = MMInk.Text)
            }
        }

        // The room's suggested shots (same list iOS passes: RoomCapturePrompts), indexed by the photos taken here.
        Text(
            CameraCaptureUi.suggestion(capturedCount, RoomCapturePrompts),
            color = MMInk.Text,
            fontSize = 15.sp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, top = 10.dp)
                .testTag("camera.suggestion"),
        )

        Box(
            Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(top = 12.dp, bottom = 16.dp)
                // The camera feed itself: dark behind the letterboxed frame, between the two light bands.
                .background(Color.Black),
        ) {
            AndroidView(
                factory = { previewView },
                modifier = Modifier.fillMaxSize(),
            )

            if (cameraUnavailable) {
                Text(
                    CameraCaptureUi.CAMERA_UNAVAILABLE,
                    color = Color.White,
                    fontSize = 17.sp,
                    modifier = Modifier.align(Alignment.Center).testTag("camera.unavailable"),
                )
            }

            // "Photo added" (or the failure) for a moment over the bottom of the preview; TalkBack hears it too.
            val noticeAlpha = remember { Animatable(0f) }
            var noticeText by remember { mutableStateOf("") }
            // Survives rotation so a notice already shown doesn't flash again when the screen is recreated.
            var shownSerial by rememberSaveable { mutableStateOf(0L) }
            LaunchedEffect(notice?.serial) {
                val current = notice ?: return@LaunchedEffect
                if (current.serial == shownSerial) return@LaunchedEffect
                shownSerial = current.serial
                noticeText = current.message
                noticeAlpha.snapTo(1f)
                delay(CameraCaptureUi.NOTICE_HOLD_MILLIS)
                noticeAlpha.animateTo(0f, tween(CameraCaptureUi.NOTICE_FADE_MILLIS))
            }
            if (noticeText.isNotEmpty() && noticeAlpha.value > 0f) {
                Text(
                    noticeText,
                    color = Color.White,
                    fontSize = 15.sp,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 16.dp)
                        .alpha(noticeAlpha.value)
                        .background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(16.dp))
                        .padding(horizontal = 14.dp, vertical = 7.dp)
                        .semantics { liveRegion = LiveRegionMode.Polite }
                        .testTag("camera.notice"),
                )
            }
        }

        Box(
            Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (CameraCaptureUi.showsCancel(capturedUris.size) || latest == null) {
                // Cancel is the same way out as Back: with photos it asks "Keep these photos?".
                TextButton(
                    onClick = { tryClose() },
                    modifier = Modifier.align(Alignment.CenterStart).heightIn(min = 48.dp).testTag("camera.cancel"),
                ) {
                    Text("Cancel", color = MMInk.Text, fontSize = 17.sp)
                }
            } else {
                // The latest photo; like iOS it goes back to the room, where review, removal and retakes happen.
                AsyncImage(
                    model = latest,
                    contentDescription = "Review photos",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .size(52.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(10.dp))
                        .clickable(enabled = !isCapturing, role = Role.Button) {
                            viewModel.finishAndDeliver { delivered -> if (delivered) onDone() }
                        }
                        .testTag("camera.thumbnail"),
                )
            }

            val shutterEnabled = !isCapturing && !cameraUnavailable
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(MMInk.Card)
                    .border(3.dp, if (shutterEnabled) MMInk.Text else MMInk.Text.copy(alpha = 0.35f), CircleShape)
                    .clickable(enabled = shutterEnabled, role = Role.Button, onClickLabel = "Take Photo") {
                        viewModel.capture(imageCapture)
                    }
                    .semantics { contentDescription = "Take Photo" }
                    .testTag("camera.shutter"),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier
                        .size(58.dp)
                        .clip(CircleShape)
                        .background(if (shutterEnabled) MMInk.Text else MMInk.Text.copy(alpha = 0.35f)),
                )
            }

            if (capturedCount > 0) {
                // iOS: a filled lime capsule with ink text, not a text action.
                Box(
                    Modifier
                        .align(Alignment.CenterEnd)
                        .heightIn(min = 48.dp)
                        .clip(CircleShape)
                        .background(if (isCapturing) MMInk.Lime.copy(alpha = 0.5f) else MMInk.Lime)
                        .clickable(enabled = !isCapturing, role = Role.Button) {
                            viewModel.finishAndDeliver { delivered -> if (delivered) onDone() }
                        }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                        .testTag("camera.done"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("Done", color = MMInk.OnLime, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
            }
        }
    }
}

private suspend fun ListenableFuture<ProcessCameraProvider>.awaitProvider(
    context: Context,
): ProcessCameraProvider = suspendCancellableCoroutine { cont ->
    addListener(
        {
            try {
                cont.resume(get())
            } catch (e: Exception) {
                cont.resumeWithException(e)
            }
        },
        ContextCompat.getMainExecutor(context),
    )
}
