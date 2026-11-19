package com.surensureshkumar.movemark.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class CrashReportingTest {
    private val dsn = "https://key@o1.ingest.us.sentry.io/2"

    @Test
    fun noDsnMeansOff() {
        assertNull(CrashReporting.settings("", isDebug = false, versionName = "1.4.0", versionCode = 2026110201))
        assertNull(CrashReporting.settings("   ", false, "1.4.0", 1))
        assertNull("not a DSN", CrashReporting.settings("changeme", false, "1.4.0", 1))
    }

    @Test
    fun matchesIos() {
        val release = CrashReporting.settings(dsn, isDebug = false, versionName = "1.4.0", versionCode = 2026110201)!!
        assertEquals("production", release.environment)
        assertEquals("1.4.0 (2026110201)", release.release)
        assertFalse("personal data off", release.sendDefaultPii)
        assertEquals(0.0, release.tracesSampleRate, 0.0)
        assertFalse(release.attachScreenshot)
        assertFalse(release.attachViewHierarchy)
        assertEquals("development", CrashReporting.settings(dsn, isDebug = true, versionName = "1.4.0", versionCode = 1)!!.environment)
    }
}
