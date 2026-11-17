package com.surensureshkumar.movemark.features.paywall

import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import org.junit.Assert.assertEquals
import org.junit.Test

/** iOS 1.4 paywall: a subscription price always names its period. */
class PlanPriceTest {
    @Test
    fun subscriptionPricesNameTheirPeriod() {
        assertEquals("$49.99 / year", planPriceWithPeriod(PlanPackageUi("y", "Yearly", "billed yearly", "$49.99", isYearly = true)))
        assertEquals("$6.99 / month", planPriceWithPeriod(PlanPackageUi("m", "Monthly", "billed monthly", "$6.99", isYearly = false)))
    }

    @Test
    fun aOneTimePackShowsThePriceAlone() {
        assertEquals("$9.99", planPriceWithPeriod(PlanPackageUi("p", "Report Pack", "one report", "$9.99", isYearly = false, isReportPack = true)))
    }
}
