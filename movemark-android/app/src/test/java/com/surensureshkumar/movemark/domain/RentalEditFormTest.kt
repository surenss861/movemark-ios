package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RentalEditFormTest {
    private val row = PropertyRow(
        id = "p", userId = "u", title = "12 Elm St", addressLine1 = "12 Elm St", addressLine2 = "Unit 4",
        city = "Toronto", provinceState = "ON", postalCode = "M5V 1A1", country = "CA",
        landlordName = "Pat", landlordEmail = "not-an-email", depositAmount = 1500.0, rentAmount = 2150.5,
    )

    @Test
    fun aTitleThatRepeatsTheStreetStaysBlankAndFollowsTheAddress() {
        val form = RentalEditForm.from(row)
        assertEquals("", form.name)
        assertEquals("1500", form.depositAmount)
        assertEquals("2150.5", form.rentAmount)
        assertEquals("14 Oak Ave", form.copy(addressLine1 = " 14 Oak Ave ").toPatch().title)
        assertEquals("Lakeview", form.copy(name = "Lakeview").toPatch().title)
    }

    @Test
    fun theAddressIsRequired() {
        val form = RentalEditForm.from(row)
        assertEquals("Enter the property address.", form.copy(addressLine1 = "  ").validationError)
        assertNull(form.validationError)
    }

    @Test
    fun anUnchangedBadValueDoesNotBlockTheSaveButAnEditedOneDoes() {
        val initial = RentalEditForm.from(row)
        assertTrue("the stored email was already malformed", initial.canSave(initial))
        assertEquals("Check the email address.", initial.copy(landlordEmail = "pat@").detailsIssue(initial))
        assertNull(initial.copy(landlordEmail = "pat@example.com").detailsIssue(initial))
        assertEquals("Enter an amount, like 1500.", initial.copy(rentAmount = "lots").detailsIssue(initial))
        assertFalse(initial.copy(depositAmount = "-5").canSave(initial))
    }

    @Test
    fun patchCleansBlanksAndAmounts() {
        val patch = RentalEditForm.from(row).copy(unit = " ", landlordPhone = "", depositAmount = "$1,750.00", rentAmount = "").toPatch()
        assertNull(patch.addressLine2)
        assertNull(patch.landlordPhone)
        assertEquals(1750.0, patch.depositAmount!!, 0.0)
        assertNull(patch.rentAmount)
        assertEquals("CA", RentalEditForm(addressLine1 = "x", country = "").toPatch().country)
        // Setup's placeholders read as blank and go back as placeholders.
        val placeholder = RentalEditForm.from(row.copy(city = "Unknown", postalCode = "00000"))
        assertEquals("", placeholder.city)
        assertEquals("", placeholder.postalCode)
        assertEquals("Unknown", placeholder.toPatch().city)
        assertEquals("00000", placeholder.toPatch().postalCode)
    }
}
