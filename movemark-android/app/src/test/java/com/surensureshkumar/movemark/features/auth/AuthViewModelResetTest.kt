package com.surensureshkumar.movemark.features.auth

import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/** iOS `AuthContainerView` reset / confirmation behaviour, driven through [AuthViewModel] on virtual time. */
@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelResetTest {
    private val dispatcher = StandardTestDispatcher()

    private class FakeActions : AuthActions {
        val resetRequests = mutableListOf<String>()
        var resetError: Exception? = null
        var signUpResult = SignUpResult.SignedIn
        var signUpError: Exception? = null
        var signIns = 0
        var available = true
        override val resetAvailable: Boolean get() = available

        override suspend fun signIn(email: String, password: String) {
            signIns++
        }

        override suspend fun signUp(email: String, password: String): SignUpResult {
            signUpError?.let { throw it }
            return signUpResult
        }

        override suspend fun requestPasswordReset(email: String) {
            resetRequests += email
            resetError?.let { throw it }
        }
    }

    private val actions = FakeActions()

    @Before
    fun setUp() = Dispatchers.setMain(dispatcher)

    @After
    fun tearDown() = Dispatchers.resetMain()

    private fun viewModel() = AuthViewModel(actions)

    @Test
    fun forgotPasswordOpensResetModeAndRememberedItGoesBackToSignIn() {
        val vm = viewModel()
        vm.setPassword("secret123")
        vm.openResetPassword()
        assertEquals(AuthMode.ResetPassword, vm.mode.value)
        assertEquals("", vm.password.value)
        vm.switchMode()
        assertEquals(AuthMode.SignIn, vm.mode.value)
    }

    @Test
    fun withoutAResetPageThereIsNoResetMode() {
        // iOS PasswordResetRequest.isAvailable: no reset page, no "Forgot password?".
        actions.available = false
        val vm = viewModel()
        assertEquals(false, vm.resetAvailable)
        vm.openResetPassword()
        assertEquals(AuthMode.SignIn, vm.mode.value)
        val routed = viewModel()
        routed.start(AuthMode.ResetPassword)
        assertEquals(AuthMode.SignIn, routed.mode.value)
    }

    @Test
    fun startAppliesTheRouteModeOnlyOnce() {
        val vm = viewModel()
        vm.start(AuthMode.ResetPassword)
        vm.switchMode()
        vm.start(AuthMode.ResetPassword)
        assertEquals(AuthMode.SignIn, vm.mode.value)
        assertEquals(AuthMode.ResetPassword, AuthMode.fromRoute("resetPassword"))
        assertEquals(AuthMode.SignUp, AuthMode.fromRoute("signUp"))
        assertEquals(AuthMode.SignIn, AuthMode.fromRoute(null))
    }

    @Test
    fun aSendShowsTheNeutralStateNoSoonerThanTheMinimumThenCountsDown() = runTest(dispatcher) {
        val vm = viewModel()
        vm.openResetPassword()
        vm.setEmail("  renter@example.com ")
        vm.submit()
        assertTrue(vm.loading.value)
        runCurrent()
        assertEquals(listOf("renter@example.com"), actions.resetRequests)
        assertNull(vm.resetSentTo.value)

        advanceTimeBy(PasswordResetRequest.MINIMUM_SEND_MILLIS)
        runCurrent()
        assertEquals("renter@example.com", vm.resetSentTo.value)
        assertFalse(vm.loading.value)
        assertEquals(60, vm.resendCooldown.value)

        advanceTimeBy(1_000)
        runCurrent()
        assertEquals(59, vm.resendCooldown.value)

        // No resend while the cooldown runs.
        vm.resendResetLink()
        runCurrent()
        assertEquals(1, actions.resetRequests.size)

        advanceTimeBy(59_000)
        runCurrent()
        assertEquals(0, vm.resendCooldown.value)

        vm.resendResetLink()
        assertTrue(vm.resending.value)
        advanceTimeBy(PasswordResetRequest.MINIMUM_SEND_MILLIS)
        runCurrent()
        assertEquals(2, actions.resetRequests.size)
        assertFalse(vm.resending.value)
        assertEquals(60, vm.resendCooldown.value)
    }

    @Test
    fun anUnknownAddressAnswersExactlyLikeAKnownOne() = runTest(dispatcher) {
        actions.resetError = NeonAuthException.Rejected("USER_NOT_FOUND", "User not found")
        val vm = viewModel()
        vm.openResetPassword()
        vm.setEmail("nobody@example.com")
        vm.submit()
        advanceUntilIdle()
        assertEquals("nobody@example.com", vm.resetSentTo.value)
        assertNull(vm.message.value)
    }

    @Test
    fun aNetworkFailureStaysOnTheFormWithNoConnection() = runTest(dispatcher) {
        actions.resetError = IOException("Unable to resolve host")
        val vm = viewModel()
        vm.openResetPassword()
        vm.setEmail("renter@example.com")
        vm.submit()
        advanceUntilIdle()
        assertNull(vm.resetSentTo.value)
        assertEquals(PasswordResetRequest.NO_CONNECTION, vm.message.value)
        assertEquals(0, vm.resendCooldown.value)
    }

    @Test
    fun anInvalidEmailIsCaughtBeforeAnythingIsSent() = runTest(dispatcher) {
        val vm = viewModel()
        vm.openResetPassword()
        vm.setEmail("renter@example")
        vm.submit()
        advanceUntilIdle()
        assertEquals("Enter a valid email.", vm.message.value)
        assertTrue(actions.resetRequests.isEmpty())
    }

    @Test
    fun backToSignInKeepsTheAddressAndTheCooldownBlocksAnotherSend() = runTest(dispatcher) {
        val vm = viewModel()
        vm.openResetPassword()
        vm.setEmail("renter@example.com")
        vm.submit()
        advanceTimeBy(PasswordResetRequest.MINIMUM_SEND_MILLIS)
        runCurrent()

        vm.backToSignInFromReset()
        assertEquals(AuthMode.SignIn, vm.mode.value)
        assertEquals("renter@example.com", vm.email.value)
        assertNull(vm.resetSentTo.value)

        vm.openResetPassword()
        vm.submit()
        runCurrent()
        assertEquals("You can send another link in 60s.", vm.info.value)
        assertEquals(1, actions.resetRequests.size)
    }

    @Test
    fun signUpThatNeedsConfirmationShowsCheckYourEmailNotAnError() = runTest(dispatcher) {
        actions.signUpResult = SignUpResult.EmailConfirmationRequired
        val vm = viewModel()
        vm.setMode(AuthMode.SignUp)
        vm.setEmail(" new@example.com ")
        vm.setPassword("longenough")
        vm.setConfirmPassword("longenough")
        vm.submit()
        advanceUntilIdle()
        assertEquals("new@example.com", vm.confirmationEmail.value)
        assertNull(vm.message.value)

        vm.backToSignInAfterConfirmation()
        assertEquals(AuthMode.SignIn, vm.mode.value)
        assertEquals("new@example.com", vm.email.value)
        assertEquals("", vm.password.value)
        assertNull(vm.confirmationEmail.value)
    }

    @Test
    fun signUpErrorsOtherThanConfirmationStillShow() = runTest(dispatcher) {
        actions.signUpError = AuthException("An account with this email already exists. Sign in instead.")
        val vm = viewModel()
        vm.setMode(AuthMode.SignUp)
        vm.setEmail("new@example.com")
        vm.setPassword("longenough")
        vm.setConfirmPassword("longenough")
        vm.submit()
        advanceUntilIdle()
        assertNull(vm.confirmationEmail.value)
        assertEquals("An account with this email already exists. Sign in instead.", vm.message.value)
    }

    @Test
    fun theSessionManagerConfirmationMessageIsRecognised() {
        assertTrue(AuthViewModel.isConfirmationRequired(AuthException("Account created. Confirm your email, then sign in.")))
        assertFalse(AuthViewModel.isConfirmationRequired(AuthException("Enter your email.")))
        assertFalse(AuthViewModel.isConfirmationRequired(IllegalStateException("Account created. Confirm your email, then sign in.")))
    }
}
