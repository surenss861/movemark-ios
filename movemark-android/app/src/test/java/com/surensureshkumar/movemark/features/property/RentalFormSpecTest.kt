package com.surensureshkumar.movemark.features.property

import com.surensureshkumar.movemark.domain.RentalEditForm
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

class RentalFormSpecTest {
    @Test
    fun sectionsFollowIos() {
        assertEquals(listOf("Address", "Dates", "On your record", "Landlord", "Deposit & rent"), RentalFormSpec.sections)
    }

    @Test
    fun countryPickerShowsNamesNotCodes() {
        assertEquals("Canada", RentalFormSpec.countryName("CA"))
        assertEquals("United States", RentalFormSpec.countryName("US"))
        assertEquals("United Kingdom", RentalFormSpec.countryName("GB"))
        assertEquals("Other", RentalFormSpec.countryName("Other"))
        RentalFormSpec.countryOptions.forEach { assert(RentalFormSpec.countryName(it).length > 2) { it } }
    }

    @Test
    fun countryPickerKeepsStoredValuesCompatible() {
        assertEquals("CA", RentalFormSpec.countryOption("CA"))
        assertEquals("CA", RentalFormSpec.countryOption(""))
        assertEquals("Other", RentalFormSpec.countryOption("FR"))
        assertEquals("FR", RentalFormSpec.customCountry("FR"))
        assertEquals("", RentalFormSpec.customCountry("US"))
        val form = RentalEditForm(addressLine1 = "1 A St", country = "CA")
        assertEquals("US", RentalFormSpec.choose("US", form).country)
        // Other from a fixed code starts blank; a stored custom code is kept.
        assertEquals("", RentalFormSpec.choose("Other", form).country)
        assertEquals("FR", RentalFormSpec.choose("Other", form.copy(country = "FR")).country)
        assertEquals("Other", RentalFormSpec.shownOption("", otherChosen = true))
        assertEquals("CA", RentalFormSpec.shownOption("", otherChosen = false))
    }

    @Test
    fun inlineIssuesForEmailAndAmounts() {
        val form = RentalEditForm(addressLine1 = "1 A St")
        assertNull(RentalFormSpec.emailIssue(form))
        assertEquals("Check the email address.", RentalFormSpec.emailIssue(form.copy(landlordEmail = "pat@")))
        assertNull(RentalFormSpec.emailIssue(form.copy(landlordEmail = "pat@example.com")))
        assertEquals("Enter an amount, like 1500.", RentalFormSpec.depositIssue(form.copy(depositAmount = "lots")))
        assertNull(RentalFormSpec.depositIssue(form.copy(depositAmount = "$1,500")))
        assertEquals("Enter an amount, like 1500.", RentalFormSpec.rentIssue(form.copy(rentAmount = "-5")))
    }

    @Test
    fun noticePrefersTheSaveErrorThenTheLease() {
        val start = LocalDate.of(2026, 1, 1)
        val initial = RentalEditForm(addressLine1 = "1 A St", leaseStart = start, leaseEnd = start.plusYears(1), hadLease = true)
        assertNull(RentalFormSpec.notice(null, initial, initial))
        val backwards = initial.copy(leaseEnd = start.minusDays(1))
        assertEquals(backwards.leaseError(initial), RentalFormSpec.notice(null, backwards, initial))
        assertEquals("Couldn't save your changes. Try again.", RentalFormSpec.notice("Couldn't save your changes. Try again.", backwards, initial))
    }

    @Test
    fun otherWithNoCountryCodeCannotBeSaved() {
        val initial = RentalEditForm(addressLine1 = "1 A St", country = "CA")
        val other = RentalFormSpec.choose("Other", initial)
        assertEquals(RentalEditForm.COUNTRY_CODE_NEEDED, other.countryIssue)
        assertEquals(false, other.canSave(initial))
        assertEquals(RentalEditForm.COUNTRY_CODE_NEEDED, RentalFormSpec.notice(null, other, initial))
        val typed = other.copy(country = "FR")
        assertNull(typed.countryIssue)
        assertEquals("FR", typed.toPatch(initial).country)
    }
}
