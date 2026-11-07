package com.surensureshkumar.movemark.features.auth.social

import android.app.Activity
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.surensureshkumar.movemark.BuildConfig
import com.surensureshkumar.movemark.data.backend.NeonAuthClient
import com.surensureshkumar.movemark.data.backend.NeonAuthSessionStorage
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import java.security.MessageDigest
import java.security.SecureRandom

/*
 * MoveMark — "Continue with Google / Apple" (feature/social-welcome; iOS SocialSignIn.swift).
 *
 * Gated, on purpose:
 * - Release builds hard-code SOCIAL_PROBE_AUTH_URL to "", so the block never shows.
 * - Debug builds show it only when local.properties names the isolated probe project (SOCIAL_PROBE_AUTH_URL).
 *   A probe sign-in uses its own client with in-memory storage. It reports the Neon user id and email (never
 *   a token), then signs out of the probe. It never becomes the app session.
 *
 * The app session stays email/password until the probe has proven:
 * - native token acceptance;
 * - no implicit linking to an existing same-email account;
 * - the same user id across iOS and Android.
 */

enum class SocialProvider(val id: String, val buttonTitle: String) {
    GOOGLE("google", "Continue with Google"),
    APPLE("apple", "Continue with Apple");

    companion object {
        /** Platform order: Google first on Android (Apple first on iOS). */
        val androidOrder = listOf(GOOGLE, APPLE)

        /**
         * What the Android welcome shows. Apple is left out until its browser flow exists: a control that can't
         * sign anyone in must not look usable.
         */
        val androidShown = androidOrder.filter { it != APPLE }
    }
}

/** An OIDC ID token plus the nonce exactly as it appears in the token's `nonce` claim. Never logged or stored. */
class SocialIdentityToken(val provider: SocialProvider, val idToken: String, val nonce: String?)

sealed class SocialSignInException(message: String) : Exception(message) {
    /** The person dismissed the sheet. Not an error to show. */
    class Cancelled : SocialSignInException("cancelled")
    class ProviderUnavailable(provider: SocialProvider) : SocialSignInException(
        if (provider == SocialProvider.APPLE) "Apple sign-in isn’t available in this build yet."
        else "Google sign-in isn’t available in this build yet.",
    )
    class Failed(message: String) : SocialSignInException(message)
}

object SocialSignInConfig {
    /** Debug + probe only (see the file header). */
    val probeAuthUrl: HttpUrl? by lazy {
        validatedProbeUrl(BuildConfig.SOCIAL_PROBE_AUTH_URL, BuildConfig.NEON_AUTH_URL.toHttpUrlOrNull())
    }

    val isEnabled: Boolean get() = BuildConfig.DEBUG && probeAuthUrl != null

    /** HTTPS, a Neon Auth host, and never the app's own auth (dev or production) URL. */
    fun validatedProbeUrl(raw: String?, appAuthUrl: HttpUrl?): HttpUrl? {
        val url = raw?.trim()?.takeIf { it.isNotEmpty() }?.toHttpUrlOrNull() ?: return null
        val host = url.host.lowercase()
        if (!url.isHttps || !host.contains(".neonauth.") || !host.endsWith(".neon.tech")) return null
        if (appAuthUrl != null && appAuthUrl.host.lowercase() == host) return null
        return url
    }
}

/** Gets an ID token from a provider's native UI. */
fun interface SocialCredentialProvider {
    suspend fun credential(activity: Activity, provider: SocialProvider): SocialIdentityToken
}

/** Google through Credential Manager ("Sign in with Google" sheet). Apple waits on the probe's browser-flow check. */
class NativeSocialCredentialProvider(
    private val googleWebClientId: String = BuildConfig.GOOGLE_WEB_CLIENT_ID,
) : SocialCredentialProvider {

    override suspend fun credential(activity: Activity, provider: SocialProvider): SocialIdentityToken = when (provider) {
        SocialProvider.GOOGLE -> google(activity)
        SocialProvider.APPLE -> throw SocialSignInException.ProviderUnavailable(SocialProvider.APPLE)
    }

    private suspend fun google(activity: Activity): SocialIdentityToken {
        if (googleWebClientId.isBlank()) throw SocialSignInException.ProviderUnavailable(SocialProvider.GOOGLE)
        // Google signs the nonce into the token as given, so the claim and the request value are the same string.
        val nonce = randomNonce()
        val option = GetSignInWithGoogleOption.Builder(googleWebClientId).setNonce(nonce).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val result = try {
            CredentialManager.create(activity).getCredential(activity, request)
        } catch (e: GetCredentialCancellationException) {
            throw SocialSignInException.Cancelled()
        } catch (e: GetCredentialException) {
            Log.i(TAG, "google credential failed type=${e.type}")
            throw SocialSignInException.Failed("Google sign-in didn’t finish. Try again.")
        }
        val credential = result.credential
        if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw SocialSignInException.Failed("Google didn’t return a sign-in token. Try again.")
        }
        val idToken = GoogleIdTokenCredential.createFrom(credential.data).idToken
        return SocialIdentityToken(SocialProvider.GOOGLE, idToken, nonce)
    }

    companion object {
        private const val TAG = "SocialSignIn"
        private const val CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"

        fun randomNonce(length: Int = 32): String {
            val random = SecureRandom()
            return String(CharArray(length) { CHARSET[random.nextInt(CHARSET.length)] })
        }

        fun sha256Hex(input: String): String =
            MessageDigest.getInstance("SHA-256").digest(input.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}

/** Probe result shown to QA: identity only, never a token. */
data class SocialProbeResult(val provider: SocialProvider, val userId: String, val email: String)

/** The probe session lives only in memory: nothing is written to the app's Keystore-backed session. */
class InMemoryProbeSessionStorage : NeonAuthSessionStorage {
    private var value: String? = null
    override fun load(): String? = value
    override fun save(value: String) { this.value = value }
    override fun clear() { value = null }
}

/** Runs one social sign-in against the isolated probe, reports the identity, then signs out of the probe. */
class SocialProbeRunner(
    private val credentials: SocialCredentialProvider = NativeSocialCredentialProvider(),
    private val makeClient: (HttpUrl) -> NeonAuthClient = { url ->
        NeonAuthClient(url, OkHttpClient(), InMemoryProbeSessionStorage())
    },
) {
    suspend fun run(activity: Activity, provider: SocialProvider, probeUrl: HttpUrl): SocialProbeResult {
        val token = credentials.credential(activity, provider)
        val client = makeClient(probeUrl)
        try {
            val user = client.signInSocial(token.provider.id, token.idToken, token.nonce)
            client.signOut()
            return SocialProbeResult(provider, user.id, user.email)
        } catch (e: Exception) {
            client.endSessionLocally(notify = false)
            throw e
        }
    }
}
