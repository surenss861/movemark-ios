package com.surensureshkumar.movemark.features.maintenance

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRow
import com.surensureshkumar.movemark.core.design.MMRowAccessory
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.mmFont

/** What "Save issue" hands the log: [category] is the iOS raw value stored on the server. */
data class MaintenanceIssueDraft(
    val title: String,
    val category: String,
    val details: String,
    val photos: List<Uri> = emptyList(),
)

/** Photos per pick, the same as the case file's "Add photos" (iOS allows 10). */
internal const val MAINTENANCE_PHOTO_PICK_LIMIT = 10 // iOS PhotosPicker maxSelectionCount

/**
 * Record an issue (iOS `MaintenanceNewIssueSheet`): the focused surface opened from the log's "+" and its empty
 * state. Title, category, details, photos, one lime Save. Closing with something entered asks "Discard changes?".
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MaintenanceNewIssueSheet(
    isSubmitting: Boolean,
    errorMessage: String?,
    onSave: (MaintenanceIssueDraft) -> Unit,
    onDismiss: () -> Unit,
) {
    var title by rememberSaveable { mutableStateOf("") }
    var categoryName by rememberSaveable { mutableStateOf(MaintenanceCategory.Default.name) }
    var details by rememberSaveable { mutableStateOf("") }
    var photos by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var confirmDiscard by remember { mutableStateOf(false) }
    val category = MaintenanceCategory.entries.firstOrNull { it.name == categoryName } ?: MaintenanceCategory.Default

    val hasChanges = title.isNotBlank() || details.isNotBlank() || category != MaintenanceCategory.Default || photos.isNotEmpty()
    val guardChanges by rememberUpdatedState(hasChanges || isSubmitting)
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { value ->
            if (value == SheetValue.Hidden && guardChanges) {
                confirmDiscard = true
                false
            } else {
                true
            }
        },
    )

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(MAINTENANCE_PHOTO_PICK_LIMIT)) { uris ->
        if (uris.isNotEmpty()) photos = uris
    }

    ModalBottomSheet(
        onDismissRequest = { if (!guardChanges) onDismiss() else confirmDiscard = true },
        sheetState = sheetState,
        containerColor = MMInk.Sheet,
        contentColor = MMInk.Text,
    ) {
        MaintenanceNewIssueForm(
            title = title,
            onTitle = { title = it },
            category = category,
            onCategory = { categoryName = it.name },
            details = details,
            onDetails = { details = it },
            photos = photos,
            onAttachPhotos = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
            isSubmitting = isSubmitting,
            errorMessage = errorMessage,
            onCancel = { if (hasChanges && !isSubmitting) confirmDiscard = true else if (!isSubmitting) onDismiss() },
            onSave = { onSave(MaintenanceIssueDraft(title.trim(), category.raw, details.trim(), photos)) },
            modifier = Modifier.navigationBarsPadding().imePadding(),
        )
    }

    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text("Discard changes?") },
            confirmButton = {
                TextButton(onClick = { confirmDiscard = false; onDismiss() }, enabled = !isSubmitting) {
                    Text("Discard", color = MMInk.Danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDiscard = false }) { Text("Keep editing", color = MMInk.Text) }
            },
        )
    }
}

/** The sheet's body from plain values (rendered directly by the tests). */
@Composable
internal fun MaintenanceNewIssueForm(
    title: String,
    onTitle: (String) -> Unit,
    category: MaintenanceCategory,
    onCategory: (MaintenanceCategory) -> Unit,
    details: String,
    onDetails: (String) -> Unit,
    photos: List<Uri>,
    onAttachPhotos: () -> Unit,
    isSubmitting: Boolean,
    errorMessage: String?,
    onCancel: () -> Unit,
    onSave: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMMetrics.Inset)
            .padding(bottom = 24.dp),
    ) {
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                "Record an issue",
                style = mmFont(20f, FontWeight.SemiBold),
                color = MMInk.Text,
                modifier = Modifier.weight(1f).semantics { heading() },
            )
            TextButton(onClick = onCancel, enabled = !isSubmitting) {
                Text("Cancel", color = MMInk.Text, style = mmFont(15.5f))
            }
        }
        Spacer(Modifier.height(12.dp))

        errorMessage?.let {
            MMNotice(message = it, modifier = Modifier.testTag("maintenance.new.error"))
            Spacer(Modifier.height(16.dp))
        }

        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            MaintenanceField(
                title = "Issue title",
                placeholder = "Water leak under sink",
                value = title,
                onValueChange = onTitle,
                enabled = !isSubmitting,
            )
            MaintenanceCategoryChips(selected = category, onSelect = onCategory, enabled = !isSubmitting)
            MaintenanceField(
                title = "Details",
                placeholder = "What happened, where, and what was reported",
                value = details,
                onValueChange = onDetails,
                multiline = true,
                enabled = !isSubmitting,
            )
        }

        Spacer(Modifier.height(18.dp))
        MMGroup {
            MMRow(
                title = when {
                    photos.isEmpty() -> "Attach photos"
                    photos.size == 1 -> "1 photo selected"
                    else -> "${photos.size} photos selected"
                },
                icon = Icons.Outlined.CameraAlt,
                accessory = MMRowAccessory.None,
                enabled = !isSubmitting,
                onClick = onAttachPhotos,
            )
            if (photos.isNotEmpty()) {
                MMRowDivider()
                LazyRow(
                    Modifier.padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(photos, key = { it.toString() }) { uri ->
                        AsyncImage(
                            model = uri,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(64.dp)
                                .clip(RoundedCornerShape(10.dp)),
                        )
                    }
                }
            }
        }

        Text(
            "MoveMark dates the case and keeps its photos with the record.",
            style = mmFont(12.5f),
            color = MMInk.Secondary,
            modifier = Modifier.padding(top = 10.dp, start = 4.dp, end = 4.dp),
        )

        Spacer(Modifier.height(22.dp))
        MMPrimaryButton(
            title = "Save issue",
            onClick = onSave,
            isLoading = isSubmitting,
            // iOS: Save stays available; an empty title answers "Enter an issue title."
            enabled = !isSubmitting,
        )
    }
}

