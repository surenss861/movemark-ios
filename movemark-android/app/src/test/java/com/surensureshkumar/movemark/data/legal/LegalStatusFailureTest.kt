package com.surensureshkumar.movemark.data.legal

import com.surensureshkumar.movemark.data.backend.PostgrestException
import com.surensureshkumar.movemark.features.legal.LegalGateState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Where a failed `get_legal_status` lands (iOS `LegalStatusFailure` and `SessionManager.enter`). */
class LegalStatusFailureTest {
    @Test fun noNetworkIsOffline() {
        assertEquals(LegalStatusFailure.Offline, LegalStatusFailure.classify(java.net.UnknownHostException("x")))
        assertEquals(LegalStatusFailure.Offline, LegalStatusFailure.classify(RuntimeException(java.net.SocketTimeoutException())))
    }

    @Test fun aServerWithoutTheFunctionHasNoGate() {
        assertEquals(LegalStatusFailure.ServerWithoutGate, LegalStatusFailure.classify(PostgrestException(404, "PGRST202", "Could not find the function")))
    }

    @Test fun anyOtherAnswerIsUnavailable() {
        assertEquals(LegalStatusFailure.Unavailable, LegalStatusFailure.classify(PostgrestException(500, "XX000", "boom")))
        assertEquals(LegalStatusFailure.Unavailable, LegalStatusFailure.classify(PostgrestException(403, null, "LEGAL_NOT_AUTHENTICATED")))
    }

    @Test fun offlineAndNoGateOpenTheAppButUnavailableNeverDoes() {
        val offline = LegalGateState.from(LegalStatusResult.Failure(LegalStatusFailure.Offline))
        assertEquals(false, offline.required)
        assertFalse(offline.statusUnavailable)
        val noGate = LegalGateState.from(LegalStatusResult.Failure(LegalStatusFailure.ServerWithoutGate))
        assertEquals(false, noGate.required)
        val unavailable = LegalGateState.from(LegalStatusResult.Failure(LegalStatusFailure.Unavailable))
        assertNull(unavailable.required)
        assertTrue(unavailable.statusUnavailable)
    }
}
