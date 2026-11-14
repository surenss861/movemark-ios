package com.surensureshkumar.movemark.features.paywall

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMEyebrowStyle
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.data.subscription.BillingConfig
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import com.surensureshkumar.movemark.features.account.AccountViewModel
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import com.surensureshkumar.movemark.features.subscription.SubscriptionViewModel

/** The paywall is one dark, full-bleed surface on the archival header colour (iOS `ProPaywallView.surface`). */
private val PaywallSurface = MMInk.Hero
private val HeroSecondary = MMInk.HeroSecondary
private val EvidenceRaised = Color.White.copy(alpha = 0.06f)
private val EvidenceStroke = Color.White.copy(alpha = 0.12f)

/**
 * MoveMark Pro, in the locked iOS 1.4 information hierarchy (`ProPaywallView`): the outcome headline, the rental
 * timeline (move-in, during the rental, move-out, if questioned) with the Pro parts marked, the truth lines, the plan
 * picker with Google Play prices, and a pinned footer carrying the price and the one lime "Continue with Pro".
 * Billing off (an internal build without a store key) says subscriptions are coming soon and makes no purchase claim.
 */
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

    BackHandler(enabled = !purchasing) { onClose() }

    ProPaywallContent(
        reason = reason,
        ui = PaywallUi(
            packages = packages, selected = selected, loading = loading, purchasing = purchasing, error = error,
            restoreMessage = restoreMessage, restoreNote = restoreNote, purchaseSuccess = purchaseSuccess,
            packWasBought = packWasBought, isMockMode = viewModel.isMockMode, comingSoon = viewModel.subscriptionsComingSoon,
            canPurchase = activity != null,
        ),
        onClose = onClose,
        onSelect = viewModel::selectPlan,
        onPurchase = { activity?.let { act -> viewModel.purchase(act) { } } },
        onBuyPack = { pack -> activity?.let { viewModel.purchaseReportPack(it, pack) { } } },
        onRestore = { viewModel.restore { onClose() } },
        onRetry = viewModel::loadPlans,
    )
}

/** Everything the paywall shows, as plain values (the debug fixture gallery renders it without a store). */
internal data class PaywallUi(
    val packages: List<PlanPackageUi> = emptyList(),
    val selected: PlanPackageUi? = null,
    val loading: Boolean = false,
    val purchasing: Boolean = false,
    val error: String? = null,
    val restoreMessage: String? = null,
    val restoreNote: String? = null,
    val purchaseSuccess: Boolean = false,
    val packWasBought: Boolean = false,
    val isMockMode: Boolean = false,
    val comingSoon: Boolean = false,
    val canPurchase: Boolean = true,
)

@Composable
internal fun ProPaywallContent(
    reason: PaywallReason,
    ui: PaywallUi,
    onClose: () -> Unit,
    onSelect: (PlanPackageUi) -> Unit,
    onPurchase: () -> Unit,
    onBuyPack: (PlanPackageUi) -> Unit,
    onRestore: () -> Unit,
    onRetry: () -> Unit,
) {
    val context = LocalContext.current
    val packages = ui.packages
    val selected = ui.selected
    val loading = ui.loading
    val purchasing = ui.purchasing
    val error = ui.error
    val restoreMessage = ui.restoreMessage
    val purchaseSuccess = ui.purchaseSuccess
    val restoreNote = ui.restoreNote
    val packWasBought = ui.packWasBought
    // Yearly first, as iOS lists plans.
    val plans = packages.filterNot { it.isReportPack }.sortedByDescending { it.isYearly }
    val reportPack = packages.firstOrNull { it.isReportPack }
    val offersReportPack = reason == PaywallReason.UnlimitedExports
    val isMockMode = ui.isMockMode
    val comingSoon = ui.comingSoon
    val busy = loading || purchasing
    val plansUnavailable = !comingSoon && plans.isEmpty() && !loading && error != null

    MMLightSystemBars(lightNavigationBar = false, lightStatusBar = false)

    Box(Modifier.fillMaxSize().background(PaywallSurface)) {
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onClose, enabled = !purchasing) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White)
                }
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState())
                    .padding(horizontal = MMMetrics.Inset).padding(top = 4.dp, bottom = 24.dp),
            ) {
                // Outcome
                Text("MOVEMARK PRO", style = MMEyebrowStyle, color = HeroSecondary)
                Text(
                    "Protect the full rental timeline.",
                    style = mmFont(30f, FontWeight.SemiBold),
                    color = Color.White,
                    modifier = Modifier.padding(top = 10.dp).semantics { heading() },
                )
                Text(
                    "Keep the record from move-in through move-out, and turn your evidence into reports when you need it.",
                    style = mmFont(16f),
                    color = Color.White.copy(alpha = 0.78f),
                    modifier = Modifier.padding(top = 10.dp),
                )
                reason.contextLine?.let {
                    Text(it, style = mmFont(14f), color = HeroSecondary, modifier = Modifier.padding(top = 10.dp))
                }
                if (isMockMode) {
                    Text(
                        "Test billing mode. No real purchase will be made.",
                        style = mmFont(12.5f),
                        color = HeroSecondary,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }

                if (reportPack != null && showsReportPackSection(offersReportPack, reportPack)) {
                    Spacer(Modifier.height(26.dp))
                    ReportPackSection(
                        pack = reportPack,
                        enabled = !busy && !purchaseSuccess && ui.canPurchase,
                        onBuy = onBuyPack,
                    )
                }

                // The rental timeline: Free keeps every step's record; the move-out report and the evidence packet are Pro.
                Column(Modifier.padding(top = 30.dp).testTag("paywall.timeline")) {
                    TimelineStep(phase = "Move-in", title = "Record every room")
                    TimelineStep(phase = "During rental", title = "Maintenance cases")
                    TimelineStep(phase = "Move-out", title = "Compare before and after", proPart = "Move-out report")
                    TimelineStep(phase = "If questioned", title = "Build the evidence packet", proPart = "Evidence packet", isLast = true)
                }

                // Truth lines
                Box(Modifier.padding(top = 26.dp).fillMaxWidth().height(0.5.dp).background(EvidenceStroke))
                Text(
                    "Free keeps the record. Pro turns it into the reports and evidence packet you’d use.",
                    style = mmFont(15f, FontWeight.Medium),
                    color = Color.White,
                    modifier = Modifier.padding(top = 22.dp),
                )
                Text(
                    "Pro also includes unlimited reports and more than one rental.",
                    style = mmFont(13.5f),
                    color = HeroSecondary,
                    modifier = Modifier.padding(top = 6.dp),
                )

                // Plans
                if (!comingSoon && !plansUnavailable) {
                    Text("CHOOSE YOUR PLAN", style = MMEyebrowStyle, color = HeroSecondary, modifier = Modifier.padding(top = 30.dp, bottom = 12.dp))
                    if (plans.isEmpty()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(color = HeroSecondary, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Getting prices from Google Play…", style = mmFont(13f), color = HeroSecondary)
                        }
                    } else {
                        Column(Modifier.selectableGroup(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            plans.forEach { plan ->
                                PlanRow(
                                    plan = plan,
                                    selected = selected?.id == plan.id,
                                    enabled = !busy && !purchaseSuccess,
                                    onSelect = { onSelect(plan) },
                                )
                            }
                        }
                    }
                    // Below the fold with the plans: the pinned footer carries only the price and the one action.
                    Row(Modifier.padding(top = 22.dp).fillMaxWidth()) {
                        QuietAction(
                            if (purchasing) "Restoring purchases…" else "Restore purchases",
                            Color.White,
                            enabled = !busy,
                            modifier = Modifier.weight(1f),
                            onClick = onRestore,
                        )
                        QuietAction("Not now", HeroSecondary, enabled = !purchasing, modifier = Modifier.weight(1f), onClick = onClose)
                    }
                }

                // Legal
                Text(
                    "MoveMark Pro is an auto-renewing subscription. Prices come from Google Play; Google handles payment and renewal. Manage or cancel in Google Play › Subscriptions.",
                    style = mmFont(12.5f),
                    color = HeroSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 26.dp),
                )
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.Center) {
                    TextButton(onClick = { com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.TERMS_URL) }) {
                        Text("Terms of Use", style = mmFont(13f, FontWeight.Medium), color = Color.White, textDecoration = TextDecoration.Underline)
                    }
                    TextButton(onClick = { com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.PRIVACY_URL) }) {
                        Text("Privacy Policy", style = mmFont(13f, FontWeight.Medium), color = Color.White, textDecoration = TextDecoration.Underline)
                    }
                }
            }

            // Pinned footer: one lime action, the store line, and the way out when plans can't be bought.
            Column(
                Modifier.fillMaxWidth().background(PaywallSurface).navigationBarsPadding()
                    .padding(horizontal = MMMetrics.Inset).padding(top = 12.dp, bottom = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Box(Modifier.fillMaxWidth().height(0.5.dp).background(EvidenceStroke))
                (restoreNote ?: restoreMessage)?.takeIf { !comingSoon }?.let {
                    Text(it, style = mmFont(14f), color = Color.White, textAlign = TextAlign.Center,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                }
                when {
                    comingSoon -> {
                        DarkNotice(BillingConfig.COMING_SOON_TITLE, BillingConfig.COMING_SOON_BODY, tag = "paywall.comingSoon")
                        MMPrimaryButton(title = "Continue on Free", onClick = onClose)
                    }
                    plansUnavailable -> {
                        // What failed sits right above its recovery; said once.
                        DarkNotice("Plans didn’t load", "Try again in a minute. You can keep using Free for now.", tag = "paywall.plansUnavailable")
                        MMPrimaryButton(
                            title = if (loading) "Trying…" else "Try again",
                            isLoading = loading,
                            enabled = !loading,
                            onClick = onRetry,
                        )
                        Row(Modifier.fillMaxWidth()) {
                            QuietAction("Restore purchases", Color.White, enabled = !busy, modifier = Modifier.weight(1f), onClick = onRestore)
                            QuietAction("Continue on Free", HeroSecondary, enabled = !purchasing, modifier = Modifier.weight(1f), onClick = onClose)
                        }
                    }
                    else -> {
                        if (error != null && plans.isNotEmpty()) {
                            Text(error, style = mmFont(14f), color = Color(0xFFFF8A80), textAlign = TextAlign.Center)
                        }
                        selected?.let { plan ->
                            Text(plan.price, style = mmFont(17f, FontWeight.SemiBold), color = Color.White, textAlign = TextAlign.Center)
                        }
                        MMPrimaryButton(
                            title = when {
                                purchaseSuccess -> if (packWasBought) "Report Pack unlocked" else "Pro unlocked"
                                purchasing -> "Starting…"
                                isMockMode -> "Continue with Pro (test)"
                                else -> "Continue with Pro"
                            },
                            isLoading = purchasing && !purchaseSuccess,
                            enabled = !(selected == null || !ui.canPurchase || busy || purchaseSuccess),
                            onClick = onPurchase,
                            modifier = Modifier.testTag("paywall.continue"),
                        )
                        Text("Cancel anytime · Managed by Google Play", style = mmFont(12.5f), color = HeroSecondary, textAlign = TextAlign.Center)
                    }
                }
            }
        }

        if (purchaseSuccess) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
                Column(
                    Modifier.padding(horizontal = MMMetrics.Inset).widthIn(max = 320.dp)
                        .background(PaywallSurface, RoundedCornerShape(20.dp))
                        .border(0.75.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(20.dp))
                        .padding(horizontal = 28.dp, vertical = 26.dp)
                        .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.size(44.dp).background(MMInk.LimeMark, CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.Check, contentDescription = null, tint = MMInk.OnLime, modifier = Modifier.size(20.dp))
                    }
                    Text(if (packWasBought) "Report Pack unlocked" else "Pro unlocked", style = mmFont(19f, FontWeight.SemiBold), color = Color.White)
                    Text(
                        if (packWasBought) "One more move-in report is ready to make."
                        else "Your move-out report and evidence packet are ready when you need them.",
                        style = mmFont(14f), color = HeroSecondary, textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

/** One step of the rental timeline on the dark surface (iOS `MMDarkTimelineStep`). */
@Composable
private fun TimelineStep(phase: String, title: String, proPart: String? = null, isLast: Boolean = false) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).semantics(mergeDescendants = true) {}) {
        Column(Modifier.width(18.dp).fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                Modifier.padding(top = 1.dp).size(18.dp).background(MMInk.Evidence, CircleShape)
                    .border(1.5.dp, Color.White.copy(alpha = 0.45f), CircleShape),
            )
            if (!isLast) Box(Modifier.width(1.5.dp).weight(1f).background(Color.White.copy(alpha = 0.16f)))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.padding(bottom = if (isLast) 0.dp else 18.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(phase.uppercase(), style = MMEyebrowStyle, color = HeroSecondary)
            Text(title, style = mmFont(17f, FontWeight.SemiBold), color = Color.White)
            proPart?.let {
                Row(
                    Modifier.padding(top = 3.dp).semantics { contentDescription = "$it, included with Pro" },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(it, style = mmFont(13.5f, FontWeight.Medium), color = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "Pro",
                        style = mmFont(11.5f, FontWeight.SemiBold),
                        color = MMInk.Evidence,
                        modifier = Modifier.background(Color.White, RoundedCornerShape(50)).padding(horizontal = 7.dp, vertical = 2.dp),
                    )
                }
            }
        }
    }
}

/** A selectable plan: radio, name, Google Play price, one quiet line (iOS `MMDarkPlanRow`), as a native radio. */
@Composable
private fun PlanRow(plan: PlanPackageUi, selected: Boolean, enabled: Boolean, onSelect: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(shape)
            .background(if (selected) Color.White.copy(alpha = 0.09f) else EvidenceRaised, shape)
            .border(if (selected) 1.5.dp else 0.75.dp, if (selected) Color.White.copy(alpha = 0.85f) else EvidenceStroke, shape)
            .selectable(selected = selected, enabled = enabled, role = Role.RadioButton, onClick = onSelect)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .testTag("paywall.plan.${if (plan.isYearly) "yearly" else "monthly"}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(
            selected = selected,
            onClick = null,
            colors = RadioButtonDefaults.colors(selectedColor = Color.White, unselectedColor = Color.White.copy(alpha = 0.4f)),
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(if (plan.isYearly) "Yearly" else "Monthly", style = mmFont(16f, FontWeight.SemiBold), color = Color.White)
            Text(plan.periodLabel, style = mmFont(13f), color = HeroSecondary)
        }
        Spacer(Modifier.width(8.dp))
        Text(plan.price, style = mmFont(16f, FontWeight.SemiBold), color = Color.White)
    }
}

@Composable
private fun QuietAction(title: String, color: Color, enabled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, enabled = enabled, modifier = modifier.heightIn(min = 48.dp)) {
        Text(title, style = mmFont(15f, FontWeight.Medium), color = if (enabled) color else color.copy(alpha = 0.5f), textAlign = TextAlign.Center)
    }
}

/** A notice on the dark surface: what happened, then one quiet line (iOS `plansUnavailableNotice`). */
@Composable
private fun DarkNotice(title: String, body: String, tag: String) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier.fillMaxWidth().background(EvidenceRaised, shape).border(0.75.dp, EvidenceStroke, shape).padding(14.dp)
            .testTag(tag).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(title, style = mmFont(16f, FontWeight.SemiBold), color = Color.White)
        Text(body, style = mmFont(14f), color = HeroSecondary)
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
