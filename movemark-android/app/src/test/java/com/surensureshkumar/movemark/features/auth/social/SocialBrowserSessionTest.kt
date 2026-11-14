package com.surensureshkumar.movemark.features.auth.social

import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** A browser return with no attempt waiting (process death) is reported, a repeat is ignored, and the method sticks. */
@RunWith(AndroidJUnit4::class)
class SocialBrowserSessionTest {
    @Test fun anOrphanedReturnIsReportedOnceAndOtherLinksAreNotOurs() {
        SocialBrowserSession.clearOrphanedReturn()
        assertFalse(SocialBrowserSession.offer(Uri.parse("movemark://reset-password?token=x")))
        assertFalse(SocialBrowserSession.orphanedReturn.value)
        val link = Uri.parse("movemark://auth/callback?neon_auth_session_verifier=v-${System.nanoTime()}")
        assertTrue(SocialBrowserSession.offer(link))
        assertTrue(SocialBrowserSession.orphanedReturn.value)
        SocialBrowserSession.clearOrphanedReturn()
        assertTrue(SocialBrowserSession.offer(link)) // the same link again (a recreated Activity's intent)
        assertFalse(SocialBrowserSession.orphanedReturn.value)
    }

    @Test fun theSignInMethodIsKeptOnDisk() {
        LegalAcceptanceMethod.attach(ApplicationProvider.getApplicationContext())
        LegalAcceptanceMethod.last = "google"
        assertEquals("google", LegalAcceptanceMethod.last)
        LegalAcceptanceMethod.last = "something-else"
        assertEquals("email", LegalAcceptanceMethod.last)
    }
}
