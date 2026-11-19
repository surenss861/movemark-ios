package com.surensureshkumar.movemark.features.auth.social

import com.surensureshkumar.movemark.features.auth.social.SocialBrowserReturn
import com.surensureshkumar.movemark.features.auth.social.SocialSignInException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class SocialSignInTest {
    @Test fun onlyTheExpectedLinkIsAReturn() {
        assertTrue(SocialBrowserReturn.isReturn("movemark", "auth", "/callback"))
        assertFalse(SocialBrowserReturn.isReturn("https", "auth", "/callback"))
        assertFalse(SocialBrowserReturn.isReturn("movemark", "reset-password", "/callback"))
        assertFalse(SocialBrowserReturn.isReturn("movemark", "auth", "/other"))
    }

    @Test fun aVerifierIsReturned() {
        assertEquals("abc-123", SocialBrowserReturn.verifier("abc-123", null))
    }

    @Test fun declinedConsentIsCancelled() {
        assertThrows(SocialSignInException.Cancelled::class.java) { SocialBrowserReturn.verifier(null, "access_denied") }
    }

    @Test fun anAccountConflictSaysHowToGetIn() {
        val e = assertThrows(SocialSignInException.Failed::class.java) { SocialBrowserReturn.verifier(null, "account_not_linked") }
        assertEquals(SocialBrowserReturn.ACCOUNT_CONFLICT_MESSAGE, e.message)
    }

    @Test fun anythingElseFails() {
        assertThrows(SocialSignInException.Failed::class.java) { SocialBrowserReturn.verifier("", "server_error") }
        assertThrows(SocialSignInException.Failed::class.java) { SocialBrowserReturn.verifier(null, null) }
    }
}
