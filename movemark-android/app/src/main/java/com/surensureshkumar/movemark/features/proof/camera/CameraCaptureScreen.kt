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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executor
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
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
    val errorMessage by viewModel.errorMessage.collectAsState()
    var showExitDialog by remember { mutableStateOf(false) }

    val imageCapture = remember {
        ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .build()
    }
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }
    var cameraBound by remember { mutableStateOf(false) }

    LaunchedEffect(lifecycleOwner) {
        val provider = ProcessCameraProvider.getInstance(context).awaitProvider(context)
        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }
        provider.unbindAll()
        provider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            imageCapture,
        )
        cameraBound = true
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
                }) { Text("Keep photos", color = MMColors.Primary) }
            },
            dismissButton = {
                TextButton(onClick = {
                    showExitDialog = false
                    viewModel.discardPending()
                    onClose()
                }) { Text("Discard", color = MMColors.TextSecondary) }
            },
        )
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        AndroidView(
            factory = { previewView },
            modifier = Modifier.fillMaxSize(),
        )

        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = { tryClose() }) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White)
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        "$roomName proof",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 17.sp,
                    )
                    Text(
                        if (capturedCount == 1) "1 photo captured" else "$capturedCount photos captured",
                        color = Color.White.copy(alpha = 0.75f),
                        fontSize = 13.sp,
                    )
                }
                IconButton(
                    onClick = {
                        galleryPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                ) {
                    Icon(Icons.Filled.PhotoLibrary, contentDescription = "Gallery", tint = Color.White)
                }
            }

            Spacer(Modifier.weight(1f))

            errorMessage?.let { msg ->
                Text(
                    msg,
                    color = MMColors.SemanticDanger,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 8.dp),
                    fontSize = 14.sp,
                )
            }

            if (capturedUris.isNotEmpty()) {
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(capturedUris, key = { it.toString() }) { uri ->
                        AsyncImage(
                            model = uri,
                            contentDescription = null,
                            modifier = Modifier
                                .size(56.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .border(1.dp, Color.White.copy(0.3f), RoundedCornerShape(8.dp)),
                        )
                    }
                }
            }

            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Spacer(Modifier.size(72.dp))
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(if (isCapturing) Color.White.copy(0.35f) else Color.White)
                        .clickable(enabled = !isCapturing) {
                            viewModel.capture(imageCapture)
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier
                            .size(62.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(0.15f)),
                    )
                }
                if (capturedCount > 0) {
                    TextButton(
                        onClick = {
                            viewModel.finishAndDeliver { delivered -> if (delivered) onDone() }
                        },
                        enabled = !isCapturing,
                    ) {
                        Text("Done", color = MMColors.Primary, fontWeight = FontWeight.Bold)
                    }
                } else {
                    Spacer(Modifier.size(48.dp))
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
