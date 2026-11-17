package com.surensureshkumar.movemark.features.paywall

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** iOS 1.4 `ProPaywallView` parity: loading placeholders, footer notices, plan marker, recorded move-in step. */
@RunWith(AndroidJUnit4::class)
class PaywallLoadingAndNoticesTest {
    @get:Rule val compose = createComposeRule()

    private val plans = listOf(
        PlanPackageUi("yearly", "MoveMark Pro Yearly", "Billed yearly", "$49.99", isYearly = true),
        PlanPackageUi("monthly", "MoveMark Pro Monthly", "Billed monthly", "$7.99", isYearly = false),
    )

    private fun show(ui: PaywallUi) {
        compose.setContent {
            ProPaywallContent(
                reason = PaywallReason.ExtraProperty,
                ui = ui,
                onClose = {}, onSelect = {}, onPurchase = {}, onBuyPack = {}, onRestore = {}, onRetry = {},
            )
        }
    }

    @Test
    fun loadingKeepsTwoPlaceholderRowsAndNoPrices() {
        show(PaywallUi(loading = true))
        compose.onNodeWithTag("paywall.plan.placeholders").assertExists()
        compose.onNodeWithText("Getting prices from Google Play…").assertExists()
        compose.onNodeWithTag("paywall.plan.yearly").assertDoesNotExist()
        compose.onNodeWithText("Yearly").assertDoesNotExist()
    }

    @Test
    fun loadedPlansReplaceThePlaceholders() {
        show(PaywallUi(packages = plans, selected = plans.first()))
        compose.onNodeWithTag("paywall.plan.placeholders").assertDoesNotExist()
        compose.onNodeWithTag("paywall.plan.yearly").assertExists()
        // The price shows in the row and again in the footer above the action.
        compose.onAllNodesWithText("$49.99 / year").assertCountEquals(2)
    }

    @Test
    fun planMarkerIsCheckForTheChosenPlanAndCircleForTheOther() {
        show(PaywallUi(packages = plans, selected = plans.first()))
        compose.onNodeWithTag("paywall.plan.marker.selected", useUnmergedTree = true).assertExists()
        compose.onNodeWithTag("paywall.plan.marker.unselected", useUnmergedTree = true).assertExists()
    }

    @Test
    fun purchaseErrorIsANoticeInTheFooter() {
        show(PaywallUi(packages = plans, selected = plans.first(), error = "The purchase didn’t go through."))
        compose.onNodeWithTag("paywall.notice.error").assertExists()
        compose.onNodeWithText("The purchase didn’t go through.").assertExists()
        compose.onNodeWithTag("paywall.notice.restore").assertDoesNotExist()
    }

    @Test
    fun restoreOutcomeIsAnInfoNotice() {
        show(PaywallUi(packages = plans, selected = plans.first(), restoreNote = "No purchases to restore."))
        compose.onNodeWithTag("paywall.notice.restore").assertExists()
        compose.onNodeWithText("No purchases to restore.").assertExists()
        compose.onNodeWithTag("paywall.notice.error").assertDoesNotExist()
    }

    @Test
    fun plansUnavailableShowsItsOwnNoticeNotTheErrorNotice() {
        show(PaywallUi(error = "Plans didn't load."))
        compose.onNodeWithTag("paywall.plansUnavailable").assertExists()
        compose.onNodeWithTag("paywall.notice.error").assertDoesNotExist()
    }

    @Test
    fun moveInStepReadsNeutrallyUnlessRecorded() {
        show(PaywallUi(packages = plans, selected = plans.first()))
        compose.onNodeWithText("Record every room").assertExists()
        compose.onNodeWithTag("paywall.timeline.recorded", useUnmergedTree = true).assertDoesNotExist()
    }

    @Test
    fun moveInStepShowsRecordedWhenThePresenterKnows() {
        show(PaywallUi(packages = plans, selected = plans.first(), moveInRecorded = true))
        compose.onNodeWithText("Recorded").assertExists()
        compose.onNodeWithText("Record every room").assertDoesNotExist()
        compose.onNodeWithTag("paywall.timeline.recorded", useUnmergedTree = true).assertExists()
    }
}
