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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.features.reports.components.ExportHistorySection
import com.surensureshkumar.movemark.features.reports.components.MMReportPreviewHero
import com.surensureshkumar.movemark.features.reports.components.MMReportReadinessChecklist

@Composable
fun ReportsScreen(
    onContinueRoomProof: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ReportsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.shareUrl.collect { url ->
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "Share move-in report")
            runCatching { context.startActivity(chooser) }
                .onFailure {
                    // fallback: generic send
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TEXT, url)
                    }
                    context.startActivity(Intent.createChooser(send, "Share move-in report"))
                }
        }
    }

    val scroll = rememberScrollState()
    val (ctaTitle, ctaEnabled, ctaLoading) = state.primaryCta()
    val showChecklist = state.readiness != ReportReadiness.NoVault

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(scroll)
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        Text(
            "Your move-in report",
            style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
            color = MMColors.TextPrimary,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            "Build a clean report from saved room proof.",
            color = MMColors.TextSecondary,
            fontSize = 15.sp,
        )
        Spacer(Modifier.height(20.dp))

        when {
            state.propertyLoading && state.exports.isEmpty() -> {
                CircularProgressIndicator(color = MMColors.Primary)
            }
            state.noVault -> {
                Text("Create a rental vault first.", color = MMColors.TextSecondary)
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
                )
                if (showChecklist) {
                    Spacer(Modifier.height(20.dp))
                    MMReportReadinessChecklist(items = state.checklistItems)
                }
                if (state.exports.isNotEmpty()) {
                    Spacer(Modifier.height(24.dp))
                    ExportHistorySection(exports = state.exports)
                }
                if (!state.noVault) {
                    Spacer(Modifier.height(24.dp))
                    Text(
                        "Move-out report",
                        style = androidx.compose.material3.MaterialTheme.typography.titleLarge,
                        color = MMColors.TextPrimary,
                    )
                    Spacer(Modifier.height(8.dp))
                    MMProofCard {
                        Text(
                            state.moveOutReportStatus,
                            color = if (state.moveOutReportReady) MMColors.Primary else MMColors.TextSecondary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        if (state.moveOutPhotos > 0) {
                            Spacer(Modifier.height(6.dp))
                            Text(
                                "${state.moveOutDocumentedRooms} of ${state.totalRooms} rooms · ${state.moveOutPhotos} photos",
                                color = MMColors.TextMuted,
                                fontSize = 13.sp,
                            )
                            Spacer(Modifier.height(6.dp))
                            Text(
                                "Report generation coming soon.",
                                color = MMColors.TextMuted,
                                fontSize = 13.sp,
                            )
                        }
                    }
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
