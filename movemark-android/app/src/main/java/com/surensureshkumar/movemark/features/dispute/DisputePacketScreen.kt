package com.surensureshkumar.movemark.features.dispute

import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.offset
import androidx.compose.material.icons.automirrored.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.Share
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.Dp
import com.surensureshkumar.movemark.core.design.MMEmptyBlock
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMRowChevron
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMSectionTitle
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import com.surensureshkumar.movemark.features.documents.recordIcon
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.domain.DisputePacketModel
import com.surensureshkumar.movemark.domain.DisputePacketModel.Packet
import com.surensureshkumar.movemark.domain.MoveOutComparison
import com.surensureshkumar.movemark.features.moveout.MoveOutCompactRow
import com.surensureshkumar.movemark.features.moveout.MoveOutMissingCard
import com.surensureshkumar.movemark.features.moveout.MoveOutSide
import com.surensureshkumar.movemark.features.moveout.MoveOutSpreadCard
import com.surensureshkumar.movemark.features.paywall.ProPaywallScreen
import com.surensureshkumar.movemark.features.proof.RoomPhotoViewer
import com.surensureshkumar.movemark.features.reports.ReportLocalPdf
import com.surensureshkumar.movemark.features.reports.ReportPdfAction
import com.surensureshkumar.movemark.features.reports.components.ReportPdfViewer
import com.surensureshkumar.movemark.features.reports.components.shareReportPdf
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import java.util.UUID

/** The evidence packet builder (iOS `DisputePacketView` / `DisputePacketContent`). */
@Composable
fun DisputePacketScreen(
    onBack: () -> Unit,
    onCaptureMoveOut: (UUID) -> Unit,
    onMissing: (DisputePacketModel.Missing.Target) -> Unit,
    viewModel: DisputePacketViewModel = hiltViewModel(),
) {
    val model by viewModel.model.collectAsState()
    val question by viewModel.question.collectAsState()
    val amount by viewModel.amount.collectAsState()
    val error by viewModel.error.collectAsState()
    val timedOut by viewModel.pollTimedOut.collectAsState()
    val downloading by viewModel.downloading.collectAsState()
    val context = LocalContext.current
    var paywall by remember { mutableStateOf(false) }
    var viewing by remember { mutableStateOf<ReportLocalPdf?>(null) }
    var viewer by remember { mutableStateOf<Pair<List<EvidencePhoto>, EvidencePhoto>?>(null) }

    LaunchedEffect(Unit) { viewModel.paywall.collect { paywall = true } }
    LaunchedEffect(Unit) {
        viewModel.pdf.collect { pdf ->
            if (pdf.action == ReportPdfAction.View) viewing = pdf else shareReportPdf(context, pdf.file, pdf.displayTitle)
        }
    }

    Box(Modifier.fillMaxSize()) {
        val m = model
        if (m == null) {
            // iOS: the same header with "No rental yet", and an empty block on the sheet.
            MMScreen(title = "No rental yet", eyebrow = "Dispute packet", onBack = onBack) {
                MMEmptyBlock(
                    icon = Icons.Outlined.Description,
                    title = "No rental yet",
                    message = "A packet is assembled from a rental's recorded evidence.",
                )
            }
        } else {
            val generating = m.packet == Packet.Generating
            DisputePacketContent(
                model = m,
                question = question,
                amount = amount,
                errorMessage = error ?: if (timedOut && generating) "Taking longer than usual." else null,
                errorActionTitle = if (error == null && timedOut && generating) "Check again" else "Try again",
                isDownloading = downloading,
                sign = viewModel::signedPhotoUrl,
                onQuestion = viewModel::setQuestion,
                onAmount = viewModel::setAmount,
                onToggleRoom = viewModel::toggleRoom,
                onOpenPhoto = { item, side ->
                    val photos = if (side == MoveOutSide.MoveIn) item.moveInPhotos else item.moveOutPhotos
                    photos.firstOrNull()?.let { viewer = photos to it }
                },
                onCaptureMoveOut = onCaptureMoveOut,
                onMissing = onMissing,
                onGenerate = viewModel::generate,
                onView = { viewModel.open(share = false) },
                onShare = { viewModel.open(share = true) },
                onRetry = viewModel::refreshAndPoll,
                onBack = onBack,
                modifier = Modifier.imePadding(),
            )
        }
        viewing?.let { pdf ->
            ReportPdfViewer(pdf.file, pdf.displayTitle, onShare = { shareReportPdf(context, pdf.file, pdf.displayTitle) }, onClose = { viewing = null })
        }
        viewer?.let { (photos, start) ->
            RoomPhotoViewer(photos = photos, start = start, signPhotoUrl = viewModel::signedPhotoUrl, onDismiss = { viewer = null })
        }
        if (paywall) ProPaywallScreen(reason = PaywallReason.DisputePacket, onClose = { paywall = false })
    }
}

/**
 * Presentational (iOS `DisputePacketContent`): the dark header — DISPUTE PACKET, the rental's name, the purpose line
 * and the packet's status — then what is being questioned → evidence to review → missing proof → contents → one
 * action on the sheet.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun DisputePacketContent(
    model: DisputePacketModel,
    question: String,
    amount: String,
    errorMessage: String?,
    errorActionTitle: String,
    isDownloading: Boolean,
    sign: suspend (String) -> String?,
    onQuestion: (String) -> Unit,
    onAmount: (String) -> Unit,
    onToggleRoom: (UUID) -> Unit,
    onOpenPhoto: (MoveOutComparison, MoveOutSide) -> Unit,
    onCaptureMoveOut: (UUID) -> Unit,
    onMissing: (DisputePacketModel.Missing.Target) -> Unit,
    onGenerate: () -> Unit,
    onView: () -> Unit,
    onShare: () -> Unit,
    onRetry: () -> Unit,
    onBack: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    MMScreen(
        title = model.title,
        eyebrow = "Dispute packet",
        lines = listOf(DISPUTE_PURPOSE_LINE),
        onBack = onBack,
        modifier = modifier,
        headerAccessory = { PacketStatus(model.statusLine, model.isReadyState) },
    ) {
        DisputePacketSheet(
            model, question, amount, errorMessage, errorActionTitle, isDownloading, sign, onQuestion, onAmount,
            onToggleRoom, onOpenPhoto, onCaptureMoveOut, onMissing, onGenerate, onView, onShare, onRetry,
        )
    }
}

internal const val DISPUTE_PURPOSE_LINE = "Build a record of the evidence related to this issue."

/** The status on the light header: a lime dot when ready or generated, else a quiet one, and the status line. */
@Composable
private fun PacketStatus(status: String, ready: Boolean) {
    // MMHeader adds 22dp above the accessory; iOS sets the status 18 below the purpose line.
    Row(
        Modifier
            .offset(y = (-4).dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(7.dp).background(if (ready) MMInk.LimeMark else MMInk.HeroSecondary.copy(alpha = 0.5f), CircleShape))
        Spacer(Modifier.width(7.dp))
        Text(status, style = mmFont(12.5f, FontWeight.Medium), color = MMInk.HeroText)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DisputePacketSheet(
    model: DisputePacketModel,
    question: String,
    amount: String,
    errorMessage: String?,
    errorActionTitle: String,
    isDownloading: Boolean,
    sign: suspend (String) -> String?,
    onQuestion: (String) -> Unit,
    onAmount: (String) -> Unit,
    onToggleRoom: (UUID) -> Unit,
    onOpenPhoto: (MoveOutComparison, MoveOutSide) -> Unit,
    onCaptureMoveOut: (UUID) -> Unit,
    onMissing: (DisputePacketModel.Missing.Target) -> Unit,
    onGenerate: () -> Unit,
    onView: () -> Unit,
    onShare: () -> Unit,
    onRetry: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(32.dp)) {
        if (errorMessage != null) {
            MMNotice(message = errorMessage, tone = MMNoticeTone.Info, actionTitle = errorActionTitle, onAction = onRetry)
        }

        Section("What is being questioned") {
            Field("Issue", "e.g. Deduction for the kitchen counter", question, onQuestion, KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Next))
            Field("Amount questioned (optional)", "e.g. $350", amount, onAmount, KeyboardOptions(keyboardType = KeyboardType.Text, autoCorrectEnabled = false, imeAction = ImeAction.Done))
            Caption("Kept on this phone for your reference. It is not added to the generated packet.")
        }

        Section("Evidence to review") {
            if (model.selectableRooms.isEmpty()) {
                Caption("Rooms appear here once they have proof.")
            } else {
                Caption("Select the rooms you want to review while building this packet. The generated packet includes the full rental record.")
                FlowRow(
                    Modifier.semantics { contentDescription = "Rooms to review" },
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    model.selectableRooms.forEach { room ->
                        RoomChip(room.name, room.id in model.selectedRoomIds) { onToggleRoom(room.id) }
                    }
                }
                model.involved.forEach { item ->
                    when (item.state) {
                        MoveOutComparison.State.Changed, MoveOutComparison.State.NewIssue ->
                            MoveOutSpreadCard(item, sign, justCompared = false) { onOpenPhoto(item, it) }
                        MoveOutComparison.State.Missing ->
                            MoveOutMissingCard(item, sign, isPrimary = false, onOpen = { onOpenPhoto(item, it) }, onCapture = { onCaptureMoveOut(item.id) })
                        else -> Box(
                            Modifier
                                .clip(RoundedCornerShape(MMMetrics.CardRadius))
                                .background(MMInk.Card)
                                .border(1.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.CardRadius)),
                        ) { MoveOutCompactRow(item, sign, justCompared = false) { onOpenPhoto(item, it) } }
                    }
                }
            }
        }

        if (model.missing.isNotEmpty()) {
            Section("Missing proof") {
                MMGroup {
                    model.missing.forEachIndexed { index, item ->
                        if (index > 0) MMRowDivider()
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .mmPressable { onMissing(item.target) }
                                .semantics(mergeDescendants = true) {}
                                .heightIn(min = 56.dp)
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(item.title, style = mmFont(16f), color = MMInk.Text)
                                Text(item.detail, style = mmFont(13f), color = MMInk.Secondary)
                            }
                            MMRowChevron()
                        }
                    }
                }
            }
        }

        Section(if (model.isGenerated) "A new packet would include" else "Generated packet includes", spacing = 10.dp) {
            Column(Modifier.padding(start = 2.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                model.contentLines.forEach { Text(it, style = mmFont(15f), color = MMInk.Text) }
            }
            if (model.records.isNotEmpty()) {
                MMGroup(Modifier.padding(top = 6.dp)) {
                    model.records.forEachIndexed { index, record ->
                        if (index > 0) MMRowDivider(leading = 52.dp)
                        IncludedRow(record)
                    }
                }
            }
        }

        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            when (val packet = model.packet) {
                Packet.NeedsMoveInProof -> MMPrimaryButton(
                    title = "Add move-in proof",
                    onClick = { onMissing(DisputePacketModel.Missing.Target.Rooms) },
                    icon = Icons.Outlined.PhotoCamera,
                )
                Packet.Ready, is Packet.Failed -> {
                    if (packet is Packet.Failed) Caption("The last packet couldn't be generated. Your evidence is unchanged.", center = true)
                    MMPrimaryButton(title = "Generate evidence packet", onClick = onGenerate, icon = Icons.Outlined.Description)
                    if (packet is Packet.Failed && packet.lastGoodDate != null) {
                        MMSecondaryButton(
                            title = if (isDownloading) "Opening…" else "View last packet",
                            onClick = onView,
                            icon = Icons.Outlined.Description,
                            enabled = !isDownloading,
                        )
                    }
                    if (!model.hasPro) Caption("The evidence packet is part of Pro.", center = true)
                }
                Packet.Generating -> {
                    MMPrimaryButton(title = "Generating evidence packet…", onClick = {}, isLoading = true, enabled = false)
                    Caption("This takes a moment. You can leave this screen.", center = true)
                }
                is Packet.Generated -> {
                    MMPrimaryButton(
                        title = if (isDownloading) "Opening…" else "View evidence packet",
                        onClick = onView,
                        icon = Icons.Outlined.Description,
                        isLoading = isDownloading,
                        enabled = !isDownloading,
                    )
                    MMSecondaryButton(title = "Share", onClick = onShare, icon = Icons.Outlined.Share, enabled = !isDownloading)
                    TextButton(onClick = onGenerate, modifier = Modifier.heightIn(min = 48.dp)) {
                        Text("Generate a new packet", style = mmFont(14f), color = MMInk.Secondary)
                    }
                }
            }
        }
    }
}

/** A record already on file, in the rental record's row geometry: icon, title, what it is, a quiet check. */
@Composable
private fun IncludedRow(record: DisputePacketModel.Record) {
    Row(
        Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) { stateDescription = "Included" }
            .heightIn(min = 56.dp)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            includedIcon(record),
            contentDescription = null,
            tint = MMInk.Text.copy(alpha = 0.8f),
            modifier = Modifier.size(20.dp).width(24.dp),
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(record.title, style = mmFont(16f), color = MMInk.Text)
            Text(record.detail, style = mmFont(13f), color = MMInk.Secondary)
        }
        Icon(Icons.Filled.Check, contentDescription = null, tint = MMInk.Text.copy(alpha = 0.7f), modifier = Modifier.size(16.dp))
    }
}

/** iOS: reports "doc.richtext", documents their record icon, maintenance "wrench.and.screwdriver". */
private fun includedIcon(record: DisputePacketModel.Record): ImageVector = when (record.kind) {
    DisputePacketModel.RecordKind.Report -> Icons.Outlined.Description
    DisputePacketModel.RecordKind.Document ->
        VaultDocumentKind.entries.firstOrNull { it.raw == record.id }?.let(::recordIcon) ?: Icons.AutoMirrored.Outlined.InsertDriveFile
    DisputePacketModel.RecordKind.Maintenance -> Icons.Outlined.Build
}

@Composable
private fun Section(title: String, spacing: Dp = 12.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
        MMSectionTitle(title)
        content()
    }
}

@Composable
private fun Caption(text: String, center: Boolean = false) {
    Text(
        text,
        style = mmFont(13f),
        color = MMInk.Secondary,
        textAlign = if (center) TextAlign.Center else TextAlign.Start,
        modifier = Modifier.padding(start = 2.dp),
    )
}

@Composable
private fun Field(label: String, placeholder: String, value: String, onChange: (String) -> Unit, keyboard: KeyboardOptions) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label, color = MMInk.Secondary) },
        placeholder = { Text(placeholder, color = MMInk.Secondary.copy(alpha = 0.7f)) },
        keyboardOptions = keyboard,
        singleLine = false,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = MMInk.Text,
            unfocusedTextColor = MMInk.Text,
            focusedBorderColor = MMInk.Text,
            unfocusedBorderColor = MMInk.CardStroke,
            focusedLabelColor = MMInk.Secondary,
            unfocusedLabelColor = MMInk.Secondary,
            cursorColor = MMInk.Text,
            focusedContainerColor = MMInk.Card,
            unfocusedContainerColor = MMInk.Card,
        ),
    )
}

/**
 * iOS `MMChip`: selected is solid ink with white semibold text; unselected a white card with a hairline stroke;
 * 36dp tall inside a 48dp touch target. Never green.
 */
@Composable
private fun RoomChip(name: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .heightIn(min = 48.dp)
            .mmPressable(role = Role.Checkbox, onClick = onClick)
            .semantics { this.selected = selected; stateDescription = if (selected) "Selected" else "Not selected" },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .heightIn(min = 36.dp)
                .clip(CircleShape)
                .background(if (selected) MMInk.Text else MMInk.Card)
                .border(1.dp, if (selected) Color.Transparent else MMInk.CardStroke, CircleShape)
                .padding(horizontal = 14.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                name,
                style = mmFont(14f, if (selected) FontWeight.SemiBold else FontWeight.Normal),
                color = if (selected) Color.White else MMInk.Text,
            )
        }
    }
}
