package com.surensureshkumar.movemark.features.vault

import androidx.compose.foundation.clickable
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
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import java.util.UUID

@Composable
fun VaultScreen(
    onOpenRoom: (UUID) -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onAddProperty: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: VaultViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val propertyCount by viewModel.propertyCount.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        Text("Vault", style = androidx.compose.material3.MaterialTheme.typography.headlineLarge)
        Spacer(Modifier.height(16.dp))
        when {
            loading -> CircularProgressIndicator(color = MMColors.Primary)
            error != null -> Text(error!!, color = MMColors.SemanticDanger)
            property == null -> Text("No rental yet. Create one to start proof.", color = MMColors.TextSecondary)
            else -> {
                val p = property!!
                val documented = RoomProofMetrics.documentedCount(p)
                val total = p.rooms.size
                val next = RoomProofMetrics.nextRoom(p)
                MMProofCard {
                    Text(p.title, style = androidx.compose.material3.MaterialTheme.typography.headlineMedium)
                    Text("${p.city}, ${p.provinceState}", color = MMColors.TextSecondary)
                    Spacer(Modifier.height(8.dp))
                    Text("$documented of $total rooms ready", color = MMColors.TextPrimary)
                    next?.let {
                        Spacer(Modifier.height(8.dp))
                        Text("Next: ${it.name}", color = MMColors.SemanticWarning)
                    }
                }
                Spacer(Modifier.height(16.dp))
                MMButton(
                    text = if (next != null) "Continue room proof" else "Review rooms",
                    onClick = { (next ?: p.rooms.firstOrNull())?.let { onOpenRoom(it.id) } },
                )
                Spacer(Modifier.height(12.dp))
                MMProofCard(
                    modifier = Modifier.clickable {
                        if (hasPro) {
                            onOpenMoveOutProof()
                        } else {
                            onShowPaywall(PaywallReason.MoveOutProof)
                        }
                    },
                ) {
                    Text(
                        "Open move-out proof",
                        style = androidx.compose.material3.MaterialTheme.typography.titleMedium,
                        color = MMColors.TextPrimary,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Re-capture rooms before you leave.",
                        color = MMColors.TextSecondary,
                        fontSize = 14.sp,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        RoomProofMetrics.moveOutStatusLine(p),
                        color = MMColors.TextMuted,
                        fontSize = 13.sp,
                    )
                }
                Spacer(Modifier.height(12.dp))
                MMButton(
                    text = "Add another rental",
                    onClick = {
                        if (!hasPro && propertyCount >= 1) {
                            onShowPaywall(PaywallReason.ExtraProperty)
                        } else {
                            onAddProperty()
                        }
                    },
                    style = MMButtonStyle.Secondary,
                )
            }
        }
    }
}
