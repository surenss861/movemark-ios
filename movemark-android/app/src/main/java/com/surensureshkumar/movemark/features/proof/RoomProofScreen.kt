package com.surensureshkumar.movemark.features.proof

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import coil.compose.SubcomposeAsyncImage
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import java.util.UUID
import kotlinx.coroutines.launch

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

    val draft by viewModel.draft.collectAsState()
    val entryBusy by viewModel.entryBusy.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    var editingEntry by remember { mutableStateOf<EvidenceRecord?>(null) }
    var deletingEntry by remember { mutableStateOf<EvidenceRecord?>(null) }
    var appendTarget by remember { mutableStateOf<UUID?>(null) }
    var viewerPhoto by remember { mutableStateOf<EvidencePhoto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.entryNotice.collect { snackbar.showSnackbar(it) }
    }

    val appendPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(12),
    ) { uris ->
        val target = appendTarget
        appendTarget = null
        if (target != null && uris.isNotEmpty()) viewModel.appendPhotos(target, uris)
    }

    val entries = room?.let { if (proofPhase == ProofPhase.MoveOut) it.moveOutEvidence else it.moveInEvidence }.orEmpty()
    val hasPending = photos.isNotEmpty()
    val showsSaveBar = hasPending || isBusy || isPartial || isFailed
    val compareLine = room?.let { r ->
        val moveIn = r.moveInEvidence.sumOf { it.photoCount }
        val moveOut = r.moveOutEvidence.sumOf { it.photoCount }
        if (moveIn > 0 && moveOut > 0) "MOVE-IN $moveIn · MOVE-OUT $moveOut PHOTOS" else null
    }
    val scroll = rememberScrollState()
    val density = LocalDensity.current
    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp
    // The title settles into the bar once the hero (or the empty-state heading) has scrolled away.
    val scrolledAwayPx = with(density) {
        (if (entries.isEmpty()) 140.dp else roomHeroHeight(screenWidth, screenHeight) - 90.dp).toPx()
    }
    fun chooseGallery() = picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    MMBackground {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            contentWindowInsets = WindowInsets(0),
            snackbarHost = { SnackbarHost(snackbar) },
            bottomBar = {
                AnimatedVisibility(
                    visible = showsSaveBar,
                    enter = slideInVertically { it } + fadeIn(),
                    exit = slideOutVertically { it } + fadeOut(),
                ) {
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
                        modifier = Modifier.navigationBarsPadding(),
                    )
                }
            },
        ) { padding ->
          Box(Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = padding.calculateBottomPadding())
                    .verticalScroll(scroll)
                    .padding(bottom = 48.dp),
            ) {
                RoomEvidenceHero(
                    roomName = room?.name ?: "Room",
                    entries = entries,
                    proofPhase = proofPhase,
                    signPhotoUrl = viewModel::signedPhotoUrl,
                    scrollOffset = { scroll.value },
                    onOpenPhoto = { viewerPhoto = it },
                    hasPendingPhotos = hasPending,
                    isBusy = isBusy || entryBusy,
                    onTakePhotos = ::launchCamera,
                    onChooseGallery = ::chooseGallery,
                    compareLine = compareLine,
                )

                Column(Modifier.padding(horizontal = MMSpacing.ScreenHorizontal.dp)) {
                    if (cameraDenied) {
                        Spacer(Modifier.height(16.dp))
                        Text("Camera access is needed to take proof photos.", color = MMColors.TextSecondary)
                        Spacer(Modifier.height(10.dp))
                        MMButton(text = "Open Settings", onClick = ::openAppSettings, style = MMButtonStyle.Secondary)
                    }

                    if (entries.isNotEmpty()) {
                        RoomEvidenceBody(
                            entries = entries,
                            proofPhase = proofPhase,
                            isBusy = isBusy || entryBusy,
                            onEdit = { editingEntry = it },
                            onAddPhotos = { entry ->
                                appendTarget = entry.id
                                appendPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                            },
                            onDelete = { deletingEntry = it },
                            modifier = Modifier.padding(top = 10.dp),
                        )
                    }

                    AnimatedVisibility(visible = hasPending, enter = fadeIn(), exit = fadeOut()) {
                        Column(Modifier.padding(vertical = 18.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            if (entries.isNotEmpty()) HorizontalDivider(thickness = 0.5.dp, color = MMColors.CardStroke)
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Kicker(if (proofPhase == ProofPhase.MoveOut) "NEW MOVE-OUT ENTRY" else "NEW ENTRY", MMColors.TextMuted)
                                Spacer(Modifier.weight(1f))
                                Text(
                                    if (photos.size == 1) "1 photo" else "${photos.size} photos",
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 12.sp,
                                    color = MMColors.TextMuted,
                                )
                            }
                            RoomProofPhotoGrid(photos = photos, reduceMotion = reduceMotion)
                            EntryDetailsForm(
                                draft = draft,
                                onChange = { next -> viewModel.updateDraft { next } },
                                enabled = !isBusy,
                            )
                        }
                    }
                }
            }
            RoomTopBar(
                roomName = room?.name ?: "Room",
                phase = proofPhase,
                onBack = ::handleBack,
                scrolledAway = scroll.value > scrolledAwayPx,
            )
          }
        }
    }

    editingEntry?.let { entry ->
        EditEntrySheet(
            entry = entry,
            isSaving = entryBusy,
            onSave = { edit -> viewModel.updateEntry(entry.id, edit) { ok -> if (ok) editingEntry = null } },
            onDismiss = { if (!entryBusy) editingEntry = null },
        )
    }

    deletingEntry?.let { entry ->
        AlertDialog(
            onDismissRequest = { deletingEntry = null },
            title = { Text("Delete proof?") },
            text = { Text("Photos and notes for this entry will be removed. This can't be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    deletingEntry = null
                    viewModel.deleteEntry(entry.id)
                }) { Text("Delete", color = MMColors.SemanticDanger) }
            },
            dismissButton = {
                TextButton(onClick = { deletingEntry = null }) { Text("Cancel", color = MMColors.TextSecondary) }
            },
        )
    }

    viewerPhoto?.let { photo ->
        RoomPhotoViewer(
            photos = orderedRoomPhotos(entries).map { it.first },
            start = photo,
            signPhotoUrl = viewModel::signedPhotoUrl,
            onDismiss = { viewerPhoto = null },
        )
    }
}

/** Edit a saved entry's details — same fields as iOS `EditEvidenceSheet`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditEntrySheet(
    entry: EvidenceRecord,
    isSaving: Boolean,
    onSave: (EntryDraft) -> Unit,
    onDismiss: () -> Unit,
) {
    var edit by remember(entry.id) {
        mutableStateOf(
            EntryDraft(
                title = entry.title,
                notes = entry.notes,
                conditionRating = entry.conditionRating ?: 4,
                tags = entry.issueTags.toSet(),
            ),
        )
    }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MMColors.AppBackgroundRaised,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("Edit proof", color = MMColors.TextPrimary, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            EntryDetailsForm(draft = edit, onChange = { edit = it }, enabled = !isSaving)
            MMButton(text = if (isSaving) "Saving…" else "Save changes", onClick = { onSave(edit) }, loading = isSaving, enabled = !isSaving)
        }
    }
}

/** Every photo in the phase, paged, "2 of 4", filmstrip — the counterpart of iOS `RoomPhotoViewer`. */
@Composable
fun RoomPhotoViewer(
    photos: List<EvidencePhoto>,
    start: EvidencePhoto,
    signPhotoUrl: suspend (String) -> String?,
    onDismiss: () -> Unit,
) {
    val pager = rememberPagerState(initialPage = photos.indexOfFirst { it.id == start.id }.coerceAtLeast(0)) { photos.size }
    val scope = rememberCoroutineScope()
    // A dialog window reports zero insets, so read the bars from the activity before opening it
    // (the filmstrip sat under the gesture bar).
    val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Box(Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Color.Black)) {
            HorizontalPager(state = pager, modifier = Modifier.fillMaxSize()) { page ->
                val photo = photos[page]
                val url by produceState<String?>(initialValue = null, photo.filePath) { value = signPhotoUrl(photo.filePath) }
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    if (url == null) {
                        CircularProgressIndicator(color = androidx.compose.ui.graphics.Color.White)
                    } else {
                        SubcomposeAsyncImage(
                            model = url,
                            contentDescription = "Evidence photo ${page + 1} of ${photos.size}",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.fillMaxSize(),
                            loading = { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = androidx.compose.ui.graphics.Color.White) } },
                            error = { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Couldn't load this photo", color = androidx.compose.ui.graphics.Color.White) } },
                        )
                    }
                }
            }
            Row(
                Modifier.fillMaxWidth().padding(top = topInset).padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = androidx.compose.ui.graphics.Color.White)
                }
                Text(
                    "${pager.currentPage + 1} of ${photos.size}",
                    color = androidx.compose.ui.graphics.Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.size(48.dp))
            }
            if (photos.size > 1) {
                LazyRow(
                    Modifier.align(Alignment.BottomCenter).padding(bottom = bottomInset + 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                ) {
                    itemsIndexed(photos, key = { _, p -> p.id }) { index, p ->
                        val path = p.thumbnailPath ?: p.filePath
                        val thumb by produceState<String?>(initialValue = null, path) { value = signPhotoUrl(path) ?: signPhotoUrl(p.filePath) }
                        val selected = index == pager.currentPage
                        Box(
                            Modifier
                                .size(52.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.08f))
                                .border(2.dp, if (selected) androidx.compose.ui.graphics.Color.White else androidx.compose.ui.graphics.Color.Transparent, RoundedCornerShape(10.dp))
                                .alpha(if (selected) 1f else 0.6f)
                                .clickable { scope.launch { pager.animateScrollToPage(index) } },
                        ) {
                            if (thumb != null) {
                                SubcomposeAsyncImage(model = thumb, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                            }
                        }
                    }
                }
            }
        }
    }
}
