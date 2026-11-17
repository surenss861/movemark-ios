package com.surensureshkumar.movemark.features.maintenance

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.FindInPage
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMEyebrowStyle
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMPanel
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRow
import com.surensureshkumar.movemark.core.design.MMRowAccessory
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.MMSectionTitle
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.core.util.rememberSignedImageRequest
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.features.proof.RoomPhotoViewer
import com.surensureshkumar.movemark.features.proof.rememberSignedUrl
import java.util.UUID

/*
 * Maintenance case file (iOS `MaintenanceIssueDetailView` in `MMCaseScreen`): the dark case header (MAINTENANCE
 * CASE, status, title, category, REPORTED), then the lead evidence photo + strip (tap → viewer), the case
 * timeline from the record, details, the follow-up composer and Mark resolved.
 */

@Composable
fun MaintenanceIssueDetailScreen(
    issueId: UUID,
    onBack: () -> Unit,
    viewModel: MaintenanceIssueDetailViewModel = hiltViewModel(),
) {
    val issue by viewModel.issue.collectAsState()
    val hasLoadedIssue by viewModel.hasLoadedIssue.collectAsState()
    val issueLookupFailed by viewModel.issueLookupFailed.collectAsState()
    val isSavingFollowUp by viewModel.isSavingFollowUp.collectAsState()
    val isResolving by viewModel.isResolving.collectAsState()
    val message by viewModel.message.collectAsState()
    val softNotice by viewModel.softNotice.collectAsState()
    val retryAvailable by viewModel.retryAvailable.collectAsState()
    val photos by viewModel.photos.collectAsState()
    val hasLoadedPhotos by viewModel.hasLoadedPhotos.collectAsState()
    val photosLoadFailed by viewModel.photosLoadFailed.collectAsState()
    val isUploadingPhotos by viewModel.isUploadingPhotos.collectAsState()

    var followUpNote by rememberSaveable(issueId) { mutableStateOf("") }
    var viewerStart by remember { mutableStateOf<EvidencePhoto?>(null) }
    var confirmResolve by remember { mutableStateOf(false) }

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(MAINTENANCE_PHOTO_PICK_LIMIT),
    ) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        viewModel.attachPhotos(uris)
    }

    val case = issue
    if (case == null) {
        MMScreen(
            title = when {
                !hasLoadedIssue -> "Opening case"
                issueLookupFailed -> "Couldn’t open this case"
                else -> "Case not found"
            },
            eyebrow = "Maintenance case",
            onBack = onBack,
        ) {
            if (hasLoadedIssue && issueLookupFailed) {
                // iOS MaintenanceIssueDetailContainerView: a failed lookup offers Try again.
                com.surensureshkumar.movemark.core.design.MMEmptyBlock(
                    icon = Icons.Outlined.FindInPage,
                    title = "The case file didn’t load",
                    message = "Couldn’t load this issue. Try again.",
                    actionTitle = "Try again",
                    onAction = viewModel::retryLoadIssue,
                )
            } else if (hasLoadedIssue) {
                com.surensureshkumar.movemark.core.design.MMEmptyBlock(
                    icon = Icons.Outlined.FindInPage,
                    title = "This case isn't available",
                    message = "It may have been removed, or it belongs to another rental.",
                )
            } else {
                com.surensureshkumar.movemark.core.design.MMLoadingBlock(message = "Loading the case file…")
            }
        }
        return
    }

    val status = case.caseStatus
    val ordered = remember(photos) { orderMaintenancePhotos(photos) }
    val reported = case.reportedText()
    val errorText = message
    val noticeText = softNotice

    MMScreen(
        title = case.title,
        eyebrow = "Maintenance case",
        lines = listOf(case.categoryLabel),
        onBack = onBack,
        modifier = Modifier.imePadding(),
        trailing = { MaintenanceStatusMark(status, onDark = true) },
        headerAccessory = if (reported != null) {
            { MaintenanceReportedLabel(reported) }
        } else {
            null
        },
    ) {
        if (errorText != null) {
            MMNotice(
                message = errorText,
                actionTitle = if (retryAvailable) "Try again" else null,
                onAction = if (retryAvailable) viewModel::retry else null,
            )
            Spacer(Modifier.height(18.dp))
        } else if (noticeText != null) {
            MMNotice(message = noticeText, tone = MMNoticeTone.Info)
            Spacer(Modifier.height(18.dp))
        }

        MaintenanceEvidenceSection(
            photos = ordered,
            isLoading = !hasLoadedPhotos,
            loadFailed = photosLoadFailed,
            isUploading = isUploadingPhotos,
            signPhotoUrl = viewModel::signedPhotoUrl,
            onOpen = { viewerStart = it.asEvidencePhoto },
            onAddPhotos = { photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        )

        Spacer(Modifier.height(30.dp))
        MaintenanceTimelineSection(MaintenanceCaseTimeline.events(case))

        case.details.trim().takeIf { it.isNotEmpty() }?.let { details ->
            Spacer(Modifier.height(30.dp))
            MaintenanceCaption("Details")
            Spacer(Modifier.height(10.dp))
            Text(details, style = mmFont(15.5f), color = MMInk.Text)
        }

        // A resolved case is closed: no further entries, so its resolution date holds.
        if (!status.isResolved) {
            Spacer(Modifier.height(32.dp))
            MaintenanceFollowUpSection(
                note = followUpNote,
                onNote = { followUpNote = it },
                isSaving = isSavingFollowUp,
                onSave = { viewModel.saveFollowUp(followUpNote, onSaved = { followUpNote = "" }) },
            )
        }

        Spacer(Modifier.height(22.dp))
        MaintenanceResolveSection(
            isResolved = status.isResolved,
            isResolving = isResolving,
            onMarkResolved = { confirmResolve = true },
        )
    }

    if (confirmResolve) {
        AlertDialog(
            onDismissRequest = { confirmResolve = false },
            title = { Text("Mark this case resolved?") },
            confirmButton = {
                TextButton(onClick = { confirmResolve = false; viewModel.markResolved() }) {
                    Text("Mark resolved", color = MMInk.Text, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmResolve = false }) { Text("Cancel", color = MMInk.Secondary) }
            },
        )
    }

    viewerStart?.let { start ->
        RoomPhotoViewer(
            photos = ordered.map { it.asEvidencePhoto },
            start = start,
            signPhotoUrl = viewModel::signedPhotoUrl,
            onDismiss = { viewerStart = null },
        )
    }
}

/** The header's REPORTED label + value (iOS `MMCaseScreen`). */
@Composable
private fun MaintenanceReportedLabel(reported: String) {
    Column(
        Modifier.semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text("REPORTED", style = MMEyebrowStyle, color = MMInk.HeroSecondary)
        Text(reported, style = mmFont(14.5f, FontWeight.Medium), color = Color.White)
    }
}

/** Lead photo (4:3, tap → viewer), "N photos recorded", the strip of the rest, then "Add photos". */
@Composable
internal fun MaintenanceEvidenceSection(
    photos: List<MaintenancePhotoUi>,
    isLoading: Boolean,
    loadFailed: Boolean,
    isUploading: Boolean,
    signPhotoUrl: suspend (String) -> String?,
    onOpen: (MaintenancePhotoUi) -> Unit,
    onAddPhotos: () -> Unit,
) {
    val tileShape = RoundedCornerShape(14.dp)
    Column(Modifier.fillMaxWidth()) {
        val lead = photos.firstOrNull()
        val countText = maintenancePhotosRecordedText(photos.size)
        if (lead != null) {
            // The lead shows the full image; until it signs (or if it can't), the thumbnail stands in.
            val full by rememberSignedUrl(lead.filePath) { signPhotoUrl(lead.filePath) }
            Box(
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(4f / 3f)
                    .clip(tileShape)
                    .background(MMInk.Field)
                    .border(0.75.dp, Color.Black.copy(alpha = 0.06f), tileShape)
                    .mmPressable(onClickLabel = "Open the photo viewer") { onOpen(lead) }
                    .semantics { contentDescription = "Lead evidence photo, $countText" },
            ) {
                val url = full ?: lead.signedUrl
                if (url != null) {
                    AsyncImage(
                        model = rememberSignedImageRequest(url, if (full != null) lead.filePath else lead.displayPath),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
            Text(
                countText,
                style = mmFont(13.5f, FontWeight.Medium),
                color = MMInk.Text,
                modifier = Modifier.padding(top = 10.dp),
            )
            if (photos.size > 1) {
                LazyRow(
                    Modifier.padding(top = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    itemsIndexed(photos.drop(1), key = { _, p -> p.id.toString() }) { offset, photo ->
                        MaintenanceThumbTile(
                            thumb = photo.signedUrl?.let { MaintenanceThumb(it, photo.displayPath) },
                            side = 64.dp,
                            modifier = Modifier
                                .mmPressable(onClickLabel = "Open the photo viewer") { onOpen(photo) }
                                .semantics { contentDescription = "Evidence photo ${offset + 2} of ${photos.size}" },
                        )
                    }
                }
            }
        } else if (isLoading) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(4f / 3f)
                    .clip(tileShape)
                    .background(MMInk.Field)
                    .semantics { contentDescription = "Loading evidence" },
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
            }
        } else {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .clip(tileShape)
                    .background(MMInk.Field),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (loadFailed) "Photos couldn't load" else "No photos recorded for this case",
                    style = mmFont(13.5f),
                    color = MMInk.Secondary,
                )
            }
        }

        MMGroup(Modifier.padding(top = 14.dp)) {
            MMRow(
                title = when {
                    isUploading -> "Uploading…"
                    photos.isEmpty() -> "Add photos"
                    else -> "Add more photos"
                },
                icon = Icons.Outlined.CameraAlt,
                accessory = MMRowAccessory.None,
                enabled = !isUploading,
                trailing = if (isUploading) {
                    { CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(16.dp)) }
                } else {
                    null
                },
                onClick = onAddPhotos,
            )
        }
    }
}

@Composable
internal fun MaintenanceTimelineSection(events: List<MaintenanceCaseEvent>) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        MaintenanceCaption("Case timeline")
        MMPanel(padding = PaddingValues(18.dp)) {
            events.forEachIndexed { index, event ->
                MaintenanceTimelineRow(event, isFirst = index == 0, isLast = index == events.lastIndex)
            }
        }
    }
}

@Composable
internal fun MaintenanceFollowUpSection(
    note: String,
    onNote: (String) -> Unit,
    isSaving: Boolean,
    onSave: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        MMSectionTitle(title = "Add to the record")
        Text(
            "What your landlord said, what you sent, or what happened next. It joins the timeline, dated.",
            style = mmFont(14f),
            color = MMInk.Secondary,
            modifier = Modifier.padding(top = 4.dp),
        )
        MaintenanceField(
            title = "Landlord response / follow-up note",
            placeholder = "What happened next",
            value = note,
            onValueChange = onNote,
            multiline = true,
            enabled = !isSaving,
            modifier = Modifier.padding(top = 16.dp),
        )
        Spacer(Modifier.height(18.dp))
        MMPrimaryButton(
            title = "Save follow-up",
            onClick = onSave,
            isLoading = isSaving,
            enabled = !isSaving && note.isNotBlank(),
        )
    }
}

@Composable
internal fun MaintenanceResolveSection(isResolved: Boolean, isResolving: Boolean, onMarkResolved: () -> Unit) {
    if (isResolved) {
        Text(
            "This case is resolved and stays in your record.",
            style = mmFont(13.5f),
            color = MMInk.Secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    } else {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            MMSecondaryButton(
                title = if (isResolving) "Marking resolved…" else "Mark resolved",
                onClick = onMarkResolved,
                icon = Icons.Filled.Check,
                enabled = !isResolving,
            )
            Text(
                "Once it's fixed. The case and its photos stay preserved.",
                style = mmFont(12.5f),
                color = MMInk.Secondary,
                textAlign = TextAlign.Center,
            )
        }
    }
}
