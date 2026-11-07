/**
 * @file "Continue with Google / Apple" through Neon Auth's browser flow, as on iOS. Managed Neon Auth ignores native
 *       ID tokens, so: post the provider and keep this attempt's challenge cookie in memory, open a Custom Tab, Neon
 *       returns to account.movemark.ca/auth/return, which hands a single-use verifier to movemark://auth/callback, and
 *       the verifier plus the challenge become the session. Off in Release unless an internal build opts in.
 * @domain onboarding-auth
 * @status wip
 * @see [[SocialSignIn.swift]] — iOS counterpart
 * @see [[Native Social Sign-In]]
 */
package com.surensureshkumar.movemark.features.auth.social

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabsIntent
import com.surensureshkumar.movemark.BuildConfig
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay

enum class SocialProvider(val id: String, val buttonTitle: String) {
    GOOGLE("google", "Continue with Google"),
    APPLE("apple", "Continue with Apple");

    companion object {
        /** Platform order: Google first on Android (Apple first on iOS). */
        val androidOrder = listOf(GOOGLE, APPLE)
        val androidShown = androidOrder
    }
}

sealed class SocialSignInException(message: String) : Exception(message) {
    /** The person closed the browser. Not an error to show. */
    class Cancelled : SocialSignInException("cancelled")
    class Failed(message: String) : SocialSignInException(message)
}

object SocialSignInConfig {
    val isEnabled: Boolean get() = BuildConfig.SOCIAL_SIGN_IN_ENABLED
}

object SocialBrowserReturn {
    /** Must be a Neon Auth trusted domain; custom schemes are refused as a callback. */
    const val CALLBACK_URL = "https://account.movemark.ca/auth/return"
    const val ACCOUNT_CONFLICT_MESSAGE = "This email already has a MoveMark vault. Sign in the way you created it."
    private const val FAILED = "Sign-in didn’t finish. Try again."

    fun isReturn(scheme: String?, host: String?, path: String?): Boolean =
        scheme == "movemark" && host == "auth" && path == "/callback"

    /** The verifier from the return's query. Anything else is a failed sign-in, never a session. */
    fun verifier(verifier: String?, error: String?): String {
        if (!verifier.isNullOrEmpty()) return verifier
        if (BuildConfig.DEBUG) Log.i("SocialSignIn", "browser return error=${error ?: "none"}")
        throw when (error) {
            "access_denied" -> SocialSignInException.Cancelled()
            "account_not_linked" -> SocialSignInException.Failed(ACCOUNT_CONFLICT_MESSAGE)
            else -> SocialSignInException.Failed(FAILED)
        }
    }
}

/** One browser attempt at a time. The Activity reports the return link, and when it comes back without one. */
object SocialBrowserSession {
    private var pending: CompletableDeferred<Uri>? = null
    private var launched = false

    /** How the renter last signed in, for the acceptance record. Not an authority on anything. */
    var lastMethod: String = "email"

    suspend fun open(context: Context, url: String): Uri {
        val attempt = CompletableDeferred<Uri>()
        pending = attempt
        launched = false
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, Uri.parse(url))
        launched = true
        return try {
            attempt.await()
        } finally {
            pending = null
        }
    }

    /** From `onCreate` and `onNewIntent`. Returns true when the link was this flow's return. */
    fun offer(uri: Uri?): Boolean {
        if (uri == null || !SocialBrowserReturn.isReturn(uri.scheme, uri.host, uri.path)) return false
        pending?.complete(uri)
        return true
    }

    /** From `onResume`: back in the app with no return link means the Custom Tab was closed. */
    suspend fun hostResumed() {
        if (!launched) return
        delay(RETURN_GRACE_MILLIS) // the return link is delivered just around resume
        pending?.completeExceptionally(SocialSignInException.Cancelled())
    }

    private const val RETURN_GRACE_MILLIS = 700L
}
