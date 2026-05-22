package com.surensureshkumar.movemark.features.paywall

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import com.surensureshkumar.movemark.features.account.AccountViewModel
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import com.surensureshkumar.movemark.features.subscription.SubscriptionViewModel

@Composable
fun ProPaywallScreen(
    reason: PaywallReason,
    onClose: () -> Unit,
    viewModel: SubscriptionViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val packages by viewModel.packages.collectAsState()
    val selected by viewModel.selectedPlan.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val purchasing by viewModel.purchasing.collectAsState()
    val error by viewModel.errorMessage.collectAsState()
    val restoreMessage by viewModel.restoreMessage.collectAsState()
    val purchaseSuccess by viewModel.purchaseSuccess.collectAsState()
    val busy = loading || purchasing

    LaunchedEffect(Unit) {
        viewModel.clearMessages()
        viewModel.loadPlans()
    }

    LaunchedEffect(purchaseSuccess) {
        if (purchaseSuccess) {
            kotlinx.coroutines.delay(900)
            viewModel.resetPurchaseSuccess()
            onClose()
        }
    }

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp),
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onClose, enabled = !busy) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = MMColors.TextSecondary)
                }
            }
            Text(reason.headline, color = MMColors.TextPrimary, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(reason.subheadline, color = MMColors.TextSecondary, fontSize = 15.sp)
            Spacer(Modifier.height(6.dp))
            Text(reason.valueProp, color = MMColors.TextMuted, fontSize = 14.sp)
            Spacer(Modifier.height(20.dp))

            when {
                loading && packages.isEmpty() -> {
                    CircularProgressIndicator(color = MMColors.Primary, modifier = Modifier.align(Alignment.CenterHorizontally))
                }
                error != null && packages.isEmpty() -> {
                    MMProofCard {
                        Text("Plans didn't load.", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        Text(error ?: "Try again.", color = MMColors.TextSecondary)
                        Spacer(Modifier.height(12.dp))
                        MMButton(text = "Try again", onClick = viewModel::loadPlans)
                        Spacer(Modifier.height(8.dp))
                        MMButton(text = "Continue on Free", onClick = onClose, style = MMButtonStyle.Secondary)
                    }
                }
                else -> {
                    packages.forEach { plan ->
                        PlanCard(
                            plan = plan,
                            selected = selected?.revenueCatPackage?.identifier == plan.revenueCatPackage.identifier,
                            onSelect = { viewModel.selectPlan(plan) },
                            enabled = !busy,
                        )
                        Spacer(Modifier.height(10.dp))
                    }
                    error?.let {
                        Text(it, color = MMColors.SemanticDanger, fontSize = 14.sp)
                        Spacer(Modifier.height(8.dp))
                    }
                    restoreMessage?.let {
                        Text(it, color = MMColors.Primary, fontSize = 14.sp)
                        Spacer(Modifier.height(8.dp))
                    }
                    MMButton(
                        text = if (purchasing) "Starting Pro…" else "Start Pro",
                        onClick = {
                            activity?.let { act ->
                                viewModel.purchase(act) { }
                            }
                        },
                        enabled = selected != null && activity != null && !busy,
                        loading = purchasing,
                    )
                    Spacer(Modifier.height(10.dp))
                    MMButton(
                        text = "Restore purchases",
                        onClick = { viewModel.restore { onClose() } },
                        style = MMButtonStyle.Secondary,
                        enabled = !busy,
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
            Row(Modifier.fillMaxWidth()) {
                TextButton(onClick = {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AccountViewModel.TERMS_URL)))
                }) { Text("Terms of Use", color = MMColors.TextSecondary) }
                TextButton(onClick = {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AccountViewModel.PRIVACY_URL)))
                }) { Text("Privacy Policy", color = MMColors.TextSecondary) }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun PlanCard(
    plan: PlanPackageUi,
    selected: Boolean,
    onSelect: () -> Unit,
    enabled: Boolean,
) {
    val border = if (selected) MMColors.Primary else MMColors.CardStroke
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onSelect),
        shape = RoundedCornerShape(MMSpacing.CornerRadius.dp),
        color = MMColors.Card,
        border = BorderStroke(if (selected) 2.dp else 1.dp, border),
    ) {
        Row(
            Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(plan.title, color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Text(plan.periodLabel, color = MMColors.TextSecondary, fontSize = 13.sp)
            }
            Text(plan.price, color = MMColors.Primary, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            if (selected) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = MMColors.Primary,
                    modifier = Modifier.padding(start = 8.dp),
                )
            }
        }
    }
}
