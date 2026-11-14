/**
 * @file Reports tab (iOS `ReportsHomeView`): a document control centre for one rental. The move-in report is the
 *       artifact at the top — what it covers, whether it's ready, and the one thing to do with it; past reports
 *       sit below in a quiet history; the other report types (move-out, dispute packet) follow. Lime marks only
 *       the single most important action. All actions go through [ReportsViewModel] exactly as before.
 * @domain reports
 * @see [[ReportsHomeView.swift]] — iOS reference
 */
package com.surensureshkumar.movemark.features.reports

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.FindInPage
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRow
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.MMSectionTitle
import com.surensureshkumar.movemark.core.design.MMTag
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.data.export.DisputePacketReadiness
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.export.MoveOutReportReadiness
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.data.export.ReportReadinessMapper
import com.surensureshkumar.movemark.features.reports.components.ExportHistorySection
import com.surensureshkumar.movemark.features.reports.components.ReportPdfViewer
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun ReportsScreen(
    onContinueRoomProof: () -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onOpenVault: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    modifier: Modifier = Modifier,
    /** The dispute packet opens its builder, as on iOS; null keeps the in-place action. */
    onOpenDisputePacket: (() -> Unit)? = null,
    scrollState: androidx.compose.foundation.ScrollState = rememberScrollState(),
    viewModel: ReportsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val context = LocalContext.current

    var viewing by remember { mutableStateOf<ReportLocalPdf?>(null) }
    viewing?.let { payload ->
        ReportPdfViewer(
            file = payload.file,
            title = payload.displayTitle,
            onShare = {
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", payload.file)
                shareLocalPdf(context, uri, payload.displayTitle)
            },
            onClose = { viewing = null },
        )
    }

    LaunchedEffect(Unit) {
        viewModel.paywallRequests.collect { onShowPaywall(it) }
    }

    LaunchedEffect(Unit) {
        viewModel.reportPdf.collect { payload ->
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", payload.file)
            when (payload.action) {
                // Read it in the app (iOS QuickLook): no other PDF app needed.
                ReportPdfAction.View -> viewing = payload
                ReportPdfAction.Share -> shareLocalPdf(context, uri, payload.displayTitle)
            }
        }
    }

    val isLoading = state.propertyLoading || (state.exportsLoading && state.exports.isEmpty())

    MMScreen(
        title = "Your proof records",
        eyebrow = "Reports",
        tail = MMMetrics.RootTabTail,
        scrollState = scrollState,
        modifier = modifier,
    ) {
        state.banner?.let { msg ->
            MMNotice(msg, tone = if (state.bannerIsError) MMNoticeTone.Error else MMNoticeTone.Success)
            Spacer(Modifier.height(14.dp))
        }

        ReportArtifact(
            state = state,
            isLoading = isLoading,
            onOpenVault = onOpenVault,
            onPrimary = { viewModel.onPrimaryAction(onContinueRoomProof) },
            onShare = { ReportReadinessMapper.firstReadyExport(state.exports)?.let(viewModel::shareExport) },
        )

        if (state.exports.isNotEmpty()) {
            Spacer(Modifier.height(32.dp))
            MMSectionTitle("Report history")
            Spacer(Modifier.height(12.dp))
            ExportHistorySection(
                exports = state.exports,
                onShare = { row -> viewModel.shareExport(row) },
                onRetry = { row -> viewModel.retryExport(row) },
            )
        }

        if (!state.noVault) {
            Spacer(Modifier.height(32.dp))
            MMSectionTitle("More reports")
            Spacer(Modifier.height(12.dp))
            MMGroup(
                radius = MMMetrics.CardRadius,
                footer = "MoveMark organizes your proof. It does not provide legal advice.",
            ) {
                MMRow(
                    title = "Move-out report",
                    subtitle = moveOutDetail(state, hasPro),
                    titleSize = 14.5f,
                    trailing = otherTrailing(
                        processing = state.moveOutReadiness == MoveOutReportReadiness.Processing || state.moveOutActionInProgress,
                        locked = !hasPro,
                    ),
                    onClick = {
                        viewModel.onMoveOutPrimaryAction(
                            hasPro = hasPro,
                            onOpenMoveOutProof = onOpenMoveOutProof,
                            onShowPaywall = onShowPaywall,
                        )
                    },
                )
                MMRowDivider()
                MMRow(
                    title = "Dispute packet",
                    subtitle = disputeDetail(state, hasPro),
                    titleSize = 14.5f,
                    trailing = otherTrailing(
                        processing = state.disputeReadiness == DisputePacketReadiness.Processing || state.disputeActionInProgress,
                        locked = !hasPro,
                    ),
                    onClick = onOpenDisputePacket ?: {
                        viewModel.onDisputePrimaryAction(
                            hasPro = hasPro,
                            onContinueRoomProof = onContinueRoomProof,
                            onShowPaywall = onShowPaywall,
                        )
                    },
                )
            }
        }
    }
}

private fun otherTrailing(processing: Boolean, locked: Boolean): (@Composable androidx.compose.foundation.layout.RowScope.() -> Unit)? = when {
    processing -> ({ CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(16.dp)) })
    locked -> ({ MMTag("Pro") })
    else -> null
}

/** The move-in report: what it covers, its state in one line, and the one action. */
@Composable
private fun ReportArtifact(
    state: ReportsUiState,
    isLoading: Boolean,
    onOpenVault: () -> Unit,
    onPrimary: () -> Unit,
    onShare: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MMMetrics.CardRadius))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.CardRadius))
            .padding(18.dp),
    ) {
        if (state.noVault && !state.propertyLoading) {
            Text("No rental yet", style = mmFont(20f, FontWeight.SemiBold), color = MMInk.Text)
            Spacer(Modifier.height(6.dp))
            Text(
                "Reports are built from a rental's saved proof. Add your rental in Proof to start.",
                style = mmFont(14f),
                color = MMInk.Secondary,
            )
            Spacer(Modifier.height(12.dp))
            MMPrimaryButton(title = "Go to Proof", icon = Icons.Filled.Home, onClick = onOpenVault, height = 46.dp)
            return@Column
        }

        // Identity: what the report is and what it covers.
        Row(Modifier.semantics(mergeDescendants = true) {}) {
            Column(Modifier.weight(1f)) {
                Text("MOVE-IN REPORT", style = mmFont(11f, FontWeight.SemiBold, tracking = 0.6f), color = MMInk.Secondary)
                Text(
                    state.rentalName.ifBlank { "Your rental" },
                    style = mmFont(22f, FontWeight.SemiBold),
                    color = MMInk.Text,
                    maxLines = 2,
                    modifier = Modifier.padding(top = 6.dp),
                )
                roomsLine(state)?.let {
                    Text(it, style = mmFont(14.5f), color = MMInk.Text, modifier = Modifier.padding(top = 6.dp))
                }
                countsLine(state)?.let {
                    Text(it, style = mmFont(13f), color = MMInk.Secondary, modifier = Modifier.padding(top = 3.dp))
                }
            }
            if (!mmIsLargeFont()) {
                Spacer(Modifier.width(14.dp))
                Box(
                    Modifier
                        .size(width = 44.dp, height = 56.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MMInk.Paper),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Description, contentDescription = null, tint = MMInk.Text.copy(alpha = 0.55f), modifier = Modifier.size(22.dp))
                }
            }
        }

        // Status in one readable line, with one quiet line of support.
        Spacer(Modifier.height(16.dp))
        Box(Modifier.fillMaxWidth().height(1.dp).background(MMInk.Separator))
        val readiness = if (isLoading) null else state.readiness
        Row(
            Modifier
                .padding(top = 14.dp)
                .semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StatusMark(readiness)
            Spacer(Modifier.width(8.dp))
            Text(statusTitle(readiness), style = mmFont(15f, FontWeight.SemiBold), color = MMInk.Text)
        }
        statusDetail(readiness, state)?.let {
            Text(it, style = mmFont(13.5f), color = MMInk.Secondary, modifier = Modifier.padding(top = 4.dp))
        }

        val busy = state.moveInActionInProgress
        when (readiness) {
            ReportReadiness.NotReady, ReportReadiness.NoVault -> {
                Spacer(Modifier.height(18.dp))
                MMPrimaryButton(title = "Continue room proof", icon = Icons.Filled.CameraAlt, onClick = onPrimary, height = 46.dp)
            }
            ReportReadiness.ReadyToMake -> {
                Spacer(Modifier.height(18.dp))
                MMPrimaryButton(
                    title = if (busy) "Generating report…" else "Generate report",
                    icon = Icons.Filled.Description,
                    isLoading = busy,
                    onClick = onPrimary,
                    height = 46.dp,
                )
            }
            ReportReadiness.ReadyToShare -> {
                Spacer(Modifier.height(18.dp))
                MMPrimaryButton(
                    title = if (busy) "Opening…" else "View report",
                    icon = Icons.Filled.FindInPage,
                    isLoading = busy,
                    onClick = onPrimary,
                    height = 46.dp,
                )
                Spacer(Modifier.height(4.dp))
                MMSecondaryButton(title = "Share", icon = Icons.Filled.Share, onClick = onShare, enabled = !busy)
            }
            ReportReadiness.Failed -> {
                Spacer(Modifier.height(18.dp))
                MMPrimaryButton(
                    title = if (busy) "Retrying…" else "Retry",
                    icon = Icons.Filled.Refresh,
                    isLoading = busy,
                    onClick = onPrimary,
                    height = 46.dp,
                )
            }
            ReportReadiness.Processing, null -> Unit
        }
    }
}

@Composable
private fun StatusMark(readiness: ReportReadiness?) {
    when (readiness) {
        null, ReportReadiness.Processing ->
            CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
        ReportReadiness.ReadyToShare ->
            Box(Modifier.size(9.dp).clip(CircleShape).background(MMInk.LimeMark))
        ReportReadiness.Failed ->
            Icon(Icons.Filled.Error, contentDescription = null, tint = MMInk.Danger, modifier = Modifier.size(15.dp))
        ReportReadiness.NotReady, ReportReadiness.ReadyToMake, ReportReadiness.NoVault ->
            Box(Modifier.size(9.dp).border(1.5.dp, MMInk.Secondary, CircleShape))
    }
}

private fun statusTitle(readiness: ReportReadiness?): String = when (readiness) {
    null -> "Checking your records…"
    ReportReadiness.NotReady, ReportReadiness.NoVault -> "Needs room proof"
    ReportReadiness.ReadyToMake -> "Not generated yet"
    ReportReadiness.Processing -> "Generating report…"
    ReportReadiness.ReadyToShare -> "Ready"
    ReportReadiness.Failed -> "Couldn't generate report"
}

private fun statusDetail(readiness: ReportReadiness?, state: ReportsUiState): String? = when (readiness) {
    null -> null
    ReportReadiness.NotReady, ReportReadiness.NoVault ->
        "Document your rooms, then generate one dated PDF of your proof."
    ReportReadiness.ReadyToMake ->
        "One dated PDF with every room photo, record and issue, ready to send to your landlord."
    ReportReadiness.Processing -> "We're assembling your evidence into a PDF."
    ReportReadiness.ReadyToShare -> generatedLine(state.exports, ReportReadinessMapper.MOVE_IN_REPORT_TYPE)
    ReportReadiness.Failed -> "Your evidence is safe. Try again in a moment."
}

private fun roomsLine(state: ReportsUiState): String? {
    if (state.totalRooms <= 0) return null
    if (state.documentedRooms >= state.totalRooms) {
        return "${state.totalRooms} ${if (state.totalRooms == 1) "room" else "rooms"} documented"
    }
    return "${state.documentedRooms} of ${state.totalRooms} rooms documented"
}

private fun countsLine(state: ReportsUiState): String? {
    if (state.totalRooms <= 0 && state.totalPhotos <= 0) return null
    fun count(n: Int, noun: String) = "$n ${if (n == 1) noun else noun + "s"}"
    return listOf(count(state.totalPhotos, "photo"), count(state.supportingRecords, "record"), count(state.issueTags, "issue"))
        .joinToString(" · ")
}

/** iOS `ExportHistoryView.otherReports`: the pitch while locked, else the state in a few words. */
private fun moveOutDetail(state: ReportsUiState, hasPro: Boolean): String {
    if (!hasPro) return "Re-capture rooms before you return the keys."
    return when (state.moveOutReadiness) {
        MoveOutReportReadiness.NoProof -> "Not started"
        MoveOutReportReadiness.ReadyToMake -> "Ready to generate"
        MoveOutReportReadiness.Processing -> "Generating…"
        MoveOutReportReadiness.Failed -> "Couldn't generate · Tap to retry"
        MoveOutReportReadiness.ReadyToShare -> readyLine(state.exports, ReportReadinessMapper.MOVE_OUT_REPORT_TYPE)
    }
}

private fun disputeDetail(state: ReportsUiState, hasPro: Boolean): String {
    if (!hasPro) return "Bundle your proof if your deposit is questioned."
    return when (state.disputeReadiness) {
        DisputePacketReadiness.NoProof -> "Needs move-in proof"
        DisputePacketReadiness.ReadyToMake -> "Ready to generate"
        DisputePacketReadiness.Processing -> "Generating…"
        DisputePacketReadiness.Failed -> "Couldn't generate · Tap to retry"
        DisputePacketReadiness.ReadyToShare -> readyLine(state.exports, ReportReadinessMapper.DISPUTE_PACKET_TYPE, "dispute_summary")
    }
}

private fun readyLine(exports: List<ExportRow>, vararg types: String): String =
    generatedLine(exports, *types)?.removePrefix("Generated ")?.let { "Ready · $it" } ?: "Ready"

private fun generatedLine(exports: List<ExportRow>, vararg types: String): String? {
    val row = exports
        .filter { it.type in types && it.verification == ExportVerificationStatus.Ready }
        .maxByOrNull { it.requestedAt.orEmpty() }
        ?: return null
    val date = shortExportDate(row.requestedAt)
    return if (date.isBlank()) null else "Generated $date"
}

private fun shortExportDate(raw: String?): String {
    if (raw.isNullOrBlank()) return ""
    return runCatching {
        DateTimeFormatter.ofPattern("MMM d · h:mm a", Locale.US)
            .withZone(ZoneId.systemDefault())
            .format(Instant.parse(raw))
    }.getOrElse { raw }
}

private fun shareLocalPdf(
    context: android.content.Context,
    uri: android.net.Uri,
    displayTitle: String,
) {
    val sendIntent = Intent(Intent.ACTION_SEND).apply {
        type = "application/pdf"
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_TITLE, displayTitle)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(sendIntent, "Share report"))
}
