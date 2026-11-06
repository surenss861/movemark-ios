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
    fun withoutSocialStateWelcomeIsUnchanged() {
        compose.setContent { WelcomeScreen(onStartMoveIn = {}, onSignIn = {}) }
        compose.onNodeWithText("Already have an account?").assertExists()
        compose.onNodeWithText("Sign in").assertExists()
        compose.onNodeWithText("Continue with Google").assertDoesNotExist()
        compose.onNodeWithText("Continue with Apple").assertDoesNotExist()
        compose.onNodeWithText("I already have a vault").assertDoesNotExist()
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
        // Google first on Android.
        // Unclipped positions: on a short test screen the block scrolls, so clipped bounds can coincide.
        val google = compose.onNodeWithTag("welcome.social.google").fetchSemanticsNode().positionInRoot.y
        val apple = compose.onNodeWithTag("welcome.social.apple").fetchSemanticsNode().positionInRoot.y
        assertTrue("Google above Apple", google < apple)

        compose.onNodeWithText("Continue with Google").performScrollTo().performClick()
        compose.onNodeWithText("Continue with Apple").performScrollTo().performClick()
        compose.onNodeWithText("I already have a vault").performScrollTo().performClick()
        assertEquals(listOf(SocialProvider.GOOGLE, SocialProvider.APPLE), picked)
        assertTrue(emailTapped)
    }

    @Test
    fun exampleRecordIsAnIllustrativeCaptionNotAClaimCard() {
        compose.setContent { WelcomeScreen(onStartMoveIn = {}, onSignIn = {}) }
        compose.onNodeWithContentDescription("Example move-in record: Kitchen, April 14, 12 photos. Illustrative, not your evidence.")
            .assertExists()
        compose.onNodeWithText("DAMAGE CLAIM").assertDoesNotExist()
        compose.onNodeWithText("Already documented").assertDoesNotExist()
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
        compose.onNodeWithTag("welcome.social.apple").assertIsNotEnabled()
        compose.onNodeWithTag("welcome.social.error").assertExists()
    }
}
