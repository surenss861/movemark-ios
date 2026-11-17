package com.surensureshkumar.movemark.data.auth

import com.surensureshkumar.movemark.core.startup.ProfileStatus
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.UnknownHostException

class ProfileGateTest {
    private val offline = ProfileLookup.Failed(UnknownHostException("api"))

    @Test
    fun failedLookupWithNothingCachedIsUnavailableNeverNeedsName() {
        // The A14 root cause: fetchFullName returned null on UnknownHostException, read as "no name".
        val state = ProfileGate.apply(ProfileGate.restore(null), offline)
        assertEquals(ProfileStatus.Unavailable, state.status)
        assertFalse(state.verified)
    }

    @Test
    fun cachedNameOpensAtOnceAndSurvivesAFailedLookup() {
        val restored = ProfileGate.restore("Avery Tester")
        assertEquals(ProfileStatus.HasName, restored.status)
        assertFalse("cached answers are re-checked", restored.verified)
        val after = ProfileGate.apply(restored, offline)
        assertEquals(ProfileStatus.HasName, after.status)
        assertEquals("Avery Tester", after.fullName)
    }

    @Test
    fun blankCacheIsNothingCached() {
        assertEquals(ProfileStatus.Unknown, ProfileGate.restore("  ").status)
    }

    @Test
    fun onlyTheServersAnswerMarksTheNameMissing() {
        val state = ProfileGate.apply(ProfileGate.restore(null), ProfileLookup.Missing)
        assertEquals(ProfileStatus.NeedsName, state.status)
        assertTrue(state.verified)
        // A later failure keeps the confirmed answer: a genuinely new account still sees the name screen.
        assertEquals(ProfileStatus.NeedsName, ProfileGate.apply(state, offline).status)
    }

    @Test
    fun reconnectRecoversFromUnavailable() {
        val offlineState = ProfileGate.apply(ProfileState(), offline)
        val found = ProfileGate.apply(offlineState, ProfileLookup.Found("Avery Tester"))
        assertEquals(ProfileStatus.HasName, found.status)
        assertTrue(found.verified)
        val missing = ProfileGate.apply(offlineState, ProfileLookup.Missing)
        assertEquals(ProfileStatus.NeedsName, missing.status)
    }

    @Test
    fun serverOverridesTheCacheBothWays() {
        assertEquals(ProfileStatus.NeedsName, ProfileGate.apply(ProfileGate.restore("Old Name"), ProfileLookup.Missing).status)
        assertEquals("New Name", ProfileGate.apply(ProfileGate.restore("Old Name"), ProfileLookup.Found("New Name")).fullName)
    }

    @Test
    fun slowLookupTimesOutAsFailedNotMissing() = runTest {
        val result = ProfileGate.lookupWithin(timeoutMs = 8_000) {
            delay(60_000)
            ProfileLookup.Missing
        }
        assertTrue(result is ProfileLookup.Failed)
        assertNull((result as ProfileLookup.Failed).cause)
        assertEquals(ProfileStatus.Unavailable, ProfileGate.apply(ProfileState(), result).status)
    }

    @Test
    fun lookupThatAnswersInTimeIsKept() = runTest {
        val result = ProfileGate.lookupWithin(timeoutMs = 8_000) {
            delay(2_000)
            ProfileLookup.Found("Avery Tester")
        }
        assertEquals(ProfileLookup.Found("Avery Tester"), result)
    }
}
