package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.core.startup.RentalStatus
import com.surensureshkumar.movemark.data.models.PropertyRow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RentalGateTest {
    private val user = "0000000A-0000-4000-8000-000000000001"
    private val row = PropertyRow(
        id = "11111111-0000-4000-8000-000000000001", userId = user.lowercase(), title = "Home",
        addressLine1 = "1 Main St", city = "Toronto", provinceState = "ON", postalCode = "M1M1M1", country = "CA",
    )

    @Test
    fun onlyTheServersEmptyListingMeansNoRental() {
        assertEquals(RentalStatus.NoRental, RentalGate.status(listedEmpty = true, hasProperty = false))
    }

    @Test
    fun failedListingWithNothingCachedIsUnavailableNotNoRental() {
        // Before: the listing's catch set currentProperty = null with the fetch marked complete -> rental setup offline.
        assertEquals(RentalStatus.Unavailable, RentalGate.status(listedEmpty = false, hasProperty = false))
    }

    @Test
    fun cachedOrLoadedRentalIsHasRental() {
        assertEquals(RentalStatus.HasRental, RentalGate.status(listedEmpty = false, hasProperty = true))
    }

    @Test
    fun cachedListingRoundTripsForTheSameAccountOnly() {
        val raw = RentalGate.encodeListing(user, listOf(row))
        assertEquals(listOf(row), RentalGate.decodeListing(user.lowercase(), raw))
        assertEquals(listOf(row), RentalGate.decodeListing(user, raw))
        assertNull(RentalGate.decodeListing("00000000-0000-4000-8000-000000000002", raw))
    }

    @Test
    fun missingOrUnreadableCacheIsNull() {
        assertNull(RentalGate.decodeListing(user, null))
        assertNull(RentalGate.decodeListing(user, ""))
        assertNull(RentalGate.decodeListing(user, "{not json"))
    }

    @Test
    fun cachedEmptyListingStaysEmpty() {
        assertEquals(emptyList<PropertyRow>(), RentalGate.decodeListing(user, RentalGate.encodeListing(user, emptyList())))
    }
}
