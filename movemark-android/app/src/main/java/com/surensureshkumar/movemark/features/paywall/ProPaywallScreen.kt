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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMEyebrowStyle
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.data.subscription.BillingConfig
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import com.surensureshkumar.movemark.features.account.AccountViewModel
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import com.surensureshkumar.movemark.features.subscription.SubscriptionViewModel

/** The paywall is one light page (owner, 2026-11-18): soft off-white, ink headings, white hairline cards. */
private val PaywallSurface = MMInk.Sheet
private val Ink = MMInk.Text
private val Quiet = MMInk.Secondary

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
    /**
     * Whether the current rental already has move-in photos (iOS `moveInRecorded`). The presenter passes what it
     * already knows; the paywall loads nothing for it, and unknown (the default) reads neutrally, never "Recorded".
     */
    moveInRecorded: Boolean = false,
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
            canPurchase = activity != null, moveInRecorded = moveInRecorded,
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
    val moveInRecorded: Boolean = false,
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

    MMLightSystemBars(lightNavigationBar = true, lightStatusBar = true)

    Box(Modifier.fillMaxSize().background(PaywallSurface)) {
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onClose, enabled = !purchasing) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = Ink)
                }
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState())
                    .padding(horizontal = MMMetrics.Inset).padding(top = 4.dp, bottom = 24.dp),
            ) {
                // Outcome
                Text("MOVEMARK PRO", style = MMEyebrowStyle, color = Quiet)
                Text(
                    "Protect the full rental timeline.",
                    style = mmFont(30f, FontWeight.SemiBold),
                    color = Ink,
                    modifier = Modifier.padding(top = 10.dp).semantics { heading() },
                )
                Text(
                    "Keep the record from move-in through move-out, and turn your evidence into reports when you need it.",
                    style = mmFont(16f),
                    color = Quiet,
                    modifier = Modifier.padding(top = 10.dp),
                )
                reason.contextLine?.let {
                    Text(it, style = mmFont(14f), color = Quiet, modifier = Modifier.padding(top = 10.dp))
                }
                if (isMockMode) {
                    Text(
                        "Test billing mode. No real purchase will be made.",
                        style = mmFont(12.5f),
                        color = Quiet,
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
                    TimelineStep(
                        phase = "Move-in",
                        title = if (ui.moveInRecorded) "Recorded" else "Record every room",
                        isRecorded = ui.moveInRecorded,
                    )
                    TimelineStep(phase = "During rental", title = "Maintenance cases")
                    TimelineStep(phase = "Move-out", title = "Compare before and after", proPart = "Move-out report")
                    TimelineStep(phase = "If questioned", title = "Build the evidence packet", proPart = "Evidence packet", isLast = true)
                }

                // Truth lines
                Box(Modifier.padding(top = 26.dp).fillMaxWidth().height(0.75.dp).background(MMInk.Separator))
                Text(
                    "Free keeps the record. Pro turns it into the reports and evidence packet you’d use.",
                    style = mmFont(15f, FontWeight.Medium),
                    color = Ink,
                    modifier = Modifier.padding(top = 22.dp),
                )
                Text(
                    "Pro also includes unlimited reports and more than one rental.",
                    style = mmFont(13.5f),
                    color = Quiet,
                    modifier = Modifier.padding(top = 6.dp),
                )

                // Plans
                if (!comingSoon && !plansUnavailable) {
                    Text("CHOOSE YOUR PLAN", style = MMEyebrowStyle, color = Quiet, modifier = Modifier.padding(top = 30.dp, bottom = 12.dp))
                    if (plans.isEmpty()) {
                        // Loading keeps the plan layout (iOS redacted rows); prices only ever come from Google Play.
                        // Hidden from TalkBack (iOS accessibilityHidden); the progress line below speaks for it.
                        Box(Modifier.testTag("paywall.plan.placeholders")) {
                            Column(Modifier.clearAndSetSemantics {}, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                PlanRowPlaceholder(titleWidth = 52.dp, detailWidth = 84.dp, priceWidth = 96.dp)
                                PlanRowPlaceholder(titleWidth = 64.dp, detailWidth = 96.dp, priceWidth = 88.dp)
                            }
                        }
                        Row(
                            Modifier.padding(top = 12.dp).semantics(mergeDescendants = true) {},
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CircularProgressIndicator(color = Quiet, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Getting prices from Google Play…", style = mmFont(13f), color = Quiet)
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
                            Ink,
                            enabled = !busy,
                            modifier = Modifier.weight(1f),
                            onClick = onRestore,
                        )
                        QuietAction("Not now", Quiet, enabled = !purchasing, modifier = Modifier.weight(1f), onClick = onClose)
                    }
                }

                // Legal (not in billing-off: nothing can be bought, so no subscription terms are claimed)
                if (!comingSoon) Text(
                    "MoveMark Pro is an auto-renewing subscription. Prices come from Google Play; Google handles payment and renewal. Manage or cancel in Google Play › Subscriptions.",
                    style = mmFont(12.5f),
                    color = Quiet,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 26.dp),
                )
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.Center) {
                    TextButton(onClick = { com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.TERMS_URL) }) {
                        Text("Terms of Use", style = mmFont(13f, FontWeight.Medium), color = Ink, textDecoration = TextDecoration.Underline)
                    }
                    TextButton(onClick = { com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.PRIVACY_URL) }) {
                        Text("Privacy Policy", style = mmFont(13f, FontWeight.Medium), color = Ink, textDecoration = TextDecoration.Underline)
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
                Box(Modifier.fillMaxWidth().height(0.75.dp).background(MMInk.Separator))
                // iOS purchaseFooter: the purchase error, then the restore outcome, as light notices.
                if (!comingSoon && !plansUnavailable && error != null && plans.isNotEmpty()) {
                    PaywallNotice(error, PaywallNoticeTone.Error, tag = "paywall.notice.error")
                }
                (restoreNote ?: restoreMessage)?.takeIf { !comingSoon }?.let {
                    PaywallNotice(it, PaywallNoticeTone.Info, tag = "paywall.notice.restore")
                }
                when {
                    comingSoon -> {
                        PaywallStateNotice(BillingConfig.COMING_SOON_TITLE, BillingConfig.COMING_SOON_BODY, tag = "paywall.comingSoon")
                        MMPrimaryButton(title = "Continue on Free", onClick = onClose)
                    }
                    plansUnavailable -> {
                        // What failed sits right above its recovery; said once.
                        PaywallStateNotice("Plans didn’t load", "Try again in a minute. You can keep using Free for now.", tag = "paywall.plansUnavailable")
                        MMPrimaryButton(
                            title = if (loading) "Trying…" else "Try again",
                            isLoading = loading,
                            enabled = !loading,
                            onClick = onRetry,
                        )
                        Row(Modifier.fillMaxWidth()) {
                            QuietAction("Restore purchases", Ink, enabled = !busy, modifier = Modifier.weight(1f), onClick = onRestore)
                            QuietAction("Continue on Free", Quiet, enabled = !purchasing, modifier = Modifier.weight(1f), onClick = onClose)
                        }
                    }
                    else -> {
                        selected?.let { plan ->
                            Text(planPriceWithPeriod(plan), style = mmFont(17f, FontWeight.SemiBold), color = Ink, textAlign = TextAlign.Center)
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
                        Text("Cancel anytime · Managed by Google Play", style = mmFont(12.5f), color = Quiet, textAlign = TextAlign.Center)
                    }
                }
            }
        }

        if (purchaseSuccess) {
            // A white card over a soft scrim (the page stays light behind it).
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.32f)), contentAlignment = Alignment.Center) {
                Column(
                    Modifier.padding(horizontal = MMMetrics.Inset).widthIn(max = 320.dp)
                        .background(MMInk.Card, RoundedCornerShape(MMMetrics.SheetRadius))
                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.SheetRadius))
                        .padding(horizontal = 28.dp, vertical = 26.dp)
                        .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.size(44.dp).background(Ink, CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.Check, contentDescription = null, tint = MMInk.Card, modifier = Modifier.size(20.dp))
                    }
                    Text(if (packWasBought) "Report Pack unlocked" else "Pro unlocked", style = mmFont(19f, FontWeight.SemiBold), color = Ink, textAlign = TextAlign.Center)
                    Text(
                        if (packWasBought) "One more move-in report is ready to make."
                        else "Your move-out report and evidence packet are ready when you need them.",
                        style = mmFont(14f), color = Quiet, textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

/** One step of the rental timeline on the light page (iOS `MMDarkTimelineStep`, re-inked for the light system). */
@Composable
private fun TimelineStep(
    phase: String,
    title: String,
    proPart: String? = null,
    isRecorded: Boolean = false,
    isLast: Boolean = false,
) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).semantics(mergeDescendants = true) {}) {
        Column(Modifier.width(18.dp).fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally) {
            // iOS: a lime mark with an ink check once recorded (progress); otherwise a hollow white dot.
            Box(
                Modifier.padding(top = 1.dp).size(18.dp)
                    .background(if (isRecorded) MMInk.LimeMark else MMInk.Card, CircleShape)
                    .then(if (isRecorded) Modifier else Modifier.border(1.5.dp, Quiet.copy(alpha = 0.55f), CircleShape))
                    .then(if (isRecorded) Modifier.testTag("paywall.timeline.recorded") else Modifier),
                contentAlignment = Alignment.Center,
            ) {
                if (isRecorded) {
                    Icon(Icons.Filled.Check, contentDescription = null, tint = MMInk.OnLime, modifier = Modifier.size(11.dp))
                }
            }
            if (!isLast) Box(Modifier.width(1.5.dp).weight(1f).background(MMInk.Separator))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.padding(bottom = if (isLast) 0.dp else 18.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(phase.uppercase(), style = MMEyebrowStyle, color = Quiet)
            Text(title, style = mmFont(17f, FontWeight.SemiBold), color = Ink)
            proPart?.let {
                Row(
                    Modifier.padding(top = 3.dp).semantics { contentDescription = "$it, included with Pro" },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(it, style = mmFont(13.5f, FontWeight.Medium), color = Ink)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "Pro",
                        style = mmFont(11.5f, FontWeight.SemiBold),
                        color = Ink,
                        modifier = Modifier.border(1.dp, MMInk.CardStroke, RoundedCornerShape(50)).padding(horizontal = 7.dp, vertical = 2.dp),
                    )
                }
            }
        }
    }
}

/** A selectable plan: radio, name, Google Play price, one quiet line (iOS `MMDarkPlanRow`), as a native radio. */
@Composable
private fun PlanRow(plan: PlanPackageUi, selected: Boolean, enabled: Boolean, onSelect: () -> Unit) {
    val shape = RoundedCornerShape(MMMetrics.GroupRadius)
    Row(
        Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(shape)
            .background(MMInk.Card, shape)
            .border(if (selected) 1.5.dp else 0.75.dp, if (selected) Ink else MMInk.CardStroke, shape)
            .selectable(selected = selected, enabled = enabled, role = Role.RadioButton, onClick = onSelect)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .testTag("paywall.plan.${if (plan.isYearly) "yearly" else "monthly"}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PlanMarker(selected)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(if (plan.isYearly) "Yearly" else "Monthly", style = mmFont(16f, FontWeight.SemiBold), color = Ink)
            Text(plan.periodLabel, style = mmFont(13f), color = Quiet)
        }
        Spacer(Modifier.width(8.dp))
        Text(planPriceWithPeriod(plan), style = mmFont(16f, FontWeight.SemiBold), color = Ink)
    }
}

/** iOS "$49.99 / year": a subscription price always says what period it buys; a one-time pack shows the price alone. */
internal fun planPriceWithPeriod(plan: com.surensureshkumar.movemark.data.subscription.PlanPackageUi): String = when {
    plan.isReportPack -> plan.price
    plan.isYearly -> "${plan.price} / year"
    else -> "${plan.price} / month"
}

/** iOS `MMDarkPlanRow` marker: `checkmark.circle.fill` when chosen, a plain `circle` otherwise. */
@Composable
private fun PlanMarker(selected: Boolean) {
    Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
        if (selected) {
            Icon(
                Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = Ink,
                modifier = Modifier.size(24.dp).testTag("paywall.plan.marker.selected"),
            )
        } else {
            Box(
                Modifier.size(20.dp).border(1.5.dp, Quiet.copy(alpha = 0.55f), CircleShape)
                    .testTag("paywall.plan.marker.unselected"),
            )
        }
    }
}

/** A plan row's shape while prices load (iOS `.redacted(reason: .placeholder)`): same frame, quiet bars, no claim. */
@Composable
private fun PlanRowPlaceholder(titleWidth: Dp, detailWidth: Dp, priceWidth: Dp) {
    val shape = RoundedCornerShape(MMMetrics.GroupRadius)
    val bar = MMInk.Field
    Row(
        Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(shape)
            .background(MMInk.Card, shape)
            .border(0.75.dp, MMInk.CardStroke, shape)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(20.dp).background(bar, CircleShape))
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.width(titleWidth).height(14.dp).background(bar, RoundedCornerShape(4.dp)))
            Box(Modifier.width(detailWidth).height(11.dp).background(bar, RoundedCornerShape(4.dp)))
        }
        Spacer(Modifier.width(8.dp))
        Box(Modifier.width(priceWidth).height(14.dp).background(bar, RoundedCornerShape(4.dp)))
    }
}

internal enum class PaywallNoticeTone { Error, Info }

/** A calm light notice (the system `MMNotice`): a tone mark, then the message. Tagged and announced politely. */
@Composable
private fun PaywallNotice(message: String, tone: PaywallNoticeTone, tag: String) {
    MMNotice(
        message = message,
        tone = if (tone == PaywallNoticeTone.Error) MMNoticeTone.Error else MMNoticeTone.Info,
        modifier = Modifier
            .testTag(tag)
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
    )
}

@Composable
private fun QuietAction(title: String, color: Color, enabled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, enabled = enabled, modifier = modifier.heightIn(min = 48.dp)) {
        Text(title, style = mmFont(15f, FontWeight.Medium), color = if (enabled) color else color.copy(alpha = 0.5f), textAlign = TextAlign.Center)
    }
}

/** A white hairline card: what happened, then one quiet line (iOS `plansUnavailableNotice`). */
@Composable
private fun PaywallStateNotice(title: String, body: String, tag: String) {
    val shape = RoundedCornerShape(MMMetrics.GroupRadius)
    Column(
        Modifier.fillMaxWidth().background(MMInk.Card, shape).border(0.75.dp, MMInk.CardStroke, shape).padding(14.dp)
            .testTag(tag).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(title, style = mmFont(16f, FontWeight.SemiBold), color = Ink)
        Text(body, style = mmFont(14f), color = Quiet)
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
        Text("ONE REPORT ONLY", style = MMEyebrowStyle, color = Quiet)
        if (pack == null) {
            Text("Report Pack isn’t available right now. Pro still unlocks unlimited reports.", style = mmFont(13f), color = Quiet)
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
            shape = RoundedCornerShape(MMMetrics.GroupRadius),
            color = MMInk.Card,
            border = BorderStroke(0.75.dp, MMInk.CardStroke),
        ) {
            val large = LocalDensity.current.fontScale >= 1.5f
            val copy: @Composable () -> Unit = {
                Column {
                    Text("Report Pack", style = mmFont(16f, FontWeight.SemiBold), color = Ink)
                    Text("One move-in report · no subscription", style = mmFont(13f), color = Quiet)
                }
            }
            val price: @Composable () -> Unit = { Text(pack.price, style = mmFont(16f, FontWeight.SemiBold), color = Ink) }
            if (large) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { copy(); price() }
            } else {
                Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Description, contentDescription = null, tint = Ink, modifier = Modifier.padding(end = 12.dp))
                    Box(Modifier.weight(1f)) { copy() }
                    price()
                }
            }
        }
        Text("The move-out report and evidence packet stay on Pro.", style = mmFont(12.5f), color = Quiet)
    }
}
