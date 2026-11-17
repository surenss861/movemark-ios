package com.surensureshkumar.movemark.features.auth

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode
import java.io.IOException

/** iOS 1.4 reset mode, "Check your email" and "Link expired" on the Android auth surfaces. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class AuthResetFlowUiTest {
    @get:Rule val compose = createComposeRule()

    private fun tap(tag: String) = compose.onNodeWithTag(tag).performScrollTo().performClick()

    @Test
    fun forgotPasswordIsHiddenWithoutAResetPage() {
        compose.setContent { AuthContent(state = AuthFormState(mode = AuthMode.SignIn, resetAvailable = false)) }
        compose.onNodeWithTag("auth.forgotPassword").assertDoesNotExist()
    }

    @Test
    fun forgotPasswordIsOfferedOnSignIn() {
        var opened = 0
        compose.setContent { AuthContent(state = AuthFormState(mode = AuthMode.SignIn), onForgotPassword = { opened++ }) }
        tap("auth.forgotPassword")
        assertEquals(1, opened)
    }

    @Test
    fun resetModeAsksForTheEmailOnly() {
        var switched = 0
        compose.setContent { AuthContent(state = AuthFormState(mode = AuthMode.ResetPassword), onSwitchMode = { switched++ }) }
        compose.onNodeWithText("Reset your password").assertExists()
        compose.onNodeWithText("We’ll email you a link to choose a new one.").assertExists()
        compose.onNodeWithTag("auth.email").assertExists()
        compose.onNodeWithTag("auth.password").assertDoesNotExist()
        compose.onNodeWithTag("auth.forgotPassword").assertDoesNotExist()
        compose.onNodeWithText("Send reset link").assertExists()
        compose.onNodeWithText("Remembered it?").assertExists()
        tap("auth.switchMode")
        assertEquals(1, switched)
    }

    @Test
    fun checkYourEmailIsNeutralAndCountsDownTheResend() {
        var back = 0
        var resends = 0
        compose.setContent {
            AuthContent(
                state = AuthFormState(mode = AuthMode.ResetPassword, resetSentTo = "renter@example.com", resendCooldown = 42),
                onBackToSignInFromReset = { back++ },
                onResendReset = { resends++ },
            )
        }
        compose.onNodeWithText("Check your email").assertExists()
        compose.onNodeWithText("Open the link on this phone.").assertExists()
        compose.onNodeWithText(
            "If renter@example.com has a MoveMark account, a link to choose a new password is on its way. It expires soon.",
        ).assertExists()
        compose.onNodeWithText("Didn’t get it?").assertExists()
        compose.onNodeWithText("Resend in 42s").assertExists()
        compose.onNodeWithTag("auth.resendReset").assertIsNotEnabled()
        compose.onNodeWithText("Send reset link").assertDoesNotExist()
        compose.onNodeWithText("Back to sign in").performScrollTo().performClick()
        assertEquals(1, back)
        assertEquals(0, resends)
    }

    @Test
    fun resendIsAvailableOnceTheCooldownEnds() {
        var resends = 0
        compose.setContent {
            AuthContent(
                state = AuthFormState(mode = AuthMode.ResetPassword, resetSentTo = "renter@example.com"),
                onResendReset = { resends++ },
            )
        }
        compose.onNodeWithText("Resend link").assertExists()
        compose.onNodeWithTag("auth.resendReset").assertIsEnabled()
        tap("auth.resendReset")
        assertEquals(1, resends)
    }

    @Test
    fun signUpConfirmationShowsTheResolvedBlock() {
        var back = 0
        compose.setContent {
            AuthContent(
                state = AuthFormState(mode = AuthMode.SignUp, confirmationEmail = "new@example.com"),
                onBackToSignInAfterConfirmation = { back++ },
            )
        }
        compose.onNodeWithText("Check your email").assertExists()
        compose.onNodeWithText("One more step to finish your vault.").assertExists()
        compose.onNodeWithText(
            "We sent a confirmation link to new@example.com. Open it to finish creating your vault.",
        ).assertExists()
        compose.onNodeWithTag("auth.error").assertDoesNotExist()
        compose.onNodeWithText("Back to sign in").performScrollTo().performClick()
        assertEquals(1, back)
    }

    @Test
    fun anErrorLinkOpensOnLinkExpired() {
        var requested = 0
        compose.setContent {
            PasswordResetContent(onReset = { _, _ -> }, onDone = {}, linkExpired = true, onRequestNewLink = { requested++ })
        }
        compose.onNodeWithText("Link expired").assertExists()
        compose.onNodeWithText("Reset links work once and expire soon after they’re sent.").assertExists()
        compose.onNodeWithText("This reset link is invalid or has expired. Request a new one.").assertExists()
        compose.onNodeWithTag("passwordReset.password").assertDoesNotExist()
        tap("passwordReset.requestNew")
        assertEquals(1, requested)
    }

    @Test
    fun aSignedInPersonJustClosesAnExpiredLink() {
        var done = 0
        compose.setContent {
            PasswordResetContent(onReset = { _, _ -> }, onDone = { done++ }, linkExpired = true, signedIn = true)
        }
        compose.onNodeWithTag("passwordReset.requestNew").assertDoesNotExist()
        tap("passwordReset.close")
        assertEquals(1, done)
    }

    @Test
    fun aRefusedTokenOnSaveShowsLinkExpired() {
        compose.setContent {
            PasswordResetContent(
                onReset = { _, _ -> throw NeonAuthException.Rejected("INVALID_TOKEN", "") },
                onDone = {},
            )
        }
        tap("passwordReset.save")
        compose.waitForIdle()
        compose.onNodeWithText("Link expired").assertExists()
        compose.onNodeWithTag("passwordReset.expired").assertExists()
    }

    @Test
    fun aNetworkFailureOnSaveIsNotExpired() {
        compose.setContent {
            PasswordResetContent(onReset = { _, _ -> throw IOException("Unable to resolve host") }, onDone = {})
        }
        tap("passwordReset.save")
        compose.waitForIdle()
        compose.onNodeWithText("Link expired").assertDoesNotExist()
        compose.onNodeWithText("Choose a new password").assertExists()
        compose.onNodeWithText("No connection. Check your internet and try again.").assertExists()
    }

    @Test
    fun aSavedPasswordGoesOnToSignIn() {
        var signIns = 0
        compose.setContent {
            PasswordResetContent(onReset = { _, _ -> }, onDone = {}, onSignIn = { signIns++ })
        }
        tap("passwordReset.save")
        compose.waitForIdle()
        compose.onNodeWithText("Password updated").assertExists()
        tap("passwordReset.done")
        assertEquals(1, signIns)
    }
}
