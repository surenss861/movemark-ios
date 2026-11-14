package com.surensureshkumar.movemark.features.auth

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PasswordResetLinkTest {
    @After
    fun tearDown() = PasswordResetLink.consume()

    @Test
    fun readsTheTokenFromTheAppScheme() {
        assertEquals("abc123", PasswordResetLink.token("movemark://reset-password?token=abc123"))
        assertEquals("abc123", PasswordResetLink.token("MOVEMARK://Reset-Password?foo=1&token=abc123"))
        assertEquals("a b+c", PasswordResetLink.token("movemark://reset-password?token=a%20b%2Bc"))
    }

    @Test
    fun ignoresAnythingElse() {
        assertNull(PasswordResetLink.token(null))
        assertNull(PasswordResetLink.token("movemark://reset-password"))
        assertNull(PasswordResetLink.token("movemark://reset-password?token="))
        assertNull(PasswordResetLink.token("movemark://other?token=x"))
        assertNull(PasswordResetLink.token("https://reset-password?token=x"))
        assertNull(PasswordResetLink.token("not a uri ::"))
    }

    @Test
    fun offerQueuesTheTokenUntilConsumed() {
        assertFalse(PasswordResetLink.offer("https://example.com"))
        assertNull(PasswordResetLink.token.value)
        assertTrue(PasswordResetLink.offer("movemark://reset-password?token=t1"))
        assertEquals("t1", PasswordResetLink.token.value)
        PasswordResetLink.consume()
        assertNull(PasswordResetLink.token.value)
    }
}
