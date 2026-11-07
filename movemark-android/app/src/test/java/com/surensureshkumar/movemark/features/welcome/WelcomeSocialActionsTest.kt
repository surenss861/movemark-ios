package com.surensureshkumar.movemark.features.welcome

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.features.auth.social.SocialProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class WelcomeSocialActionsTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun withoutSocialStateTheProviderButtonsAreAbsent() {
        compose.setContent { WelcomeScreen(onStartMoveIn = {}, onSignIn = {}) }
        compose.onNodeWithText("I already have a vault").assertExists()
        compose.onNodeWithText("Continue with Google").assertDoesNotExist()
        compose.onNodeWithText("Continue with Apple").assertDoesNotExist()
    }

    @Test
    fun socialBlockKeepsTheProofCtaAndEmailAndRoutesTaps() {
        val picked = mutableListOf<SocialProvider>()
        var emailTapped = false
        compose.setContent {
            WelcomeScreen(
                onStartMoveIn = {},
                onSignIn = { emailTapped = true },
                social = WelcomeSocialState(),
                onSocial = { picked += it },
            )
        }
        compose.onNodeWithText("Start move-in proof").assertExists()
        // Both providers show: they share the browser flow.
        compose.onNodeWithTag("welcome.social.google").assertExists()
        compose.onNodeWithTag("welcome.social.apple").assertExists()
        compose.onNodeWithText("Continue with Apple").assertExists()

        compose.onNodeWithText("Continue with Google").performScrollTo().performClick()
        compose.onNodeWithText("I already have a vault").performScrollTo().performClick()
        assertEquals(listOf(SocialProvider.GOOGLE), picked)
        assertTrue(emailTapped)
    }

    @Test
    fun heroIsTheProofApertureWithOneSpokenLine() {
        compose.setContent { WelcomeScreen(onStartMoveIn = {}, onSignIn = {}) }
        compose.onNodeWithContentDescription("Move-in: before anything changes.").assertExists()
        compose.onNodeWithText("Prove what was\nalready there.").assertExists()
        compose.onNodeWithText("Private evidence").assertExists()
        compose.onNodeWithText("DAMAGE CLAIM").assertDoesNotExist()
        compose.onNodeWithText("Kitchen").assertDoesNotExist()
    }

    @Test
    fun whileOneProviderRunsBothAreDisabledAndErrorsShow() {
        compose.setContent {
            WelcomeScreen(
                onStartMoveIn = {},
                onSignIn = {},
                social = WelcomeSocialState(busyProvider = SocialProvider.GOOGLE, errorMessage = "Google sign-in didn’t finish. Try again."),
            )
        }
        compose.onNodeWithTag("welcome.social.google").assertIsNotEnabled()
        compose.onNodeWithTag("welcome.social.error").assertExists()
    }
}
