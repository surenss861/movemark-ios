package com.surensureshkumar.movemark.features.maintenance

import com.surensureshkumar.movemark.data.models.MaintenanceIssueRow
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.property.MaintenanceFollowUpEntry
import com.surensureshkumar.movemark.data.property.MaintenanceFollowUpLog
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.ZoneOffset
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

class MaintenanceCaseTest {
    private val utc = ZoneOffset.UTC
    private val us = Locale.US
    private lateinit var savedZone: TimeZone
    private lateinit var savedLocale: Locale

    @Before fun pinZoneAndLocale() {
        savedZone = TimeZone.getDefault()
        savedLocale = Locale.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
        Locale.setDefault(Locale.US)
    }

    @After fun restore() {
        TimeZone.setDefault(savedZone)
        Locale.setDefault(savedLocale)
    }

    // region Categories

    @Test
    fun categoriesAreTheIosSetInOrderWithIosRawValues() {
        assertEquals(
            listOf("Water damage", "Heating / cooling", "Pest", "Appliance", "Structural", "Plumbing", "Electrical", "Other"),
            MaintenanceCategory.entries.map { it.raw },
        )
        assertEquals(MaintenanceCategory.Other, MaintenanceCategory.Default)
    }

    @Test
    fun iosRawValuesReadBackAsTheirCategory() {
        MaintenanceCategory.entries.forEach {
            assertEquals(it, MaintenanceCategory.fromStored(it.raw))
            assertEquals(it.raw, MaintenanceCategory.label(it.raw))
        }
        assertEquals(MaintenanceCategory.HeatingCooling, MaintenanceCategory.fromStored("  heating / COOLING "))
    }

    @Test
    fun legacyAndroidValuesReadAsTheMatchingCategory() {
        assertEquals("Heating / cooling", MaintenanceCategory.label("HVAC"))
        assertEquals("Pest", MaintenanceCategory.label("Pests"))
        assertEquals("Other", MaintenanceCategory.label("General"))
        assertEquals("Plumbing", MaintenanceCategory.label("Plumbing"))
        assertEquals("Appliance", MaintenanceCategory.label("Appliance"))
    }

    @Test
    fun missingOrUnknownCategoriesReadSensibly() {
        assertEquals("Other", MaintenanceCategory.label(null))
        assertEquals("Other", MaintenanceCategory.label("   "))
        assertEquals("Roof", MaintenanceCategory.label(" Roof "))
        assertNull(MaintenanceCategory.fromStored("Roof"))
    }

    // endregion

    // region Status

    @Test
    fun statusMapsServerValuesLikeIos() {
        assertEquals(MaintenanceCaseStatus.Open, MaintenanceCaseStatus.fromStored("open"))
        assertEquals(MaintenanceCaseStatus.FollowUp, MaintenanceCaseStatus.fromStored("follow_up"))
        assertEquals(MaintenanceCaseStatus.Resolved, MaintenanceCaseStatus.fromStored("resolved"))
        // Tolerant of casing / the label spelling; anything else is open.
        assertEquals(MaintenanceCaseStatus.FollowUp, MaintenanceCaseStatus.fromStored("Follow-up"))
        assertEquals(MaintenanceCaseStatus.Resolved, MaintenanceCaseStatus.fromStored("Resolved"))
        assertEquals(MaintenanceCaseStatus.Open, MaintenanceCaseStatus.fromStored(null))
        assertEquals(MaintenanceCaseStatus.Open, MaintenanceCaseStatus.fromStored("in_progress"))
        assertEquals(listOf("Open", "Follow-up", "Resolved"), MaintenanceCaseStatus.entries.map { it.label })
        assertTrue(MaintenanceCaseStatus.Resolved.isResolved)
        assertFalse(MaintenanceCaseStatus.FollowUp.isResolved)
    }

    // endregion

    // region Dates

    @Test
    fun caseDatesReadTimestampsAndDays() {
        assertEquals("Oct 26 · 8:42 AM", MaintenanceCaseDate.text("2026-10-26T08:42:00Z", zone = utc, locale = us))
        assertEquals("Oct 26 · 8:42 AM", MaintenanceCaseDate.text("2026-10-26T08:42:00.123456+00:00", zone = utc, locale = us))
        assertEquals("Oct 26 · 8:42 AM", MaintenanceCaseDate.text("2026-10-26 08:42:00+00:00", zone = utc, locale = us))
        assertEquals("Oct 27", MaintenanceCaseDate.text("2026-10-27", zone = utc, locale = us))
        assertEquals("Oct 26", MaintenanceCaseDate.text("2026-10-26T08:42:00Z", time = false, zone = utc, locale = us))
        assertNull(MaintenanceCaseDate.text("", zone = utc, locale = us))
        assertNull(MaintenanceCaseDate.text("not a date", zone = utc, locale = us))
    }

    @Test
    fun logLineIsCategoryAndReportedDay() {
        val record = MaintenanceRecord(UUID.randomUUID(), "Fan", "HVAC", "", "open", null, 0, "2026-10-24T12:00:00Z")
        assertEquals("Heating / cooling · Reported Oct 24", maintenanceCaseLine(record))
        assertEquals("Other", maintenanceCaseLine(record.copy(category = "General", createdAt = null)))
    }

    @Test
    fun photoCountCopy() {
        assertEquals("No photos", maintenancePhotoCountText(0))
        assertEquals("1 photo", maintenancePhotoCountText(1))
        assertEquals("4 photos", maintenancePhotoCountText(4))
        assertEquals("1 photo recorded", maintenancePhotosRecordedText(1))
        assertEquals("3 photos recorded", maintenancePhotosRecordedText(3))
    }

    // endregion

    // region Follow-up log

    @Test
    fun followUpEntriesSplitOnBlankLinesAndKeepUndatedParagraphsWithTheirEntry() {
        assertEquals(emptyList<MaintenanceFollowUpEntry>(), MaintenanceFollowUpLog.entries("  "))
        assertEquals(
            listOf(
                MaintenanceFollowUpEntry("Oct 23", "Called\n\nThey said Friday"),
                MaintenanceFollowUpEntry("Oct 25", "Plumber booked"),
            ),
            MaintenanceFollowUpLog.entries("Oct 23: Called\n\nThey said Friday\n\nOct 25: Plumber booked"),
        )
        assertEquals(listOf(MaintenanceFollowUpEntry(null, "Fixed on Oct 2.")), MaintenanceFollowUpLog.entries("Fixed on Oct 2."))
    }

    // endregion

    // region Timeline

    private fun case(
        status: String = "open",
        discovered: String? = null,
        reported: String? = null,
        method: String? = null,
        response: String? = null,
        followUp: String? = null,
        updated: String? = null,
        created: String? = null,
    ) = MaintenanceCase(
        id = UUID.randomUUID(), title = "Leak", category = "Plumbing", details = "", status = status,
        landlordResponse = response, dateDiscovered = discovered, dateReported = reported, followUpDate = followUp,
        updatedAt = updated, reportMethod = method, createdAt = created,
    )

    private fun events(c: MaintenanceCase) = MaintenanceCaseTimeline.events(c, utc, us)

    @Test
    fun openCaseReadsDiscoveredRecordedFollowUpsThenPending() {
        val result = events(
            case(
                discovered = "2026-10-20", reported = "2026-10-22", method = "Email",
                response = "Oct 23: Called\n\nOct 25: Booked repair", followUp = "2026-10-25T14:30:00Z",
            ),
        )
        assertEquals(
            listOf(
                MaintenanceCaseEvent("discovered", "Issue discovered", "Oct 20"),
                MaintenanceCaseEvent("recorded", "Case recorded", "Oct 22", detail = "Reported to landlord by email"),
                MaintenanceCaseEvent("followup-0", "Landlord follow-up", "Oct 23", detail = "Called"),
                MaintenanceCaseEvent("followup-1", "Landlord follow-up", "Oct 25 · 2:30 PM", detail = "Booked repair"),
                MaintenanceCaseEvent("pending", "Repair pending", null, isPending = true),
            ),
            result,
        )
    }

    @Test
    fun discoveredOnTheReportDayIsNotItsOwnStep() {
        val result = events(case(discovered = "2026-10-22", reported = "2026-10-22"))
        assertEquals(listOf("recorded", "pending"), result.map { it.id })
    }

    @Test
    fun resolvedCaseEndsWithRepairCompletedDatedByUpdatedAt() {
        val result = events(case(status = "resolved", reported = "2026-10-22", updated = "2026-10-30T09:05:00Z"))
        assertEquals(MaintenanceCaseEvent("resolved", "Repair completed", "Oct 30 · 9:05 AM"), result.last())
        assertFalse(result.any { it.isPending })
    }

    @Test
    fun androidMadeCaseIsRecordedAtItsCreation() {
        val result = events(case(created = "2026-10-27T08:42:00.123456+00:00"))
        assertEquals(MaintenanceCaseEvent("recorded", "Case recorded", "Oct 27 · 8:42 AM"), result.first())
    }

    @Test
    fun legacyUndatedResponseAndBareFollowUpDate() {
        val undated = events(case(reported = "2026-10-22", response = "Landlord said next week"))
        assertEquals(MaintenanceCaseEvent("followup-0", "Landlord response", null, detail = "Landlord said next week"), undated[1])

        val bare = events(case(reported = "2026-10-22", followUp = "2026-10-24T10:00:00Z"))
        assertEquals(MaintenanceCaseEvent("followup", "Landlord follow-up", "Oct 24 · 10:00 AM"), bare[1])
    }

    @Test
    fun followUpStatusReadsAsOpenInTheTimeline() {
        val result = events(case(status = "follow_up", reported = "2026-10-22"))
        assertTrue(result.last().isPending)
    }

    @Test
    fun headerReportedFallsBackFromReportedToDiscoveredToCreated() {
        assertEquals("Oct 22", case(reported = "2026-10-22", discovered = "2026-10-20").reportedText(utc, us))
        assertEquals("Oct 20", case(discovered = "2026-10-20").reportedText(utc, us))
        assertEquals("Oct 27 · 8:42 AM", case(created = "2026-10-27T08:42:00Z").reportedText(utc, us))
        assertNull(case().reportedText(utc, us))
    }

    @Test
    fun caseFromRowCarriesTheTimelineColumns() {
        val id = UUID.randomUUID()
        val row = MaintenanceIssueRow(
            id = id.toString(), propertyId = UUID.randomUUID().toString(), userId = UUID.randomUUID().toString(),
            title = "Leak", category = "Pests", description = null, status = "follow_up",
            landlordResponse = "Oct 23: Called", dateDiscovered = "2026-10-20", dateReported = "2026-10-22",
            followUpDate = "2026-10-23T10:00:00Z", createdAt = "2026-10-22T09:00:00Z",
            updatedAt = "2026-10-23T10:00:00Z", reportMethod = "Phone",
        )
        val c = MaintenanceCase.from(row)
        assertEquals(id, c.id)
        assertEquals("Pest", c.categoryLabel)
        assertEquals(MaintenanceCaseStatus.FollowUp, c.caseStatus)
        assertEquals("", c.details)
        assertEquals("Phone", c.reportMethod)
        assertEquals("2026-10-23T10:00:00Z", c.updatedAt)
    }

    @Test
    fun photosLeadWithTheNewest() {
        fun photo(n: Int, captured: String?, created: String?) =
            MaintenancePhotoUi(UUID(0, n.toLong()), "p$n.jpg", signedUrl = null, capturedAt = captured, createdAt = created)
        val a = photo(1, "2026-10-20T10:00:00Z", null)
        val b = photo(2, null, "2026-10-25T10:00:00Z")
        val c = photo(3, "2026-10-22T10:00:00Z", "2026-10-26T10:00:00Z")
        val d = photo(4, null, null)
        val e = photo(5, null, null)
        assertEquals(listOf(b, c, a), orderMaintenancePhotos(listOf(a, b, c)))
        // Undated photos keep the later-loaded first.
        assertEquals(listOf(e, d), orderMaintenancePhotos(listOf(d, e)))
    }

    // endregion
}
