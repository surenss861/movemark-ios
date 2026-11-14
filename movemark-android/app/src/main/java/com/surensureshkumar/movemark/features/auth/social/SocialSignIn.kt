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

/**
 * How the renter last signed in, for the acceptance record (iOS `LegalAcceptanceMethod`). Kept on disk so a Google
 * renter who meets the legal step after process death isn't recorded as "email". Not an authority on anything.
 */
object LegalAcceptanceMethod {
    private const val PREFS = "movemark_auth"
    private const val KEY = "last_auth_method"
    private val known = setOf("email", "google", "apple")
    @Volatile private var prefs: android.content.SharedPreferences? = null
    @Volatile private var memory: String = "email"

    fun attach(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    var last: String
        get() = (prefs?.getString(KEY, null) ?: memory).takeIf { it in known } ?: "email"
        set(value) {
            val method = value.takeIf { it in known } ?: "email"
            memory = method
            prefs?.edit()?.putString(KEY, method)?.apply()
        }
}

/** One browser attempt at a time. The Activity reports the return link, and when it comes back without one. */
object SocialBrowserSession {
    private var pending: CompletableDeferred<Uri>? = null
    private var launched = false
    private var lastOffered: String? = null

    /**
     * A return link arrived with no attempt waiting for it: the process (and with it the attempt's challenge) was
     * gone by the time the browser came back. The challenge can't be recovered, so Welcome says to try again
     * instead of doing nothing.
     */
    private val _orphanedReturn = kotlinx.coroutines.flow.MutableStateFlow(false)
    val orphanedReturn: kotlinx.coroutines.flow.StateFlow<Boolean> = _orphanedReturn

    fun clearOrphanedReturn() { _orphanedReturn.value = false }

    /** How the renter last signed in, for the acceptance record. */
    var lastMethod: String
        get() = LegalAcceptanceMethod.last
        set(value) { LegalAcceptanceMethod.last = value }

    suspend fun open(context: Context, url: String): Uri {
        val attempt = CompletableDeferred<Uri>()
        pending = attempt
        launched = false
        _orphanedReturn.value = false
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, Uri.parse(url))
        launched = true
        return try {
            attempt.await()
        } finally {
            if (pending === attempt) pending = null
            launched = false
        }
    }

    /**
     * From `onCreate` and `onNewIntent`. Returns true when the link was this flow's return. The same link offered
     * twice (a recreated Activity re-reading its intent) is ignored the second time.
     */
    fun offer(uri: Uri?): Boolean {
        if (uri == null || !SocialBrowserReturn.isReturn(uri.scheme, uri.host, uri.path)) return false
        val link = uri.toString()
        if (link == lastOffered) return true
        lastOffered = link
        val attempt = pending
        if (attempt != null) attempt.complete(uri) else _orphanedReturn.value = true
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
