package com.surensureshkumar.movemark.features.moveout

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.property.MoveOutChecklistRow
import com.surensureshkumar.movemark.domain.MoveOutComparison
import com.surensureshkumar.movemark.domain.MoveOutOverview
import com.surensureshkumar.movemark.features.paywall.ProPaywallScreen
import com.surensureshkumar.movemark.features.proof.RoomPhotoViewer
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Move-out (iOS `MoveOutFoundationView`): every room's move-in record beside its move-out record, the change
 * stated first, the closeout checklist, and the move-out report.
 */
@Composable
fun MoveOutRoomsScreen(
    onBack: () -> Unit,
    onOpenRoom: (UUID) -> Unit,
    onCaptureMoveIn: () -> Unit = onBack,
    onOpenReports: () -> Unit = onBack,
    viewModel: MoveOutRoomsViewModel = hiltViewModel(),
) {
    val overview by viewModel.overview.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val justCompared by viewModel.justCompared.collectAsState()
    val checklist by viewModel.checklist.collectAsState()
    val loadingChecklist by viewModel.loadingChecklist.collectAsState()
    val error by viewModel.error.collectAsState()
    val errorFromExport by viewModel.errorFromExport.collectAsState()
    val queuedNotice by viewModel.queuedNotice.collectAsState()
    val exporting by viewModel.exporting.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    var paywall by remember { mutableStateOf<PaywallReason?>(null) }
    var viewer by remember { mutableStateOf<Pair<List<EvidencePhoto>, EvidencePhoto>?>(null) }

    LaunchedEffect(Unit) { viewModel.paywall.collect { paywall = it } }

    fun openViewer(item: MoveOutComparison, side: MoveOutSide) {
        val photos = if (side == MoveOutSide.MoveIn) item.moveInPhotos else item.moveOutPhotos
        photos.firstOrNull()?.let { viewer = photos to it }
    }

    Box(Modifier.fillMaxSize()) {
        MMBackground {
            Column(
                Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                    .padding(top = 4.dp, bottom = 48.dp),
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = MMColors.TextPrimary)
                }
                Text("MOVE-OUT", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp, color = MMColors.TextSecondary)
                Text(
                    viewModel.rentalName,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = MMColors.TextPrimary,
                    modifier = Modifier.padding(top = 4.dp).semantics { heading() },
                )
                Text("Compare what changed since move-in.", fontSize = 15.sp, color = MMColors.TextSecondary, modifier = Modifier.padding(top = 4.dp))

                val o = overview
                when {
                    o == null && loading -> CircularProgressIndicator(color = MMColors.Primary, modifier = Modifier.padding(top = 24.dp))
                    o == null -> Text("No rental loaded.", color = MMColors.TextSecondary, modifier = Modifier.padding(top = 24.dp))
                    else -> MoveOutContent(
                        o = o,
                        justCompared = justCompared,
                        checklist = checklist,
                        loadingChecklist = loadingChecklist,
                        error = error,
                        errorFromExport = errorFromExport,
                        queuedNotice = queuedNotice,
                        exporting = exporting,
                        hasPro = hasPro,
                        sign = viewModel::signedPhotoUrl,
                        onRetryChecklist = viewModel::loadChecklist,
                        onToggle = viewModel::toggle,
                        onGenerate = viewModel::generateReport,
                        onRetryExport = viewModel::queueReport,
                        onOpenRoom = onOpenRoom,
                        onCaptureMoveIn = onCaptureMoveIn,
                        onOpenReports = onOpenReports,
                        onOpenPhoto = ::openViewer,
                    )
                }
            }
        }
        viewer?.let { (photos, start) ->
            RoomPhotoViewer(photos = photos, start = start, signPhotoUrl = viewModel::signedPhotoUrl, onDismiss = { viewer = null })
        }
        paywall?.let { reason -> ProPaywallScreen(reason = reason, onClose = { paywall = null }) }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ColumnScope.MoveOutContent(
    o: MoveOutOverview,
    justCompared: Set<UUID>,
    checklist: MoveOutChecklistRow?,
    loadingChecklist: Boolean,
    error: String?,
    errorFromExport: Boolean,
    queuedNotice: String?,
    exporting: Boolean,
    hasPro: Boolean,
    sign: SignPhoto,
    onRetryChecklist: () -> Unit,
    onToggle: (MoveOutChecklistRow.Item) -> Unit,
    onGenerate: () -> Unit,
    onRetryExport: () -> Unit,
    onOpenRoom: (UUID) -> Unit,
    onCaptureMoveIn: () -> Unit,
    onOpenReports: () -> Unit,
    onOpenPhoto: (MoveOutComparison, MoveOutSide) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val jumpTargets = remember { List(3) { BringIntoViewRequester() } }

    if (o.rooms.isNotEmpty() && o.hasBaseline) {
        Spacer(Modifier.height(18.dp))
        MoveOutHeaderProgress(done = o.roomsWithMoveOutPhotos, total = o.rooms.size)
    }
    Spacer(Modifier.height(22.dp))

    o.justComparedLine(justCompared)?.let { MoveOutNotice(it, success = true); Spacer(Modifier.height(18.dp)) }
    if (error != null && !errorFromExport) {
        MoveOutNotice(error, actionTitle = "Try again", onAction = onRetryChecklist)
        Spacer(Modifier.height(18.dp))
    }

    if (o.hasBaseline) {
        Column(verticalArrangement = Arrangement.spacedBy(26.dp)) {
            Panel {
                MoveOutTally(o.changed.size, o.missing.size, o.unchanged.size) { index ->
                    scope.launch { jumpTargets[index].bringIntoView() }
                }
                if (o.isSubstantiallyCompared) {
                    HorizontalDivider(Modifier.padding(vertical = 14.dp), thickness = 0.75.dp, color = MMColors.CardStroke)
                    Text(
                        if (o.missing.isEmpty()) "Your move-out record now shows how the rental changed since move-in."
                        else "Your move-out record now shows how most of the rental changed since move-in.",
                        fontSize = 14.sp,
                        color = MMColors.TextPrimary,
                    )
                }
            }
            if (o.changed.isNotEmpty()) {
                Section("What changed", o.changed.size, "Compare move-in and move-out proof room by room.", Modifier.bringIntoViewRequester(jumpTargets[0])) {
                    o.changed.forEach { item ->
                        MoveOutSpreadCard(item, sign, item.id in justCompared) { onOpenPhoto(item, it) }
                    }
                }
            }
            if (o.missing.isNotEmpty()) {
                Section("Move-out proof needed", o.missing.size, "Capture from the same angles as move-in.", Modifier.bringIntoViewRequester(jumpTargets[1])) {
                    val next = o.missing.first()
                    MoveOutMissingCard(next, sign, isPrimary = true, onOpen = { onOpenPhoto(next, it) }, onCapture = { onOpenRoom(next.id) })
                    if (o.missing.size > 1) {
                        Group {
                            o.missing.drop(1).forEachIndexed { index, item ->
                                if (index > 0) RowDivider()
                                MoveOutMissingRow(item) { onOpenRoom(item.id) }
                            }
                        }
                    }
                }
            }
            if (o.unchanged.isNotEmpty()) {
                TitledGroup(
                    "Unchanged · ${o.unchanged.size}",
                    "Photographed at both ends with no new issue and no lower condition. Tap a room to compare its photos.",
                    Modifier.bringIntoViewRequester(jumpTargets[2]),
                ) {
                    o.unchanged.forEachIndexed { index, item ->
                        if (index > 0) RowDivider()
                        MoveOutCompactRow(item, sign, item.id in justCompared) { onOpenPhoto(item, it) }
                    }
                }
            }
            if (o.notCompared.isNotEmpty()) {
                TitledGroup(
                    "Not compared · ${o.notCompared.size}",
                    "These rooms have move-out photos but no move-in photos, so there is nothing to compare them with.",
                ) {
                    o.notCompared.forEachIndexed { index, item ->
                        if (index > 0) RowDivider()
                        MoveOutCompactRow(item, sign, justCompared = false) { onOpenPhoto(item, it) }
                    }
                }
            }
        }
    } else {
        Panel {
            Text("No move-in proof to compare yet", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary)
            Text(
                if (o.rooms.isEmpty()) "Add your rooms and photograph each one as it is now. Before you leave, you’ll capture them again here and see what changed — and what didn’t."
                else "Photograph each room as it is now. Before you leave, you’ll capture them again here and see what changed — and what didn’t.",
                fontSize = 14.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(top = 6.dp),
            )
            MMButton(text = "Capture move-in proof", onClick = onCaptureMoveIn, modifier = Modifier.padding(top = 16.dp))
        }
    }

    Spacer(Modifier.height(30.dp))
    ChecklistSection(checklist, loadingChecklist, onToggle)

    if (o.hasBaseline) {
        Spacer(Modifier.height(30.dp))
        Text("Move-out report", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary, modifier = Modifier.semantics { heading() })
        Text("One organized, dated PDF of each room’s move-out proof.", fontSize = 14.sp, color = MMColors.TextSecondary, modifier = Modifier.padding(top = 4.dp))
        if (errorFromExport && error != null) {
            Spacer(Modifier.height(16.dp))
            MoveOutNotice(error, actionTitle = "Try again", onAction = onRetryExport)
        }
        when {
            queuedNotice != null -> {
                Spacer(Modifier.height(16.dp))
                MoveOutNotice(queuedNotice, success = true)
                MMButton(
                    text = "Open Reports",
                    onClick = onOpenReports,
                    style = if (o.isComplete) MMButtonStyle.Primary else MMButtonStyle.Secondary,
                    modifier = Modifier.padding(top = 14.dp),
                )
            }
            o.isComplete -> MMButton(
                text = if (exporting) "Queuing report…" else "Generate move-out report",
                onClick = onGenerate,
                loading = exporting,
                enabled = !exporting,
                modifier = Modifier.padding(top = 18.dp),
            )
            else -> Text(o.remainingRoomsLine, fontSize = 14.5.sp, fontWeight = FontWeight.Medium, color = MMColors.TextPrimary, modifier = Modifier.padding(top = 12.dp))
        }
        if (queuedNotice == null && o.isComplete) {
            Text(
                if (hasPro) "Included with Pro" else "Pro required for move-out reports",
                fontSize = 12.5.sp,
                color = MMColors.TextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
            )
        }
    }
}

@Composable
private fun ChecklistSection(checklist: MoveOutChecklistRow?, loading: Boolean, onToggle: (MoveOutChecklistRow.Item) -> Unit) {
    when {
        checklist != null -> TitledGroup("Closeout checklist · ${checklist.completedCount} of 6", "Check off as you go. Saved to this rental.") {
            MoveOutChecklistRow.Item.entries.forEachIndexed { index, item ->
                if (index > 0) RowDivider()
                ChecklistItemRow(item.title, checklist.isDone(item)) { onToggle(item) }
            }
        }
        loading -> TitledGroup("Closeout checklist", null) {
            Row(Modifier.heightIn(min = 52.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(16.dp), color = MMColors.TextSecondary, strokeWidth = 2.dp)
                Spacer(Modifier.width(10.dp))
                Text("Loading checklist…", fontSize = 15.sp, color = MMColors.TextSecondary)
            }
        }
    }
}

/** A quiet check row: filled check when done, thin ring when not. Tap toggles and saves. */
@Composable
internal fun ChecklistItemRow(title: String, done: Boolean, onToggle: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clickable(role = Role.Checkbox, onClick = onToggle)
            .semantics(mergeDescendants = true) {
                toggleableState = if (done) ToggleableState.On else ToggleableState.Off
                stateDescription = if (done) "Done" else "Not done"
            }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(22.dp)
                .then(if (done) Modifier.background(MMColors.Primary, CircleShape) else Modifier.border(1.25.dp, MMColors.TextSecondary.copy(alpha = 0.5f), CircleShape)),
            contentAlignment = Alignment.Center,
        ) {
            if (done) Icon(Icons.Filled.Check, contentDescription = null, tint = MMColors.AppBackground, modifier = Modifier.size(13.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text(title, fontSize = 16.sp, color = MMColors.TextPrimary)
    }
}

@Composable
internal fun MoveOutNotice(message: String, success: Boolean = false, actionTitle: String? = null, onAction: (() -> Unit)? = null) {
    val tint = if (success) MMColors.Primary else MMColors.SemanticWarning
    Column(
        Modifier
            .fillMaxWidth()
            .background(tint.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .border(0.75.dp, tint.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(message, fontSize = 14.sp, color = MMColors.TextPrimary)
        if (actionTitle != null && onAction != null) {
            TextButton(onClick = onAction, modifier = Modifier.heightIn(min = 48.dp)) {
                Text(actionTitle, color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun Panel(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MMColors.EvidenceCard, RoundedCornerShape(18.dp))
            .border(0.75.dp, MMColors.CardStroke, RoundedCornerShape(18.dp))
            .padding(14.dp),
        content = content,
    )
}

@Composable
private fun Section(title: String, count: Int, caption: String, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary, modifier = Modifier.weight(1f).semantics { heading() })
            Text("$count ${if (count == 1) "room" else "rooms"}", fontSize = 13.sp, color = MMColors.TextSecondary)
        }
        Text(caption, fontSize = 13.sp, color = MMColors.TextSecondary, modifier = Modifier.padding(top = 3.dp))
        Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

@Composable
private fun Group(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MMColors.EvidenceCard, RoundedCornerShape(18.dp))
            .border(1.dp, MMColors.CardStroke, RoundedCornerShape(18.dp)),
        content = content,
    )
}

@Composable
private fun TitledGroup(title: String, footer: String?, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier) {
        Text(
            title.uppercase(),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.6.sp,
            color = MMColors.TextSecondary,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp).semantics { heading() },
        )
        Group(content)
        footer?.let { Text(it, fontSize = 12.5.sp, color = MMColors.TextSecondary, modifier = Modifier.padding(start = 4.dp, top = 8.dp)) }
    }
}

@Composable
private fun RowDivider() = HorizontalDivider(Modifier.padding(start = 16.dp), thickness = 0.5.dp, color = MMColors.CardStroke)
