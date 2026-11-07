package com.surensureshkumar.movemark.data.backend

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request

/*
 * MoveMark — every authenticated request (Data API and MoveMark API) leaves through here
 * (iOS `MoveMarkAuthenticatedTransport`).
 *
 * Normal path: attach a valid Neon Auth access token ([NeonAuthClient] refreshes it proactively).
 * Backstop: when the server rejects the token itself (stale after sleep, clock skew, early expiry), refresh
 * exactly once — shared by every request that held the same token — and retry the original request exactly
 * once. A second rejection is returned to the caller unchanged; nothing loops.
 *
 * Only a known authentication rejection triggers the backstop (see [isAuthRejection]). RLS 403s, validation
 * errors and every other 4xx pass straight through.
 *
 * Never use this for presigned storage URLs: those carry their own signature, and an extra Authorization
 * header makes Object Storage reject the request.
 */
class AuthenticatedTransport(
    private val tokens: AccessTokenProvider,
    /** Must not carry a cookie jar. */
    private val http: OkHttpClient,
    private val origins: AuthOrigins,
) {
    /** Which host speaks which rejection dialect. Rules apply only to their own origin. */
    data class AuthOrigins(val dataApiHost: String?, val apiHost: String?) {
        companion object {
            fun from(config: BackendConfig) = AuthOrigins(
                dataApiHost = config.dataApiUrl?.host?.lowercase(),
                apiHost = config.apiBaseUrl?.host?.lowercase(),
            )
        }
    }

    suspend fun execute(request: Request): HttpResult {
        val token = tokens.validAccessToken(forceRefresh = false)
        val response = send(request, token)
        if (!isAuthRejection(response.code, response.url.host, response.body, origins)) return response
        val fresh = tokens.refreshedAccessToken(replacing = token)
        return send(request, fresh)
    }

    private suspend fun send(request: Request, token: String): HttpResult =
        http.send(request.newBuilder().header("Authorization", "Bearer $token").build())

    companion object {
        /**
         * Neon Data API messages for a presented token it won't accept, as observed on the dev branch
         * (2026-10-20). The Data API answers these with HTTP 400 and `"code": null` — not 401 — so the message
         * is the only discriminator. A request without a token is a client bug, not a stale token, and is
         * deliberately not listed.
         */
        val DATA_API_TOKEN_REJECTION_PREFIXES = listOf(
            "JWT token has expired", // validly signed, past `exp`
            "signature error", // not verifiable with the current keys (e.g. after key rotation)
        )

        private val json = Json { ignoreUnknownKeys = true }

        /**
         * The MoveMark API's HTTP 401, or the Neon Data API's HTTP 400 whose body is one of the token-rejection
         * messages above — each only from its own origin. Everything else is not an auth rejection.
         */
        fun isAuthRejection(code: Int, host: String, body: ByteArray, origins: AuthOrigins): Boolean {
            val lowerHost = host.lowercase()
            if (code == 401) return lowerHost == origins.apiHost
            if (code != 400 || lowerHost != origins.dataApiHost) return false
            val obj = runCatching { json.parseToJsonElement(body.toString(Charsets.UTF_8)).jsonObject }.getOrNull()
                ?: return false
            // PostgREST errors carry a code (PGRST…/SQLSTATE); Neon's token gate doesn't.
            val errorCode = obj["code"]
            if (errorCode != null && errorCode != JsonNull) return false
            val message = (obj["message"] as? kotlinx.serialization.json.JsonPrimitive)
                ?.takeIf { it.isString }?.jsonPrimitive?.content ?: return false
            return DATA_API_TOKEN_REJECTION_PREFIXES.any { message.startsWith(it) }
        }
    }
}
