package com.surensureshkumar.movemark.features.auth

import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import com.surensureshkumar.movemark.features.auth.PasswordResetRequest.Outcome
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/** iOS `PasswordResetRequest`: neutral send outcomes, email checks, and which failures mean the link is dead. */
class PasswordResetRequestTest {
    @Test
    fun theCooldownMatchesIos() {
        assertEquals(60, PasswordResetRequest.RESEND_COOLDOWN_SECONDS)
    }

    @Test
    fun emailValidation() {
        assertEquals("Enter your email.", PasswordResetRequest.validationMessage("   "))
        assertEquals("Enter a valid email.", PasswordResetRequest.validationMessage("renter"))
        assertEquals("Enter a valid email.", PasswordResetRequest.validationMessage("renter@example"))
        assertEquals("Enter a valid email.", PasswordResetRequest.validationMessage("@example.com"))
        assertEquals("Enter a valid email.", PasswordResetRequest.validationMessage("a@b@example.com"))
        assertEquals("Enter a valid email.", PasswordResetRequest.validationMessage("renter@.example.com"))
        assertEquals("Enter a valid email.", PasswordResetRequest.validationMessage("ren ter@example.com"))
        assertNull(PasswordResetRequest.validationMessage(" renter@example.com "))
    }

    @Test
    fun aMissingAccountIsReportedAsSent() {
        assertEquals(Outcome.Sent, PasswordResetRequest.outcome(null))
        for (code in listOf("USER_NOT_FOUND", "USER_EMAIL_NOT_FOUND", "EMAIL_NOT_FOUND")) {
            assertEquals(Outcome.Sent, PasswordResetRequest.outcome(NeonAuthException.Rejected(code, "no such user")))
        }
    }

    @Test
    fun failuresStayNeutralAndNeverEchoTheServer() {
        assertEquals(Outcome.Failed(PasswordResetRequest.NO_CONNECTION), PasswordResetRequest.outcome(IOException("timeout")))
        assertEquals(
            Outcome.Failed(PasswordResetRequest.RATE_LIMITED),
            PasswordResetRequest.outcome(NeonAuthException.Rejected("RATE_LIMITED", "")),
        )
        assertEquals(
            Outcome.Failed("Enter a valid email."),
            PasswordResetRequest.outcome(NeonAuthException.Rejected("INVALID_EMAIL", "")),
        )
        assertEquals(
            Outcome.Failed(PasswordResetRequest.GENERIC_FAILURE),
            PasswordResetRequest.outcome(NeonAuthException.Rejected("SOMETHING_ELSE", "user exists: renter@example.com")),
        )
        assertEquals(Outcome.Failed(PasswordResetRequest.GENERIC_FAILURE), PasswordResetRequest.outcome(NeonAuthException.InvalidResponse()))
        assertEquals(
            Outcome.Failed("This build is not configured to reach MoveMark’s servers."),
            PasswordResetRequest.outcome(NeonAuthException.NotConfigured()),
        )
        assertEquals(Outcome.Failed("Enter your email."), PasswordResetRequest.outcome(AuthException("Enter your email.")))
        assertEquals(Outcome.Failed(PasswordResetRequest.GENERIC_FAILURE), PasswordResetRequest.outcome(IllegalStateException("boom")))
    }

    @Test
    fun onlyNeonTokenCodesMeanTheLinkExpired() {
        assertTrue(PasswordResetRequest.isRejectedToken(NeonAuthException.Rejected("INVALID_TOKEN", "")))
        assertTrue(PasswordResetRequest.isRejectedToken(NeonAuthException.Rejected("TOKEN_EXPIRED", "")))
        assertFalse(PasswordResetRequest.isRejectedToken(NeonAuthException.Rejected("PASSWORD_TOO_SHORT", "")))
        assertFalse(PasswordResetRequest.isRejectedToken(NeonAuthException.Rejected(null, "")))
        assertFalse(PasswordResetRequest.isRejectedToken(IOException("Unable to resolve host")))
        assertFalse(PasswordResetRequest.isRejectedToken(NeonAuthException.InvalidResponse()))
        assertFalse(PasswordResetRequest.isRejectedToken(AuthException("This reset link is invalid or has expired. Request a new one.")))
    }

    @Test
    fun aFailedSaveNeverSaysExpiredUnlessTheTokenWasRefused() {
        assertEquals(PasswordResetRequest.NO_CONNECTION, resetFailureMessage(IOException("Unable to resolve host")))
        assertEquals("Passwords do not match.", resetFailureMessage(AuthException("Passwords do not match.")))
        assertEquals("Couldn’t reset your password. Try again.", resetFailureMessage(IllegalStateException("HTTP 500")))
    }
}
