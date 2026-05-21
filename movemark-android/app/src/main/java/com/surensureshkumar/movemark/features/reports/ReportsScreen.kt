package com.surensureshkumar.movemark.features.reports

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.domain.RoomProofMetrics

@Composable
fun ReportsScreen(
    modifier: Modifier = Modifier,
    viewModel: ReportsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        Text("Report", style = androidx.compose.material3.MaterialTheme.typography.headlineLarge)
        Spacer(Modifier.height(16.dp))
        when (val s = state) {
            is ReportUiState.Loading -> CircularProgressIndicator(color = MMColors.Primary)
            is ReportUiState.NoVault -> Text("Create a rental vault first.", color = MMColors.TextSecondary)
            is ReportUiState.Ready -> {
                MMProofCard {
                    Text("Move-in report", style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(8.dp))
                    Text(s.subtitle, color = MMColors.TextSecondary)
                }
                Spacer(Modifier.height(16.dp))
                if (s.canExport) {
                    MMButton(text = "Make report", onClick = viewModel::requestExport, loading = s.exporting)
                } else {
                    Text(s.blockReason, color = MMColors.SemanticWarning)
                }
                s.message?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(it, color = if (s.isError) MMColors.SemanticDanger else MMColors.Primary)
                }
            }
        }
    }
}
