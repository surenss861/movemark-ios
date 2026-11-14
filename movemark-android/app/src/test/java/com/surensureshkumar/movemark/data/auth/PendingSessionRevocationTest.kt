package com.surensureshkumar.movemark.data.auth

import com.surensureshkumar.movemark.data.backend.NeonAuthException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS `PendingSessionRevocation`: the first session within an hour of a reset signs every other device out. */
class PendingSessionRevocationTest {
    private class MemoryStore : PendingSessionRevocation.Store { override var untilMillis: Long = 0 }
    private var now = 1_000_000L
    private val store = MemoryStore()
    private val pending = PendingSessionRevocation(store) { now }

    @Test fun nothingPendingRunsNothing() = runTest {
        var calls = 0
        assertEquals(PendingSessionRevocation.Outcome.NothingPending, pending.performIfPending { calls++ })
        assertEquals(0, calls)
    }

    @Test fun aResetRevokesOnceThenClears() = runTest {
        pending.markPasswordReset()
        var calls = 0
        assertEquals(PendingSessionRevocation.Outcome.Revoked, pending.performIfPending { calls++ })
        assertEquals(PendingSessionRevocation.Outcome.NothingPending, pending.performIfPending { calls++ })
        assertEquals(1, calls)
    }

    @Test fun aNetworkFailureIsRetriedLater() = runTest {
        pending.markPasswordReset()
        assertEquals(PendingSessionRevocation.Outcome.WillRetry, pending.performIfPending { throw java.io.IOException("offline") })
        assertTrue(pending.isPending())
    }

    @Test fun aGoneSessionClearsTheMark() = runTest {
        pending.markPasswordReset()
        assertEquals(PendingSessionRevocation.Outcome.SessionGone, pending.performIfPending { throw NeonAuthException.SessionExpired() })
        assertFalse(pending.isPending())
    }

    @Test fun theMarkExpiresAfterAnHour() {
        pending.markPasswordReset()
        now += PendingSessionRevocation.WINDOW_MILLIS + 1
        assertFalse(pending.isPending())
    }
}
