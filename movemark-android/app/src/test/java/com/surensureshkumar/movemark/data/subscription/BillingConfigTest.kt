package com.surensureshkumar.movemark.data.subscription

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class BillingConfigTest {
    @Test
    fun onlyAGooglePlayPublicKeyIsUsable() {
        assertNull(BillingConfig.keyProblem("goog_AbCdEf123"))
        assertNull(BillingConfig.keyProblem("  goog_AbCdEf123 \n"))
        assertNotNull(BillingConfig.keyProblem(""))
        assertNotNull(BillingConfig.keyProblem("   "))
        assertNotNull("App Store key", BillingConfig.keyProblem("appl_AbCdEf123"))
        assertNotNull("secret key", BillingConfig.keyProblem("sk_live_123"))
        assertNotNull("test store key", BillingConfig.keyProblem("test_AbC"))
    }
}
