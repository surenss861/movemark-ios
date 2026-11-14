package com.surensureshkumar.movemark.data.evidence.pending

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** PostgREST returns timestamptz with microseconds; the receipt's "Saved" time must parse every form it sends. */
class ServerTimestampTest {
    @Test fun microsecondsWithAnOffset() =
        assertEquals(Instant.parse("2026-11-14T10:13:42.123456Z"), parseServerTimestamp("2026-11-14T10:13:42.123456+00:00"))

    @Test fun nonUtcOffsetsAreHonoured() =
        assertEquals(Instant.parse("2026-11-14T15:13:42.000001Z"), parseServerTimestamp("2026-11-14T10:13:42.000001-05:00"))

    @Test fun zuluAndNoFraction() =
        assertEquals(Instant.parse("2026-11-14T10:13:42Z"), parseServerTimestamp("2026-11-14T10:13:42Z"))

    @Test fun postgresTextFormWithASpaceAndHourOffset() =
        assertEquals(Instant.parse("2026-11-14T10:13:42.123456Z"), parseServerTimestamp("2026-11-14 10:13:42.123456+00"))

    @Test fun garbageIsNull() = assertNull(parseServerTimestamp("yesterday"))

    @Test fun theLatestOfTwoWinsAndNullsAreIgnored() {
        val a = "2026-11-14T10:13:42.100000+00:00"
        val b = "2026-11-14T10:13:42.900000+00:00"
        assertEquals(b, latestServerTime(a, b))
        assertEquals(b, latestServerTime(b, a))
        assertEquals(a, latestServerTime(a, null))
        assertEquals(b, latestServerTime(null, b))
        assertNull(latestServerTime(null, null))
        assertEquals(a, latestServerTime(a, "garbage"))
    }
}
