package com.surensureshkumar.movemark.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RentalLocationTest {
    @Test
    fun aMissingProvinceShowsJustTheCity() {
        assertEquals("Toronto", RentalLocation.line("Toronto", "Unknown"))
        assertEquals("Toronto", RentalLocation.line("Toronto", ""))
        assertEquals("Toronto", RentalLocation.line(" Toronto ", null))
    }

    @Test
    fun bothPartsShowWhenStored() {
        assertEquals("Toronto, ON", RentalLocation.line("Toronto", "ON"))
        assertEquals("ON", RentalLocation.line("unknown", "ON"))
        assertEquals("", RentalLocation.line("Unknown", "N/A"))
    }

    @Test
    fun placeholdersAreNeverShown() {
        listOf("Unknown", "UNKNOWN", "n/a", "NA", "none", "-", "00000", "  ").forEach { assertNull(it, RentalLocation.meaningful(it)) }
        assertEquals("Ottawa", RentalLocation.meaningful(" Ottawa "))
    }
}
