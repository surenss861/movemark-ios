package com.surensureshkumar.movemark.features.auth

import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import java.io.IOException

/**
 * The rules behind "Forgot password?" (iOS `PasswordResetRequest`): what counts as a usable email, how a send answers
 * (always the same, whether or not the address has an account), how long before another send, and which failures
 * mean the reset link itself is dead. Kept apart from the screens so they are unit-tested.
 */
object PasswordResetRequest {
    /** Seconds before another link can be sent from the same screen. Neon Auth also throttles server-side. */
    const val RESEND_COOLDOWN_SECONDS = 60

    /**
     * Every send takes at least this long on screen, so how fast the server answered can't hint at whether the
     * address has an account.
     */
    const val MINIMUM_SEND_MILLIS = 1_200L

    const val EXPIRED_LINK_MESSAGE = "This reset link is invalid or has expired. Request a new one."
    const val GENERIC_FAILURE = "Couldn’t send the reset link. Try again."
    const val NO_CONNECTION = "No connection. Check your internet and try again."
    const val RATE_LIMITED = "Too many attempts. Wait a minute, then try again."

    sealed interface Outcome {
        /** Show the neutral "Check your email" state. */
        data object Sent : Outcome

        /** Stay on the form with this message. */
        data class Failed(val message: String) : Outcome
    }

    /** A message when the address can't be sent to as typed, or null when it can. */
    fun validationMessage(email: String): String? {
        val trimmed = email.trim()
        if (trimmed.isEmpty()) return "Enter your email."
        val parts = trimmed.split("@")
        val valid = parts.size == 2 &&
            parts[0].isNotEmpty() &&
            parts[1].contains('.') &&
            !parts[1].startsWith('.') &&
            !parts[1].endsWith('.') &&
            !trimmed.contains(' ')
        return if (valid) null else "Enter a valid email."
    }

    /**
     * How a finished send is shown. An answer that would say the account doesn't exist is shown as sent: the screen
     * must never tell anyone which addresses have a MoveMark account.
     */
    fun outcome(error: Throwable?): Outcome {
        if (error == null) return Outcome.Sent
        return when (error) {
            is IOException -> Outcome.Failed(NO_CONNECTION)
            is NeonAuthException.Rejected -> when (error.code) {
                "USER_NOT_FOUND", "USER_EMAIL_NOT_FOUND", "EMAIL_NOT_FOUND" -> Outcome.Sent
                "RATE_LIMITED" -> Outcome.Failed(RATE_LIMITED)
                "INVALID_EMAIL" -> Outcome.Failed("Enter a valid email.")
                else -> Outcome.Failed(GENERIC_FAILURE)
            }
            is NeonAuthException.NotConfigured -> Outcome.Failed(error.message ?: GENERIC_FAILURE)
            is NeonAuthException -> Outcome.Failed(GENERIC_FAILURE)
            is AuthException -> Outcome.Failed(error.message?.takeIf { it.isNotBlank() } ?: GENERIC_FAILURE)
            else -> Outcome.Failed(GENERIC_FAILURE)
        }
    }

    /**
     * The reset link's token was refused (expired, already used, malformed): a new link is the only way on. Only
     * Neon Auth's own token codes count — a network failure or any other rejection is not "expired".
     */
    fun isRejectedToken(error: Throwable): Boolean {
        val code = (error as? NeonAuthException.Rejected)?.code ?: return false
        return code == "INVALID_TOKEN" || code == "TOKEN_EXPIRED"
    }
}
