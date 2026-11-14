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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.filled.Description
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
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
import androidx.compose.ui.platform.testTag
import com.surensureshkumar.movemark.data.subscription.BillingConfig
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import com.surensureshkumar.movemark.features.account.AccountViewModel
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
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
    val restoreNote by viewModel.restoreNote.collectAsState()
    val packWasBought by viewModel.purchaseWasReportPack.collectAsState()
    val plans = packages.filterNot { it.isReportPack }
    val reportPack = packages.firstOrNull { it.isReportPack }
    // Came for one report: the Report Pack is the first answer, before the Pro story (iOS prefersReportPackFirst).
    val offersReportPack = reason == PaywallReason.UnlimitedExports
    val isMockMode = viewModel.isMockMode
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
            if (isMockMode) {
                Spacer(Modifier.height(8.dp))
                Text(
                    "Test billing mode. No real purchase will be made.",
                    color = MMColors.TextMuted,
                    fontSize = 12.sp,
                )
            }
            if (purchaseSuccess) {
                Spacer(Modifier.height(12.dp))
                Text(
                    if (packWasBought) "Report Pack unlocked" else "Pro unlocked",
                    color = MMColors.Primary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
            }
            if (reportPack != null && showsReportPackSection(offersReportPack, reportPack)) {
                Spacer(Modifier.height(20.dp))
                ReportPackSection(
                    pack = reportPack,
                    enabled = !busy && !purchaseSuccess && activity != null,
                    onBuy = { pack -> activity?.let { viewModel.purchaseReportPack(it, pack) { } } },
                )
            }
            Spacer(Modifier.height(16.dp))
            MMProofCard {
                Text("MoveMark Pro includes", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(4.dp))
                Text(MoveMarkGrowthCopy.PAYWALL_SUPPORT_LINE, color = MMColors.TextSecondary, fontSize = 13.sp)
                Spacer(Modifier.height(12.dp))
                MoveMarkGrowthCopy.PAYWALL_BENEFITS.forEach { (title, subtitle) ->
                    Row(Modifier.fillMaxWidth()) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = com.surensureshkumar.movemark.core.design.MMInk.LimeMark,
                            modifier = Modifier.padding(end = 8.dp),
                        )
                        Column {
                            Text(title, color = MMColors.TextPrimary, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                            Text(subtitle, color = MMColors.TextSecondary, fontSize = 13.sp)
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                }
            }
            Spacer(Modifier.height(16.dp))

            when {
                viewModel.subscriptionsComingSoon -> {
                    MMProofCard(modifier = Modifier.testTag("paywall.comingSoon")) {
                        Text("Subscriptions coming soon", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        Text(BillingConfig.COMING_SOON, color = MMColors.TextSecondary)
                        Spacer(Modifier.height(12.dp))
                        MMButton(text = "Continue on Free", onClick = onClose, style = MMButtonStyle.Secondary)
                    }
                }
                loading && packages.isEmpty() -> {
                    CircularProgressIndicator(color = MMColors.Primary, modifier = Modifier.align(Alignment.CenterHorizontally))
                }
                error != null && packages.isEmpty() -> {
                    MMProofCard {
                        Text("Plans didn't load.", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        Text(error ?: "Try again.", color = MMColors.TextSecondary)
                        Spacer(Modifier.height(12.dp))
                        MMButton(text = "Try again", onClick = viewModel::loadPlans, style = MMButtonStyle.Action)
                        Spacer(Modifier.height(8.dp))
                        MMButton(text = "Continue on Free", onClick = onClose, style = MMButtonStyle.Secondary)
                    }
                }
                else -> {
                    plans.forEach { plan ->
                        PlanCard(
                            plan = plan,
                            selected = selected?.id == plan.id,
                            onSelect = { viewModel.selectPlan(plan) },
                            enabled = !busy,
                        )
                        Spacer(Modifier.height(10.dp))
                    }
                    error?.let {
                        Text(it, color = MMColors.SemanticDanger, fontSize = 14.sp)
                        Spacer(Modifier.height(8.dp))
                    }
                    (restoreNote ?: restoreMessage)?.let {
                        Text(it, color = MMColors.Primary, fontSize = 14.sp)
                        Spacer(Modifier.height(8.dp))
                    }
                    MMButton(
                        text = when {
                            purchasing -> if (isMockMode) "Unlocking Pro…" else "Starting Pro…"
                            isMockMode -> "Unlock Pro for testing"
                            else -> "Start Pro"
                        },
                        onClick = {
                            activity?.let { act ->
                                viewModel.purchase(act) { }
                            }
                        },
                        enabled = selected != null && activity != null && !busy,
                        loading = purchasing,
                        style = MMButtonStyle.Action,
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
                    com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.TERMS_URL)
                }) { Text("Terms of Use", color = MMColors.TextSecondary) }
                TextButton(onClick = {
                    com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.PRIVACY_URL)
                }) { Text("Privacy Policy", color = MMColors.TextSecondary) }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

/**
 * The Report Pack section appears only when the offering actually sells one (iOS 4c7eedd): no "One report only" label
 * and no "isn't available" line for a product that doesn't exist.
 */
internal fun showsReportPackSection(offersReportPack: Boolean, reportPack: PlanPackageUi?): Boolean =
    offersReportPack && reportPack != null

/** One report, no subscription — offered first when the renter only needs a single move-in report. */
@Composable
private fun ReportPackSection(pack: PlanPackageUi?, enabled: Boolean, onBuy: (PlanPackageUi) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("ONE REPORT ONLY", color = MMColors.TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.8.sp)
        if (pack == null) {
            Text("Report Pack isn’t available right now. Pro still unlocks unlimited reports.", color = MMColors.TextSecondary, fontSize = 13.sp)
            return@Column
        }
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 64.dp)
                .clickable(enabled = enabled, role = Role.Button) { onBuy(pack) }
                .semantics(mergeDescendants = true) {
                    contentDescription = "Buy Report Pack, one move-in report, no subscription, ${pack.price}"
                },
            shape = RoundedCornerShape(14.dp),
            color = MMColors.CardRaised,
            border = BorderStroke(0.75.dp, MMColors.CardStroke),
        ) {
            val large = LocalDensity.current.fontScale >= 1.5f
            val copy: @Composable () -> Unit = {
                Column {
                    Text("Report Pack", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    Text("One move-in report · no subscription", color = MMColors.TextSecondary, fontSize = 13.sp)
                }
            }
            val price: @Composable () -> Unit = { Text(pack.price, color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 16.sp) }
            if (large) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { copy(); price() }
            } else {
                Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Description, contentDescription = null, tint = MMColors.TextPrimary, modifier = Modifier.padding(end = 12.dp))
                    Box(Modifier.weight(1f)) { copy() }
                    price()
                }
            }
        }
        Text("The move-out report and evidence packet stay on Pro.", color = MMColors.TextSecondary, fontSize = 12.5.sp)
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
