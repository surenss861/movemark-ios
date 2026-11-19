package com.surensureshkumar.movemark

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/** The built app carries the release version scheme (README "Versioning"). */
class VersionSchemeTest {
    @Test
    fun versionNameMatchesIos() = assertEquals("1.4.0", BuildConfig.VERSION_NAME)

    @Test
    fun versionCodeIsADateAndASequence() {
        val code = BuildConfig.VERSION_CODE.toString()
        assertEquals(10, code.length)
        LocalDate.parse(code.take(8), DateTimeFormatter.BASIC_ISO_DATE) // throws when not a real date
        assertTrue(code.takeLast(2).toInt() in 1..99)
        assertTrue("above every earlier upload", BuildConfig.VERSION_CODE > 1)
        assertTrue("under Play's ceiling", BuildConfig.VERSION_CODE < 2_100_000_000)
    }
}
