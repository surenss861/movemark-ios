package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class RentalDatesTest {
    private val d = LocalDate.of(2026, 9, 1)

    @Test
    fun storedAsIsoDays() {
        assertEquals("2026-09-01", RentalDates.format(d))
        assertEquals(d, RentalDates.parse("2026-09-01"))
        assertEquals(d, RentalDates.parse("2026-09-01T00:00:00+00:00"))
        assertNull(RentalDates.parse(""))
        assertNull(RentalDates.parse("09/01/2026"))
    }

    @Test
    fun leaseCannotEndBeforeItStartsSameDayIsFine() {
        assertEquals("The lease end date can’t be before the lease start date.", RentalDates.leaseDatesError(d, d.minusDays(1)))
        assertNull(RentalDates.leaseDatesError(d, d))
        assertNull(RentalDates.leaseDatesError(null, d))
        assertEquals(LocalDate.of(2027, 9, 1), RentalDates.defaultLeaseEnd(d))
    }

    private val row = PropertyRow(
        id = "p", userId = "u", title = "12 Elm St", addressLine1 = "12 Elm St", city = "Toronto",
        provinceState = "ON", postalCode = "M5V", country = "CA", moveInDate = "2026-09-01",
    )

    @Test
    fun aRentalWithoutALeaseKeepsNoneUnlessTheRenterSetsOne() {
        val initial = RentalEditForm.from(row)
        assertFalse(initial.hadLease)
        assertEquals(d, initial.moveInDate)
        assertEquals(d, initial.leaseStart)
        assertEquals(d.plusYears(1), initial.leaseEnd)
        val untouched = initial.copy(rentAmount = "2000").toPatch(initial)
        assertEquals("2026-09-01", untouched.moveInDate)
        assertNull("no invented lease", untouched.leaseStart)
        assertNull(untouched.leaseEnd)
        val set = initial.copy(leaseEnd = LocalDate.of(2027, 8, 31)).toPatch(initial)
        assertEquals("2026-09-01", set.leaseStart)
        assertEquals("2027-08-31", set.leaseEnd)
    }

    @Test
    fun anExistingLeaseIsAlwaysSavedAndValidated() {
        val initial = RentalEditForm.from(row.copy(leaseStart = "2026-08-15", leaseEnd = "2027-08-14"))
        assertTrue(initial.hadLease)
        assertEquals("2026-08-15", initial.toPatch(initial).leaseStart)
        val backwards = initial.copy(leaseEnd = LocalDate.of(2026, 8, 1))
        assertEquals("The lease end date can’t be before the lease start date.", backwards.leaseError(initial))
        assertFalse(backwards.canSave(initial))
        val moved = initial.copy(moveInDate = LocalDate.of(2026, 9, 3)).toPatch(initial)
        assertEquals("2026-09-03", moved.moveInDate)
    }

    @Test
    fun aMissingMoveInDateStartsFromToday() {
        val today = LocalDate.of(2026, 11, 2)
        assertEquals(today, RentalEditForm.from(row.copy(moveInDate = null), today).moveInDate)
    }
}
