package com.surensureshkumar.movemark.features.reports

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.data.export.DisputePacketReadiness
import com.surensureshkumar.movemark.data.export.MoveOutReportReadiness
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.features.reports.components.ExportHistorySection
import com.surensureshkumar.movemark.features.reports.components.MMReportExportSection
import com.surensureshkumar.movemark.features.reports.components.MMReportPreviewHero
import com.surensureshkumar.movemark.features.reports.components.MMReportReadinessChecklist
import com.surensureshkumar.movemark.features.subscription.PaywallReason

@Composable
fun ReportsScreen(
    onContinueRoomProof: () -> Unit,
    onOpenMoveOutProof: () -> Unit,
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
        viewModel.shareUrl.collect { url ->
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "Share report")
            runCatching { context.startActivity(chooser) }
                .onFailure {
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TEXT, url)
                    }
                    context.startActivity(Intent.createChooser(send, "Share report"))
                }
        }
    }

    val (ctaTitle, ctaEnabled, ctaLoading) = state.primaryCta()
    val (moveOutCtaTitle, moveOutCtaEnabled, moveOutCtaLoading) = state.moveOutCta()
    val (disputeCtaTitle, disputeCtaEnabled, disputeCtaLoading) = state.disputeCta()
    val showChecklist = state.readiness != ReportReadiness.NoVault && !state.noVault

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        MMProofSectionHeader(
            title = "Your move-in report",
            subtitle = "Build a clean report from saved room proof.",
        )
        Spacer(Modifier.height(20.dp))

        when {
            state.propertyLoading && state.exports.isEmpty() && state.noVault -> {
                CircularProgressIndicator(color = MMColors.Primary)
            }
            state.noVault -> {
                Text("Create a rental vault first.", color = MMColors.TextSecondary, fontSize = 15.sp)
            }
            else -> {
                MMReportPreviewHero(
                    readiness = state.readiness,
                    metricsLine = state.metricsLine(),
                    headline = state.heroHeadline(),
                    footnote = state.heroFootnote(),
                    proofChips = state.proofChips,
                    primaryTitle = ctaTitle,
                    primaryEnabled = ctaEnabled,
                    primaryLoading = ctaLoading,
                    onPrimary = { viewModel.onPrimaryAction(onContinueRoomProof) },
                    appeared = appeared,
                    reduceMotion = reduceMotion,
                )
                if (showChecklist) {
                    Spacer(Modifier.height(20.dp))
                    MMReportReadinessChecklist(
                        items = state.checklistItems,
                        appeared = appeared,
                        reduceMotion = reduceMotion,
                    )
                }
                Spacer(Modifier.height(24.dp))
                MMReportExportSection(
                    sectionTitle = "Move-out report",
                    sectionSubtitle = null,
                    statusLine = state.moveOutReportStatus,
                    statusColor = moveOutStatusColor(state.moveOutReadiness),
                    metricsLine = moveOutMetricsLine(state),
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
                )
                Spacer(Modifier.height(24.dp))
                MMReportExportSection(
                    sectionTitle = "Dispute packet",
                    sectionSubtitle = "Bundle your proof if your deposit is questioned.",
                    statusLine = state.disputePacketStatus,
                    statusColor = disputeStatusColor(state.disputeReadiness),
                    metricsLine = null,
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
                    legalNote = "MoveMark organizes your proof. It does not provide legal advice.",
                )
                if (state.exports.isNotEmpty()) {
                    Spacer(Modifier.height(24.dp))
                    ExportHistorySection(exports = state.exports)
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

private fun moveOutStatusColor(readiness: MoveOutReportReadiness) = when (readiness) {
    MoveOutReportReadiness.ReadyToShare -> MMColors.Primary
    MoveOutReportReadiness.Failed -> MMColors.SemanticDanger
    MoveOutReportReadiness.Processing -> MMColors.SemanticWarning
    MoveOutReportReadiness.ReadyToMake -> MMColors.TextPrimary
    MoveOutReportReadiness.NoProof -> MMColors.TextSecondary
}

private fun disputeStatusColor(readiness: DisputePacketReadiness) = when (readiness) {
    DisputePacketReadiness.ReadyToShare -> MMColors.Primary
    DisputePacketReadiness.Failed -> MMColors.SemanticDanger
    DisputePacketReadiness.Processing -> MMColors.SemanticWarning
    DisputePacketReadiness.ReadyToMake -> MMColors.TextPrimary
    DisputePacketReadiness.NoProof -> MMColors.TextSecondary
}

private fun moveOutMetricsLine(state: ReportsUiState): String? {
    if (state.moveOutPhotos <= 0) return null
    return "${state.moveOutDocumentedRooms} of ${state.totalRooms} rooms · ${state.moveOutPhotos} move-out photos"
}
