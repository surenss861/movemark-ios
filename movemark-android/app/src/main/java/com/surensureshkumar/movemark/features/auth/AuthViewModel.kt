package com.surensureshkumar.movemark.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/** The auth surface's modes (iOS `AuthContainerView.Mode`). */
enum class AuthMode {
    SignIn,
    SignUp,

    /** "Forgot password?": email only, sends a reset link. */
    ResetPassword;

    companion object {
        /** The mode for an `auth/{mode}` route argument: "signUp", "resetPassword", anything else signs in. */
        fun fromRoute(mode: String?): AuthMode = when (mode) {
            "signUp" -> SignUp
            "resetPassword" -> ResetPassword
            else -> SignIn
        }
    }
}

enum class SignUpResult {
    SignedIn,

    /** The account exists but Neon Auth wants the address confirmed before there is a session. */
    EmailConfirmationRequired,
}

/** What the auth surface needs from the account layer: [SessionManager] in the app, a fake in tests. */
interface AuthActions {
    suspend fun signIn(email: String, password: String)
    suspend fun signUp(email: String, password: String): SignUpResult

    /** Asks for a reset link. Neon Auth answers the same whether or not the address has an account. */
    suspend fun requestPasswordReset(email: String)
}

private class SessionAuthActions(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
) : AuthActions {
    override suspend fun signIn(email: String, password: String) {
        sessionManager.signIn(email, password)
        sessionManager.userId.value?.let { propertyStore.fetchAll(it) }
    }

    override suspend fun signUp(email: String, password: String): SignUpResult {
        try {
            sessionManager.signUp(email, password)
        } catch (e: AuthException) {
            if (AuthViewModel.isConfirmationRequired(e)) return SignUpResult.EmailConfirmationRequired
            throw e
        }
        sessionManager.userId.value?.let { propertyStore.fetchAll(it) }
        return SignUpResult.SignedIn
    }

    override suspend fun requestPasswordReset(email: String) {
        sessionManager.resetPassword(email)
    }
}

/**
 * Sign in / create account / reset password (iOS `AuthContainerView`). The reset request answers the same whether or
 * not the address has an account ([PasswordResetRequest.outcome]); after a send, another waits out
 * [PasswordResetRequest.RESEND_COOLDOWN_SECONDS].
 */
@HiltViewModel
class AuthViewModel internal constructor(
    private val actions: AuthActions,
    private val minimumSendMillis: Long = PasswordResetRequest.MINIMUM_SEND_MILLIS,
    private val cooldownSeconds: Int = PasswordResetRequest.RESEND_COOLDOWN_SECONDS,
) : ViewModel() {

    @Inject
    constructor(
        sessionManager: SessionManager,
        propertyStore: PropertyStore,
    ) : this(SessionAuthActions(sessionManager, propertyStore))

    private val _mode = MutableStateFlow(AuthMode.SignIn)
    val mode: StateFlow<AuthMode> = _mode.asStateFlow()

    private val _email = MutableStateFlow("")
    val email: StateFlow<String> = _email.asStateFlow()

    private val _password = MutableStateFlow("")
    val password: StateFlow<String> = _password.asStateFlow()

    private val _confirmPassword = MutableStateFlow("")
    val confirmPassword: StateFlow<String> = _confirmPassword.asStateFlow()

    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    /** An error to show on the form (or under the reset-sent block). */
    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    /** Neutral information (iOS `infoMessage`, MMNotice tone .info). */
    private val _info = MutableStateFlow<String?>(null)
    val info: StateFlow<String?> = _info.asStateFlow()

    /** Set when sign-up succeeded but the address must be confirmed first: the form becomes "Check your email". */
    private val _confirmationEmail = MutableStateFlow<String?>(null)
    val confirmationEmail: StateFlow<String?> = _confirmationEmail.asStateFlow()

    /** Set once a reset link was requested: the form becomes the neutral "Check your email" state. */
    private val _resetSentTo = MutableStateFlow<String?>(null)
    val resetSentTo: StateFlow<String?> = _resetSentTo.asStateFlow()

    /** Seconds until another reset link can be sent from this surface. */
    private val _resendCooldown = MutableStateFlow(0)
    val resendCooldown: StateFlow<Int> = _resendCooldown.asStateFlow()

    private val _resending = MutableStateFlow(false)
    val resending: StateFlow<Boolean> = _resending.asStateFlow()

    private var started = false
    private var cooldownJob: Job? = null

    /** The route's mode, applied once: a configuration change must not throw the person out of reset mode. */
    fun start(initial: AuthMode) {
        if (started) return
        started = true
        _mode.value = initial
    }

    fun setMode(value: AuthMode) {
        _mode.value = value
        _message.value = null
        _info.value = null
        if (value == AuthMode.SignIn) _confirmPassword.value = ""
    }

    /** The quiet link under the action: sign in ↔ create, and back to sign in from reset (iOS `switchAuthMode`). */
    fun switchMode() {
        setMode(if (_mode.value == AuthMode.SignIn) AuthMode.SignUp else AuthMode.SignIn)
    }

    /** "Forgot password?" (iOS `openResetPassword`). */
    fun openResetPassword() {
        _mode.value = AuthMode.ResetPassword
        _password.value = ""
        _message.value = null
        _info.value = null
    }

    /** Leaves the confirmation state for sign-in with the address already filled in. */
    fun backToSignInAfterConfirmation() {
        _confirmationEmail.value?.let { _email.value = it }
        _confirmationEmail.value = null
        _mode.value = AuthMode.SignIn
        _password.value = ""
        _confirmPassword.value = ""
        _message.value = null
        _info.value = null
    }

    /** Back to sign in with the address already filled in. A running cooldown keeps counting. */
    fun backToSignInFromReset() {
        _resetSentTo.value?.let { _email.value = it }
        _resetSentTo.value = null
        _mode.value = AuthMode.SignIn
        _message.value = null
        _info.value = null
    }

    fun setEmail(v: String) { _email.value = v }
    fun setPassword(v: String) { _password.value = v }
    fun setConfirmPassword(v: String) { _confirmPassword.value = v }

    fun submit() {
        if (_loading.value) return
        if (_mode.value == AuthMode.ResetPassword) {
            sendResetLink()
            return
        }
        // As iOS: sign-up asks for the password twice and stops on a mismatch before anything is sent.
        if (_mode.value == AuthMode.SignUp && _password.value.isNotEmpty() && _password.value != _confirmPassword.value) {
            _message.value = PASSWORDS_DO_NOT_MATCH
            return
        }
        val current = _mode.value
        _loading.value = true
        _message.value = null
        _info.value = null
        viewModelScope.launch {
            try {
                when (current) {
                    AuthMode.SignUp -> {
                        val result = actions.signUp(_email.value, _password.value)
                        // No session means no account to route into yet: this surface stays up and says why.
                        if (result == SignUpResult.EmailConfirmationRequired) {
                            _confirmationEmail.value = _email.value.trim()
                        }
                    }
                    AuthMode.SignIn -> actions.signIn(_email.value, _password.value)
                    AuthMode.ResetPassword -> Unit
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _message.value = MMUserMessages.auth(e)
            } finally {
                _loading.value = false
            }
        }
    }

    private fun sendResetLink() {
        PasswordResetRequest.validationMessage(_email.value)?.let {
            _message.value = it
            return
        }
        val waiting = _resendCooldown.value
        if (waiting > 0) {
            _info.value = "You can send another link in ${waiting}s."
            return
        }
        val address = _email.value.trim()
        _loading.value = true
        _message.value = null
        _info.value = null
        viewModelScope.launch {
            try {
                when (val outcome = PasswordResetRequest.outcome(timedSend(address))) {
                    PasswordResetRequest.Outcome.Sent -> {
                        startResendCooldown()
                        _resetSentTo.value = address
                    }
                    is PasswordResetRequest.Outcome.Failed -> _message.value = outcome.message
                }
            } finally {
                _loading.value = false
            }
        }
    }

    /** "Resend link" on the reset-sent block; only once the cooldown has run out. */
    fun resendResetLink() {
        val address = _resetSentTo.value ?: return
        if (_resendCooldown.value > 0 || _resending.value) return
        _resending.value = true
        _message.value = null
        viewModelScope.launch {
            try {
                when (val outcome = PasswordResetRequest.outcome(timedSend(address))) {
                    PasswordResetRequest.Outcome.Sent -> startResendCooldown()
                    is PasswordResetRequest.Outcome.Failed -> _message.value = outcome.message
                }
            } finally {
                _resending.value = false
            }
        }
    }

    /** Runs one send and returns its error (null when sent), never sooner than [minimumSendMillis]. */
    private suspend fun timedSend(address: String): Throwable? = coroutineScope {
        val floor = launch { delay(minimumSendMillis) }
        val failure = try {
            actions.requestPasswordReset(address)
            null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            e
        }
        floor.join()
        failure
    }

    private fun startResendCooldown() {
        cooldownJob?.cancel()
        _resendCooldown.value = cooldownSeconds
        cooldownJob = viewModelScope.launch {
            while (_resendCooldown.value > 0) {
                delay(1_000)
                _resendCooldown.value -= 1
            }
        }
    }

    companion object {
        const val PASSWORDS_DO_NOT_MATCH = "Passwords do not match."

        /** What [SessionManager.signUp] throws when Neon Auth created the account but returned no session. */
        const val SIGN_UP_CONFIRMATION_REQUIRED = "Account created. Confirm your email, then sign in."

        fun isConfirmationRequired(error: Throwable): Boolean =
            error is AuthException && error.message == SIGN_UP_CONFIRMATION_REQUIRED
    }
}
