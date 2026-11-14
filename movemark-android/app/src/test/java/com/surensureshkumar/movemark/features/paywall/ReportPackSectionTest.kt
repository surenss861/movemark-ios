package com.surensureshkumar.movemark.features.paywall

import com.surensureshkumar.movemark.data.subscription.PlanPackageUi
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS 4c7eedd parity: no Report Pack copy at all when the offering sells no Report Pack. */
class ReportPackSectionTest {
    private val pack = PlanPackageUi("report_pack", "Report Pack", "one report", "$9.99", isYearly = false, isReportPack = true)

    @Test fun hiddenWhenNoReportPackIsOnSale() {
        assertFalse(showsReportPackSection(offersReportPack = true, reportPack = null))
    }

    @Test fun shownOnlyWhenOfferedAndOnSale() {
        assertTrue(showsReportPackSection(offersReportPack = true, reportPack = pack))
        assertFalse(showsReportPackSection(offersReportPack = false, reportPack = pack))
    }
}
