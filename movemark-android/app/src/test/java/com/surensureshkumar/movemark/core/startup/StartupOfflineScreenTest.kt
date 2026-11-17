package com.surensureshkumar.movemark.core.startup

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StartupOfflineScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun offlineStateIsRecoverableAndNeverAskForAName() {
        var retries = 0
        var signOuts = 0
        compose.setContent { StartupOfflineScreen(isRetrying = false, onRetry = { retries++ }, onSignOut = { signOuts++ }) }
        compose.onNodeWithText(STARTUP_OFFLINE_TITLE).assertExists()
        compose.onNodeWithText("What should we call you?").assertDoesNotExist()
        compose.onNodeWithTag("startup.offline.retry").performClick()
        compose.onNodeWithText("Sign out").performClick()
        assertEquals(1, retries)
        assertEquals(1, signOuts)
    }

    @Test
    fun retryingDisablesTheButton() {
        compose.setContent { StartupOfflineScreen(isRetrying = true, onRetry = {}, onSignOut = {}) }
        compose.onNodeWithText("Trying…").assertExists()
        compose.onNodeWithTag("startup.offline.retry").assertIsNotEnabled()
    }
}
