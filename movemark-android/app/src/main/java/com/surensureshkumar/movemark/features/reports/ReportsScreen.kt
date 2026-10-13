package com.surensureshkumar.movemark.features.reports

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.core.content.FileProvider
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
import com.surensureshkumar.movemark.data.export.DisputePacketReadiness
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.MoveOutReportReadiness
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.features.reports.components.ExportHistoryEmptyState
import com.surensureshkumar.movemark.features.reports.components.ExportHistorySection
import com.surensureshkumar.movemark.features.reports.components.MMReportExportSection
import com.surensureshkumar.movemark.features.reports.components.MMReportNoVaultPlaceholder
import com.surensureshkumar.movemark.features.reports.components.MMReportPreviewHero
import com.surensureshkumar.movemark.features.reports.components.MMReportReadinessChecklist
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import com.surensureshkumar.movemark.features.subscription.PaywallReason

@Composable
fun ReportsScreen(
    onContinueRoomProof: () -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onOpenVault: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ReportsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val context = LocalContext.current
    val reduceMotion = MMMotion.rememberReduceMotion()
    var appeared by remember { mutableStateOf(reduceMotion) }

    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) appeared = true
    }

    LaunchedEffect(Unit) {
        viewModel.reportPdf.collect { payload ->
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                payload.file,
            )
            when (payload.action) {
                ReportPdfAction.View -> {
                    val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/pdf")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    runCatching {
                        context.startActivity(Intent.createChooser(viewIntent, "View report"))
                    }.onFailure {
                        shareLocalPdf(context, uri, payload.displayTitle)
                    }
                }
                ReportPdfAction.Share -> shareLocalPdf(context, uri, payload.displayTitle)
            }
        }
    }

    val isLoading = state.propertyLoading || (state.exportsLoading && state.exports.isEmpty())
    val (ctaTitle, ctaEnabled, ctaLoading) = state.primaryCta()
    val (moveOutCtaTitle, moveOutCtaEnabled, moveOutCtaLoading) = state.moveOutCta(hasPro)
    val (disputeCtaTitle, disputeCtaEnabled, disputeCtaLoading) = state.disputeCta(hasPro)
        val showChecklist = !state.noVault && state.readiness != ReportReadiness.NoVault && !isLoading && state.exports.isEmpty()
        val showStatusStrip = !state.noVault && !isLoading && state.exports.isNotEmpty()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
            .padding(top = 12.dp, bottom = MMSpacing.ReportsTabScrollBottom.dp),
    ) {
        MMProofSectionHeader(
            title = "Your reports",
            subtitle = "Shareable records built from your saved proof.",
        )
        Spacer(Modifier.height(12.dp))

        when {
            state.noVault && !state.propertyLoading -> {
                MMReportNoVaultPlaceholder(onOpenVault = onOpenVault)
            }
            else -> {
                if (showChecklist) {
                    MMReportReadinessChecklist(
                        items = state.checklistItems,
                        appeared = appeared,
                        reduceMotion = reduceMotion,
                    )
                    Spacer(Modifier.height(14.dp))
                }
                if (showStatusStrip) {
                    ReportStatusStrip(
                        moveIn = state.readiness,
                        moveOut = state.moveOutReadiness,
                        dispute = state.disputeReadiness,
                    )
                    Spacer(Modifier.height(14.dp))
                }
                Text(
                    "CURRENT REPORTS",
                    color = MMColors.TextMuted,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 1.05.sp,
                )
                Spacer(Modifier.height(8.dp))
                MMReportPreviewHero(
                    readiness = state.readiness,
                    metricsLine = state.metricsLine(),
                    headline = state.heroHeadline(),
                    footnote = state.heroFootnote(),
                    proofChips = state.proofChips,
                    generatedLine = generatedLine(state.exports, "move_in_report"),
                    recordId = archivalRecordId(state.exports, "move_in_report"),
                    primaryTitle = ctaTitle,
                    primaryEnabled = ctaEnabled,
                    primaryLoading = ctaLoading,
                    onPrimary = { viewModel.onPrimaryAction(onContinueRoomProof) },
                    appeared = appeared,
                    reduceMotion = reduceMotion,
                    loading = isLoading,
                )
                Spacer(Modifier.height(24.dp))
                MMReportExportSection(
                    sectionTitle = "Move-out report",
                    sectionSubtitle = "Re-capture rooms before you return the keys.",
                    statusLine = moveOutStatusLabel(state.moveOutReadiness),
                    statusColor = moveOutStatusColor(state.moveOutReadiness),
                    metricsLine = moveOutMetricsLine(state),
                    footnote = moveOutFootnote(state.moveOutReadiness),
                    primaryTitle = moveOutCtaTitle,
                    primaryEnabled = moveOutCtaEnabled,
                    primaryLoading = moveOutCtaLoading,
                    onPrimary = {
                        viewModel.onMoveOutPrimaryAction(
                            hasPro = hasPro,
                            onOpenMoveOutProof = onOpenMoveOutProof,
                            onShowPaywall = onShowPaywall,
                        )
                    },
                    appeared = appeared,
                    reduceMotion = reduceMotion,
                    isProcessing = state.moveOutReadiness == MoveOutReportReadiness.Processing,
                    isProLocked = !hasPro,
                    generatedLine = generatedLine(state.exports, "move_out_report"),
                    recordId = archivalRecordId(state.exports, "move_out_report"),
                )
                Spacer(Modifier.height(20.dp))
                MMReportExportSection(
                    sectionTitle = "Dispute packet",
                    sectionSubtitle = "Bundle your proof if your deposit is questioned.",
                    statusLine = disputeStatusLabel(state.disputeReadiness),
                    statusColor = disputeStatusColor(state.disputeReadiness),
                    metricsLine = null,
                    footnote = disputeFootnote(state.disputeReadiness),
                    primaryTitle = disputeCtaTitle,
                    primaryEnabled = disputeCtaEnabled,
                    primaryLoading = disputeCtaLoading,
                    onPrimary = {
                        viewModel.onDisputePrimaryAction(
                            hasPro = hasPro,
                            onContinueRoomProof = onContinueRoomProof,
                            onShowPaywall = onShowPaywall,
                        )
                    },
                    appeared = appeared,
                    reduceMotion = reduceMotion,
                    isProcessing = state.disputeReadiness == DisputePacketReadiness.Processing,
                    isProLocked = !hasPro,
                    useQuietPrimaryWhenLocked = true,
                    legalNote = "MoveMark organizes your proof. It does not provide legal advice.",
                    generatedLine = generatedLine(state.exports, "dispute_packet", "dispute_summary"),
                    recordId = archivalRecordId(state.exports, "dispute_packet", "dispute_summary"),
                )
                if (state.exports.isNotEmpty()) {
                    Spacer(Modifier.height(24.dp))
                    ExportHistorySection(
                        exports = state.exports,
                        onShare = { row -> viewModel.shareExport(row) },
                        onRetry = { row -> viewModel.retryExport(row) },
                    )
                } else if (!state.exportsLoading && !state.noVault) {
                    Spacer(Modifier.height(24.dp))
                    ExportHistoryEmptyState()
                }
            }
        }

        state.banner?.let { msg ->
            Spacer(Modifier.height(12.dp))
            Text(
                msg,
                color = if (state.bannerIsError) MMColors.SemanticDanger else MMColors.Primary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

private fun moveOutStatusLabel(readiness: MoveOutReportReadiness): String = when (readiness) {
    MoveOutReportReadiness.NoProof -> "Needs proof"
    MoveOutReportReadiness.ReadyToMake -> "Can be made"
    MoveOutReportReadiness.Processing -> "Generating record"
    MoveOutReportReadiness.ReadyToShare -> "Ready to share"
    MoveOutReportReadiness.Failed -> "Failed"
}

private fun disputeStatusLabel(readiness: DisputePacketReadiness): String = when (readiness) {
    DisputePacketReadiness.NoProof -> "Needs proof"
    DisputePacketReadiness.ReadyToMake -> "Can be made"
    DisputePacketReadiness.Processing -> "Generating record"
    DisputePacketReadiness.ReadyToShare -> "Ready to share"
    DisputePacketReadiness.Failed -> "Failed"
}

private fun moveOutStatusColor(readiness: MoveOutReportReadiness) = when (readiness) {
    MoveOutReportReadiness.ReadyToShare -> MMColors.Primary
    MoveOutReportReadiness.Failed -> MMColors.SemanticDanger
    MoveOutReportReadiness.Processing -> MMColors.TextPrimary
    MoveOutReportReadiness.ReadyToMake -> MMColors.SemanticInfo
    MoveOutReportReadiness.NoProof -> MMColors.TextSecondary
}

private fun disputeStatusColor(readiness: DisputePacketReadiness) = when (readiness) {
    DisputePacketReadiness.ReadyToShare -> MMColors.Primary
    DisputePacketReadiness.Failed -> MMColors.SemanticDanger
    DisputePacketReadiness.Processing -> MMColors.TextPrimary
    DisputePacketReadiness.ReadyToMake -> MMColors.SemanticInfo
    DisputePacketReadiness.NoProof -> MMColors.TextSecondary
}

private fun moveOutMetricsLine(state: ReportsUiState): String? {
    if (state.moveOutPhotos <= 0) return null
    return "${state.moveOutDocumentedRooms} of ${state.totalRooms} rooms · ${state.moveOutPhotos} move-out photos"
}

private fun moveOutFootnote(readiness: MoveOutReportReadiness): String? = when (readiness) {
    MoveOutReportReadiness.NoProof -> "Capture move-out room photos first."
    MoveOutReportReadiness.ReadyToMake -> "Add more move-out proof for a stronger report."
    MoveOutReportReadiness.ReadyToShare ->
        "${MoveMarkGrowthCopy.MOVE_OUT_RECORD_READY} ${MoveMarkGrowthCopy.MOVE_OUT_RECORD_READY_DETAIL}"
    MoveOutReportReadiness.Failed -> "Something went wrong. Try again when you're ready."
    MoveOutReportReadiness.Processing -> null
}

private fun disputeFootnote(readiness: DisputePacketReadiness): String? = when (readiness) {
    DisputePacketReadiness.NoProof -> "Save move-in room proof before building a packet."
    DisputePacketReadiness.ReadyToMake -> "Add more proof for a stronger packet."
    DisputePacketReadiness.ReadyToShare ->
        "${MoveMarkGrowthCopy.DISPUTE_PACKET_READY} ${MoveMarkGrowthCopy.DISPUTE_PACKET_READY_DETAIL}"
    DisputePacketReadiness.Failed -> "Something went wrong. Try again when you're ready."
    DisputePacketReadiness.Processing -> null
}

private enum class StripMark { Ready, Attention, Pending, NotStarted }

@Composable
private fun ReportStatusStrip(
    moveIn: ReportReadiness,
    moveOut: MoveOutReportReadiness,
    dispute: DisputePacketReadiness,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MMColors.SurfaceRaised)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StripItem("Move-in", moveInMark(moveIn), Modifier.weight(1f))
        Box(Modifier.width(1.dp).height(18.dp).background(MMColors.CardStroke))
        StripItem("Move-out", moveOutMark(moveOut), Modifier.weight(1f))
        Box(Modifier.width(1.dp).height(18.dp).background(MMColors.CardStroke))
        StripItem("Dispute", disputeMark(dispute), Modifier.weight(1f))
    }
}

@Composable
private fun StripItem(title: String, mark: StripMark, modifier: Modifier) {
    val tint = when (mark) {
        StripMark.Ready -> MMColors.Primary
        StripMark.Attention -> MMColors.SemanticWarning
        StripMark.Pending, StripMark.NotStarted -> MMColors.TextMuted
    }
    val icon: ImageVector = when (mark) {
        StripMark.Ready -> Icons.Default.CheckCircle
        StripMark.Attention -> Icons.Default.Error
        StripMark.Pending, StripMark.NotStarted -> Icons.Default.RadioButtonUnchecked
    }
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.height(16.dp))
        Text(
            title,
            color = if (mark == StripMark.Ready) MMColors.TextPrimary else MMColors.TextSecondary,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 6.dp),
        )
    }
}

private fun moveInMark(readiness: ReportReadiness): StripMark = when (readiness) {
    ReportReadiness.ReadyToShare -> StripMark.Ready
    ReportReadiness.Failed, ReportReadiness.NotReady -> StripMark.Attention
    ReportReadiness.Processing -> StripMark.Pending
    ReportReadiness.ReadyToMake, ReportReadiness.NoVault -> StripMark.NotStarted
}

private fun moveOutMark(readiness: MoveOutReportReadiness): StripMark = when (readiness) {
    MoveOutReportReadiness.ReadyToShare -> StripMark.Ready
    MoveOutReportReadiness.Failed -> StripMark.Attention
    MoveOutReportReadiness.Processing -> StripMark.Pending
    MoveOutReportReadiness.NoProof, MoveOutReportReadiness.ReadyToMake -> StripMark.NotStarted
}

private fun disputeMark(readiness: DisputePacketReadiness): StripMark = when (readiness) {
    DisputePacketReadiness.ReadyToShare -> StripMark.Ready
    DisputePacketReadiness.Failed -> StripMark.Attention
    DisputePacketReadiness.Processing -> StripMark.Pending
    DisputePacketReadiness.NoProof, DisputePacketReadiness.ReadyToMake -> StripMark.NotStarted
}

private fun generatedLine(exports: List<ExportRow>, vararg types: String): String? {
    val row = exports
        .filter { it.type in types && it.verification == ExportVerificationStatus.Ready }
        .maxByOrNull { it.requestedAt.orEmpty() }
        ?: return null
    val date = shortExportDate(row.requestedAt)
    return if (date.isBlank()) null else "Generated $date"
}

private fun archivalRecordId(exports: List<ExportRow>, vararg types: String): String? {
    val row = exports
        .filter { it.type in types }
        .maxByOrNull { it.requestedAt.orEmpty() }
        ?: return null
    return "MM-RP-" + row.id.toString().take(4).uppercase()
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
