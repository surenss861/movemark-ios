package com.surensureshkumar.movemark.features.maintenance

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.FindInPage
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMEmptyBlock
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import java.util.UUID

/*
 * Maintenance log (iOS `MaintenanceLogView`): the rental's case archive. Open cases first, then resolved, each read
 * as a case — evidence thumbnail when it has one, title, category, reported date, photo count, calm status.
 * Recording a new issue happens in its own sheet, opened from the header's "+" or the empty state.
 */

@Composable
fun MaintenanceLogScreen(
    onBack: () -> Unit,
    onOpenIssue: (UUID) -> Unit,
    viewModel: MaintenanceLogViewModel = hiltViewModel(),
) {
    val log by viewModel.maintenanceLog.collectAsState()
    val property by viewModel.currentProperty.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isSubmitting by viewModel.isSubmitting.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val notice by viewModel.notice.collectAsState()
    val sheetError by viewModel.sheetError.collectAsState()
    val savedCount by viewModel.savedCount.collectAsState()
    val covers by viewModel.covers.collectAsState()

    // Re-sync when the active rental changes (iOS `.task(id: currentProperty?.id)`).
    LaunchedEffect(property?.id) { viewModel.refresh() }

    MaintenanceLogContent(
        log = log,
        isLoading = isLoading,
        isSubmitting = isSubmitting,
        errorMessage = errorMessage,
        onBack = onBack,
        onOpenIssue = onOpenIssue,
        rentalTitle = maintenanceRentalTitle(property),
        notice = notice,
        sheetError = sheetError,
        savedCount = savedCount,
        covers = covers,
        onRetry = viewModel::refresh,
        onSaveIssue = viewModel::saveIssue,
        onSheetClosed = viewModel::clearSheetError,
    )
}

/** iOS `PropertyVaultModel.displayTitle`: the rental's name, else its street address. */
internal fun maintenanceRentalTitle(property: PropertyRecord?): String? =
    property?.title?.trim()?.ifEmpty { null } ?: property?.addressLine1?.trim()?.ifEmpty { null }

/** The log itself, from plain values (also rendered by the debug fixture gallery with populated cases). */
@Composable
internal fun MaintenanceLogContent(
    log: List<MaintenanceRecord>,
    isLoading: Boolean,
    isSubmitting: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onOpenIssue: (UUID) -> Unit,
    onAddIncident: (title: String, category: String, details: String) -> Unit = { _, _, _ -> },
    rentalTitle: String? = null,
    notice: String? = null,
    sheetError: String? = null,
    savedCount: Int = 0,
    covers: Map<UUID, MaintenanceThumb> = emptyMap(),
    onRetry: () -> Unit = {},
    onSaveIssue: (MaintenanceIssueDraft) -> Unit = { onAddIncident(it.title, it.category, it.details) },
    onSheetClosed: () -> Unit = {},
) {
    var isRecording by rememberSaveable { mutableStateOf(false) }
    var seenSavedCount by rememberSaveable { mutableIntStateOf(savedCount) }
    LaunchedEffect(savedCount) {
        if (savedCount != seenSavedCount) {
            seenSavedCount = savedCount
            isRecording = false
        }
    }

    // Record header grammar: MAINTENANCE · the rental · what this log holds.
    MMScreen(
        title = rentalTitle ?: "Maintenance",
        eyebrow = "Maintenance",
        lines = listOf("Issues recorded for this rental."),
        onBack = onBack,
        showsWordmark = true,
        trailing = { MaintenanceRecordButton(onClick = { isRecording = true }) },
    ) {
        MaintenanceCaseList(
            log = log,
            isLoading = isLoading,
            errorMessage = errorMessage,
            notice = notice,
            covers = covers,
            onOpenIssue = onOpenIssue,
            onRecord = { isRecording = true },
            onRetry = onRetry,
        )
    }

    if (isRecording) {
        MaintenanceNewIssueSheet(
            isSubmitting = isSubmitting,
            errorMessage = sheetError,
            onSave = onSaveIssue,
            onDismiss = {
                isRecording = false
                onSheetClosed()
            },
        )
    }
}

/** The header's "+" (iOS: a 32pt white-12% circle in a 44pt target). */
@Composable
private fun MaintenanceRecordButton(onClick: () -> Unit) {
    Box(
        Modifier
            .size(48.dp)
            .mmPressable(onClickLabel = "Record an issue", onClick = onClick)
            .semantics { contentDescription = "Record an issue" }
            .testTag("maintenance.record"),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
    }
}

/** The sheet's content: notices, then loading / failed / empty / the OPEN and RESOLVED groups. */
@Composable
internal fun MaintenanceCaseList(
    log: List<MaintenanceRecord>,
    isLoading: Boolean,
    errorMessage: String?,
    notice: String?,
    covers: Map<UUID, MaintenanceThumb>,
    onOpenIssue: (UUID) -> Unit,
    onRecord: () -> Unit,
    onRetry: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        if (errorMessage != null && log.isNotEmpty()) {
            // A refresh failure is calm: the recorded cases are still here.
            MMNotice(message = errorMessage, tone = MMNoticeTone.Info, actionTitle = "Try again", onAction = onRetry)
            Spacer(Modifier.height(18.dp))
        } else if (errorMessage == null && notice != null) {
            MMNotice(message = notice, tone = MMNoticeTone.Info)
            Spacer(Modifier.height(18.dp))
        }

        when {
            log.isEmpty() && isLoading -> Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 80.dp)
                    .semantics(mergeDescendants = true) {},
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                Text("Loading cases…", style = mmFont(14f), color = MMInk.Secondary)
            }
            // Nothing loaded to fall back on: say so rather than claim the log is empty.
            log.isEmpty() && errorMessage != null -> MMEmptyBlock(
                icon = Icons.Outlined.FindInPage,
                title = "Cases didn't load",
                message = "Couldn't load the maintenance log just now. Check your connection and try again.",
                actionTitle = "Try again",
                onAction = onRetry,
            )
            log.isEmpty() -> MMEmptyBlock(
                icon = Icons.Outlined.FindInPage,
                title = "No cases recorded",
                message = "When something happens, record it with photos and a date.",
                actionTitle = "Record an issue",
                onAction = onRecord,
            )
            else -> {
                val open = log.filter { !MaintenanceCaseStatus.fromStored(it.status).isResolved }
                val resolved = log.filter { MaintenanceCaseStatus.fromStored(it.status).isResolved }
                Column(verticalArrangement = Arrangement.spacedBy(26.dp)) {
                    MaintenanceCaseSection("Open", open, covers, onOpenIssue)
                    MaintenanceCaseSection("Resolved", resolved, covers, onOpenIssue)
                }
                if (isLoading) {
                    Box(Modifier.fillMaxWidth().padding(top = 14.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun MaintenanceCaseSection(
    title: String,
    rows: List<MaintenanceRecord>,
    covers: Map<UUID, MaintenanceThumb>,
    onOpenIssue: (UUID) -> Unit,
) {
    if (rows.isEmpty()) return
    MMGroup(title = "$title · ${rows.size}") {
        rows.forEachIndexed { index, entry ->
            if (index > 0) MMRowDivider(leading = 14.dp)
            MaintenanceCaseRow(
                title = entry.title,
                line = maintenanceCaseLine(entry),
                photoCount = entry.photoCount,
                status = MaintenanceCaseStatus.fromStored(entry.status),
                thumb = covers[entry.id],
                onClick = { onOpenIssue(entry.id) },
            )
        }
    }
}

/** iOS: "<category> · Reported <date>" (the day only). */
internal fun maintenanceCaseLine(entry: MaintenanceRecord): String {
    val category = MaintenanceCategory.label(entry.category)
    val reported = MaintenanceCaseDate.text(entry.createdAt, time = false) ?: return category
    return "$category · Reported $reported"
}
