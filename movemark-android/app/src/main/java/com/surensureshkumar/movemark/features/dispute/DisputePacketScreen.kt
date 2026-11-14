package com.surensureshkumar.movemark.features.dispute

import androidx.compose.ui.graphics.Color
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
        // 1.4 grammar (iOS dispute builder in MMScreen): the purpose in the header, the packet on the sheet.
        MMScreen(
            title = "Dispute packet",
            lines = listOf("Build a record of the evidence related to this issue."),
            onBack = onBack,
            modifier = Modifier.imePadding(),
        ) {
                val m = model
                if (m == null) {
                    Header("No rental yet", null)
                    Text("A packet is assembled from a rental's recorded evidence.", color = MMInk.Secondary, fontSize = 15.sp)
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
                    )
                }
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

@Composable
private fun Header(title: String, status: String?, ready: Boolean = false) {
    // The screen header carries "Dispute packet" and its purpose; this names the case on the sheet.
    Text(title, style = com.surensureshkumar.movemark.core.design.mmFont(20f, FontWeight.SemiBold), color = MMInk.Text, modifier = Modifier.semantics { heading() })
    if (status != null) {
        Row(Modifier.padding(top = 18.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(7.dp).background(if (ready) MMInk.LimeMark else MMInk.Secondary.copy(alpha = 0.6f), CircleShape))
            Spacer(Modifier.width(7.dp))
            Text(status, fontSize = 12.5.sp, fontWeight = FontWeight.Medium, color = MMInk.Text)
        }
    }
}

/** Presentational: header → what is being questioned → evidence to review → missing proof → contents → one action. */
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
) {
    Header(model.title, model.statusLine, model.isReadyState)
    Column(Modifier.padding(top = 28.dp), verticalArrangement = Arrangement.spacedBy(32.dp)) {
        if (errorMessage != null) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(MMInk.Secondary.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
            ) {
                Text(errorMessage, fontSize = 14.sp, color = MMInk.Text)
                TextButton(onClick = onRetry, modifier = Modifier.heightIn(min = 48.dp)) {
                    Text(errorActionTitle, color = MMInk.Text, fontWeight = FontWeight.SemiBold)
                }
            }
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
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                                .background(MMInk.Paper, RoundedCornerShape(18.dp))
                                .border(1.dp, MMInk.CardStroke, RoundedCornerShape(18.dp)),
                        ) { MoveOutCompactRow(item, sign, justCompared = false) { onOpenPhoto(item, it) } }
                    }
                }
            }
        }

        if (model.missing.isNotEmpty()) {
            Section("Missing proof") {
                Group {
                    model.missing.forEachIndexed { index, item ->
                        if (index > 0) Divider()
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .heightIn(min = 56.dp)
                                .clickable(role = Role.Button) { onMissing(item.target) }
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(item.title, fontSize = 16.sp, color = MMInk.Text)
                                Text(item.detail, fontSize = 13.sp, color = MMInk.Secondary)
                            }
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MMInk.Secondary)
                        }
                    }
                }
            }
        }

        Section(if (model.isGenerated) "A new packet would include" else "Generated packet includes") {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                model.contentLines.forEach { Text(it, fontSize = 15.sp, color = MMInk.Text) }
            }
            if (model.records.isNotEmpty()) {
                Group {
                    model.records.forEachIndexed { index, record ->
                        if (index > 0) Divider(start = 52)
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .heightIn(min = 58.dp)
                                .semantics(mergeDescendants = true) { stateDescription = "Included" }
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                when (record.kind) {
                                    DisputePacketModel.RecordKind.Report -> Icons.Filled.Description
                                    DisputePacketModel.RecordKind.Document -> Icons.AutoMirrored.Filled.InsertDriveFile
                                    DisputePacketModel.RecordKind.Maintenance -> Icons.Filled.Build
                                },
                                contentDescription = null,
                                tint = MMInk.Text.copy(alpha = 0.8f),
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(Modifier.width(16.dp))
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(record.title, fontSize = 16.sp, color = MMInk.Text)
                                Text(record.detail, fontSize = 13.sp, color = MMInk.Secondary)
                            }
                            Icon(Icons.Filled.Check, contentDescription = null, tint = MMInk.Text.copy(alpha = 0.7f), modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }

        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            when (val packet = model.packet) {
                Packet.NeedsMoveInProof -> MMPrimaryButton(title = "Add move-in proof", onClick = { onMissing(DisputePacketModel.Missing.Target.Rooms) })
                Packet.Ready, is Packet.Failed -> {
                    if (packet is Packet.Failed) Caption("The last packet couldn't be generated. Your evidence is unchanged.", center = true)
                    MMPrimaryButton(title = "Generate evidence packet", onClick = onGenerate)
                    if (packet is Packet.Failed && packet.lastGoodDate != null) {
                        MMSecondaryButton(title = if (isDownloading) "Opening…" else "View last packet", onClick = onView, enabled = !isDownloading)
                    }
                    if (!model.hasPro) Caption("The evidence packet is part of Pro.", center = true)
                }
                Packet.Generating -> {
                    MMPrimaryButton(title = "Generating evidence packet…", onClick = {}, isLoading = true, enabled = false)
                    Caption("This takes a moment. You can leave this screen.", center = true)
                }
                is Packet.Generated -> {
                    MMPrimaryButton(title = if (isDownloading) "Opening…" else "View evidence packet", onClick = onView, isLoading = isDownloading, enabled = !isDownloading)
                    MMSecondaryButton(title = "Share", onClick = onShare, enabled = !isDownloading)
                    TextButton(onClick = onGenerate, modifier = Modifier.heightIn(min = 48.dp)) {
                        Text("Generate a new packet", fontSize = 14.sp, color = MMInk.Secondary)
                    }
                }
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMInk.Text, modifier = Modifier.semantics { heading() })
        content()
    }
}

@Composable
private fun Caption(text: String, center: Boolean = false) {
    Text(
        text,
        fontSize = 13.sp,
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
        placeholder = { Text(placeholder) },
        keyboardOptions = keyboard,
        singleLine = false,
        modifier = Modifier.fillMaxWidth(),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = MMInk.Text,
            unfocusedTextColor = MMInk.Text,
            focusedBorderColor = MMInk.Text,
            unfocusedBorderColor = MMInk.CardStroke,
            focusedLabelColor = MMInk.Secondary,
            unfocusedLabelColor = MMInk.Secondary,
            cursorColor = MMInk.Text,
        ),
    )
}

@Composable
private fun RoomChip(name: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Row(
        Modifier
            .heightIn(min = 48.dp)
            .clickable(role = Role.Checkbox, onClick = onClick)
            .semantics { this.selected = selected; stateDescription = if (selected) "Selected" else "Not selected" }
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            Modifier
                .background(if (selected) MMInk.Text.copy(alpha = 0.18f) else MMInk.Paper, shape)
                .border(1.dp, if (selected) MMInk.Text else MMInk.CardStroke, shape)
                .padding(horizontal = 14.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (selected) {
                Icon(Icons.Filled.Check, contentDescription = null, tint = MMInk.Text, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
            }
            Text(name, fontSize = 14.sp, color = MMInk.Text)
        }
    }
}

@Composable
private fun Group(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MMInk.Paper, RoundedCornerShape(18.dp))
            .border(1.dp, MMInk.CardStroke, RoundedCornerShape(18.dp)),
        content = content,
    )
}

@Composable
private fun Divider(start: Int = 16) = HorizontalDivider(Modifier.padding(start = start.dp), thickness = 0.5.dp, color = MMInk.CardStroke)
