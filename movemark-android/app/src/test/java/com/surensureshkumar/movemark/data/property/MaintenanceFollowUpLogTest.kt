package com.surensureshkumar.movemark.data.property

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.ZoneOffset

class MaintenanceFollowUpLogTest {
    private val oct27 = Instant.parse("2026-10-27T15:00:00Z")

    @Test
    fun firstEntryIsDated() {
        assertEquals("Oct 27: Called landlord", MaintenanceFollowUpLog.appending("  Called landlord ", oct27, null, ZoneOffset.UTC))
        assertEquals("Oct 27: Called landlord", MaintenanceFollowUpLog.appending("Called landlord", oct27, "  ", ZoneOffset.UTC))
    }

    @Test
    fun laterEntriesAreAppendedNeverOverwritten() {
        val first = MaintenanceFollowUpLog.appending("Called landlord", oct27, null, ZoneOffset.UTC)
        val second = MaintenanceFollowUpLog.appending("Plumber booked", Instant.parse("2026-11-02T09:00:00Z"), first, ZoneOffset.UTC)
        assertEquals("Oct 27: Called landlord\n\nNov 2: Plumber booked", second)
    }

    @Test
    fun undatedLegacyTextIsKept() {
        assertEquals(
            "They said next week\n\nOct 27: Still waiting",
            MaintenanceFollowUpLog.appending("Still waiting", oct27, "They said next week", ZoneOffset.UTC),
        )
    }
}
