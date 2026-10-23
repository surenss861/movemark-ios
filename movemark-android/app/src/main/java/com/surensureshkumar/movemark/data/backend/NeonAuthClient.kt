package com.surensureshkumar.movemark.data.backend

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import okhttp3.Cookie
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.Base64

/*
 * MoveMark — the one place that talks to Neon Auth (Managed Better Auth) and owns the session
 * (iOS `NeonAuthClient`).
 *
 * Two credentials, kept apart on purpose:
 * - the session cookie (7 days, Keystore-encrypted, this device only) proves the sign-in;
 * - the access token (Ed25519 JWT, 15 minutes, memory only) is what the Data API and the MoveMark API
 *   accept. It is minted from the cookie by `GET /token` and refreshed here, once, for every caller —
 *   repositories never see expiry or refresh.
 *
 * Email/password only; no OAuth.
 */

@Serializable
data class NeonAuthUser(val id: String, val email: String)

sealed class NeonAuthException(message: String) : Exception(message) {
    class NotConfigured : NeonAuthException("This build is not configured to reach MoveMark’s servers.")

    /** No session, or the server no longer accepts it. The user must sign in again. */
    class SessionExpired : NeonAuthException("Your session has ended. Sign in again.")

    /** Neon Auth answered with an error the user can act on. */
    class Rejected(val code: String?, serverMessage: String) : NeonAuthException(userMessage(code, serverMessage))

    class InvalidResponse : NeonAuthException("Couldn’t reach MoveMark. Try again.")

    private companion object {
        fun userMessage(code: String?, message: String): String = when (code) {
            "INVALID_EMAIL_OR_PASSWORD" -> "Email or password is incorrect."
            "USER_ALREADY_EXISTS", "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL" ->
                "An account with this email already exists. Sign in instead."
            "PASSWORD_TOO_SHORT" -> "Password is too short."
            "PASSWORD_TOO_LONG" -> "Password is too long."
            "INVALID_EMAIL" -> "Enter a valid email."
            else -> message.ifEmpty { "Couldn’t reach MoveMark. Try again." }
        }
    }
}

/** The token operations [AuthenticatedTransport] needs ([NeonAuthClient] in the app; a fake in tests). */
interface AccessTokenProvider {
    suspend fun validAccessToken(forceRefresh: Boolean = false): String
    suspend fun refreshedAccessToken(replacing: String): String
}

class NeonAuthClient(
    private val baseUrl: HttpUrl?,
    /** Must not carry a cookie jar: the one session cookie is handled by hand so it never leaks into other requests. */
    private val http: OkHttpClient,
    private val storage: NeonAuthSessionStorage,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) : AccessTokenProvider {

    @Serializable
    private data class Stored(val cookieName: String, val cookieValue: String, val user: NeonAuthUser? = null) {
        val cookieHeader: String get() = "$cookieName=$cookieValue"
    }

    private class AccessToken(val value: String, val refreshAfterMillis: Long)

    private val json = Json { ignoreUnknownKeys = true }
    private val lock = Mutex()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var stored: Stored? = null
    private var loadedFromStorage = false
    private var accessToken: AccessToken? = null
    private var refresh: Deferred<String>? = null

    private val _sessionExpired = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    /** Emits when Neon Auth rejected the stored session and it was forgotten (not on a user sign-out). */
    val sessionExpired: SharedFlow<Unit> = _sessionExpired.asSharedFlow()

    // ---- Session ----

    /** The signed-in user persisted on this device, if any. Does not touch the network. */
    suspend fun currentUser(): NeonAuthUser? = lock.withLock {
        loadIfNeeded()
        stored?.user
    }

    /**
     * A valid access token, minting a new one when the cached token is close to expiry. Concurrent callers
     * share one refresh. Throws [NeonAuthException.SessionExpired] only when Neon Auth rejects the session
     * itself — a network failure is thrown as-is and never signs anyone out.
     */
    override suspend fun validAccessToken(forceRefresh: Boolean): String {
        val task = lock.withLock {
            loadIfNeeded()
            if (stored == null) throw NeonAuthException.SessionExpired()
            val cached = accessToken
            if (!forceRefresh && cached != null && cached.refreshAfterMillis > nowMillis()) return cached.value
            refresh ?: startRefresh()
        }
        return await(task)
    }

    /**
     * The backstop after a server rejected [replacing]: one refresh for everyone holding that token. When
     * several requests were rejected with the same stale token, only the first refreshes; the rest find a
     * newer token already cached, or join the refresh in flight.
     */
    override suspend fun refreshedAccessToken(replacing: String): String {
        val task = lock.withLock {
            loadIfNeeded()
            if (stored == null) throw NeonAuthException.SessionExpired()
            accessToken?.takeIf { it.value != replacing }?.let { return it.value }
            refresh ?: startRefresh()
        }
        return await(task)
    }

    private fun startRefresh(): Deferred<String> = scope.async { mintAccessToken() }.also { refresh = it }

    private suspend fun await(task: Deferred<String>): String = try {
        task.await()
    } finally {
        lock.withLock { if (refresh === task) refresh = null }
    }

    private suspend fun mintAccessToken(): String {
        val base = baseUrl ?: throw NeonAuthException.NotConfigured()
        val session = lock.withLock { stored } ?: throw NeonAuthException.SessionExpired()
        val request = Request.Builder()
            .url(base.resolvePath("token"))
            .header("Cookie", session.cookieHeader)
            .get()
            .build()
        val response = http.send(request)
        if (response.code == 401 || response.code == 403) {
            Log.i(TAG, "session rejected by Neon Auth (HTTP ${response.code}); signing out locally")
            // This runs inside the refresh itself: forget the session without cancelling it, so every
            // caller waiting on it gets SessionExpired rather than a cancellation.
            endSessionLocally(notify = true, cancelRefresh = false)
            throw NeonAuthException.SessionExpired()
        }
        val token = if (response.code == 200) {
            runCatching { json.parseToJsonElement(response.bodyString()).jsonObject["token"]?.jsonPrimitive?.content }
                .getOrNull()
        } else {
            null
        }
        val lifetime = token?.let(::lifetimeSecondsOfJwt) ?: throw NeonAuthException.InvalidResponse()
        // Expiry is measured on this device's clock from the token's own lifetime, so a skewed clock
        // can't make a fresh token look expired (or an old one look fresh).
        val refreshAfter = nowMillis() + maxOf(30L, lifetime - REFRESH_LEEWAY_SECONDS) * 1000
        lock.withLock { accessToken = AccessToken(token, refreshAfter) }
        return token
    }

    // ---- Sign up / in / out ----

    /** Null when the account was created but Neon Auth issued no session (email verification required). */
    suspend fun signUp(email: String, password: String): NeonAuthUser? {
        val body = post("sign-up/email", mapOf("email" to email, "password" to password, "name" to ""), storeSession = true)
        if (lock.withLock { stored } == null) return null
        return finishSignIn(body)
    }

    suspend fun signIn(email: String, password: String): NeonAuthUser {
        val body = post("sign-in/email", mapOf("email" to email, "password" to password), storeSession = true)
        return finishSignIn(body)
    }

    private suspend fun finishSignIn(body: String): NeonAuthUser {
        val user = runCatching {
            val obj = json.parseToJsonElement(body).jsonObject["user"]!!.jsonObject
            NeonAuthUser(
                id = obj["id"]!!.jsonPrimitive.content.lowercase(),
                email = obj["email"]!!.jsonPrimitive.content,
            )
        }.getOrNull()
        val saved = lock.withLock {
            val session = stored ?: return@withLock false
            if (user == null) return@withLock false
            stored = session.copy(user = user).also { storage.save(json.encodeToString(Stored.serializer(), it)) }
            true
        }
        if (!saved || user == null) {
            endSessionLocally(notify = false)
            throw NeonAuthException.InvalidResponse()
        }
        // Prove the session can mint a token before the UI treats the user as signed in.
        validAccessToken(forceRefresh = true)
        return user
    }

    /** Revokes the session server-side when possible; always clears it locally (offline sign-out works). */
    suspend fun signOut() {
        val session = lock.withLock {
            loadIfNeeded()
            stored
        }
        val base = baseUrl
        if (session != null && base != null) {
            val request = Request.Builder()
                .url(base.resolvePath("sign-out"))
                .header("Cookie", session.cookieHeader)
                .header("Origin", base.origin())
                .post("{}".toRequestBody(JSON_MEDIA))
                .build()
            runCatching { http.send(request) }
        }
        endSessionLocally(notify = false)
    }

    /** Forgets the session on this device (account deleted, session rejected, or sign-out). */
    suspend fun endSessionLocally(notify: Boolean, cancelRefresh: Boolean = true) {
        lock.withLock {
            if (cancelRefresh) refresh?.cancel()
            refresh = null
            accessToken = null
            stored = null
            loadedFromStorage = true
            storage.clear()
        }
        if (notify) _sessionExpired.tryEmit(Unit)
    }

    // ---- Password reset ----

    /** Emails a reset link. Answers the same whether or not the address has an account. */
    suspend fun requestPasswordReset(email: String) {
        post("request-password-reset", mapOf("email" to email), storeSession = false)
    }

    // ---- HTTP ----

    private suspend fun post(path: String, fields: Map<String, String>, storeSession: Boolean): String {
        val base = baseUrl ?: throw NeonAuthException.NotConfigured()
        val url = base.resolvePath(path)
        val payload = JsonObject(fields.mapValues { JsonPrimitive(it.value) }).toString()
        val request = Request.Builder()
            .url(url)
            .header("Origin", base.origin())
            .post(payload.toRequestBody(JSON_MEDIA))
            .build()
        val response = http.send(request)
        if (!response.isSuccessful) {
            val err = runCatching { json.parseToJsonElement(response.bodyString()).jsonObject }.getOrNull()
            val code = err?.get("code")?.jsonPrimitive?.contentOrNull
            Log.i(TAG, "$path failed HTTP ${response.code} code=${code ?: "-"}")
            throw NeonAuthException.Rejected(code, err?.get("message")?.jsonPrimitive?.contentOrNull.orEmpty())
        }
        if (storeSession) {
            val cookie = response.headers.values("Set-Cookie")
                .mapNotNull { Cookie.parse(url, it) }
                .firstOrNull { it.name.endsWith("session_token") && it.value.isNotEmpty() }
            lock.withLock {
                accessToken = null
                loadedFromStorage = true
                stored = cookie?.let { Stored(it.name, it.value) }
            }
        }
        return response.bodyString()
    }

    /** Caller holds [lock]. */
    private fun loadIfNeeded() {
        if (loadedFromStorage) return
        loadedFromStorage = true
        stored = storage.load()?.let { raw -> runCatching { json.decodeFromString(Stored.serializer(), raw) }.getOrNull() }
        // A cookie without a user means sign-in never finished; don't resurrect it.
        if (stored?.user == null) {
            stored = null
            storage.clear()
        }
    }

    internal companion object {
        const val TAG = "NeonAuth"

        /** Refresh this long before the token's own expiry, so a request never leaves with a token that dies in flight. */
        const val REFRESH_LEEWAY_SECONDS = 90L

        val JSON_MEDIA = "application/json".toMediaType()

        /** Seconds between `iat` and `exp`; the signature is the server's business, not the client's. */
        fun lifetimeSecondsOfJwt(token: String): Long? {
            val parts = token.split('.')
            if (parts.size != 3) return null
            return runCatching {
                val payload = String(Base64.getUrlDecoder().decode(parts[1].trimEnd('=')), Charsets.UTF_8)
                val claims = Json.parseToJsonElement(payload).jsonObject
                val iat = claims["iat"]?.jsonPrimitive?.longOrNull ?: return null
                val exp = claims["exp"]?.jsonPrimitive?.longOrNull ?: return null
                (exp - iat).takeIf { it > 0 }
            }.getOrNull()
        }
    }
}
