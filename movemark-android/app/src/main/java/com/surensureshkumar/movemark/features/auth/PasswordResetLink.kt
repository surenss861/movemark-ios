package com.surensureshkumar.movemark.features.auth

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.net.URI
import java.net.URLDecoder

/**
 * A password-reset link (iOS `PasswordResetLink`): `movemark://reset-password?token=…`, the reset page's
 * "Open in the app" button. MainActivity hands each incoming link here; the nav host shows the reset screen.
 *
 * Neon Auth sends a bad or expired link to the reset page as `?error=INVALID_TOKEN`; the page forwards that, and the
 * reset screen opens straight on "Link expired" ([Payload.Invalid]).
 */
object PasswordResetLink {
    /** What a reset link carries into the app. */
    sealed interface Payload {
        /** Set a new password with this token. */
        data class Token(val value: String) : Payload

        /** Neon Auth already judged the link invalid or expired (`error=…` instead of `token=…`). */
        data object Invalid : Payload
    }

    private val _payload = MutableStateFlow<Payload?>(null)
    private val _token = MutableStateFlow<String?>(null)

    /** The reset link waiting to be shown (a token or an already-dead link), or null. */
    val payload: StateFlow<Payload?> = _payload.asStateFlow()

    /** The token of a reset link waiting to be used, or null (also null for a link that carries only an error). */
    val token: StateFlow<String?> = _token.asStateFlow()

    /** Takes [uri] when it is a reset link. Returns whether it was one. */
    fun offer(uri: String?): Boolean {
        val value = payload(uri) ?: return false
        _payload.value = value
        _token.value = (value as? Payload.Token)?.value
        return true
    }

    fun consume() {
        _payload.value = null
        _token.value = null
    }

    /** The token from a `movemark://reset-password` link, or null for any other URL (or a link with only an error). */
    fun token(uri: String?): String? = (payload(uri) as? Payload.Token)?.value

    /**
     * The payload of a `movemark://reset-password` link, or null for any other URL. Parameters are read from the
     * query, then from the fragment (`#token=…`), as iOS.
     */
    fun payload(uri: String?): Payload? {
        if (uri.isNullOrBlank()) return null
        val parsed = runCatching { URI(uri.trim()) }.getOrNull() ?: return null
        if (!parsed.scheme.equals("movemark", ignoreCase = true)) return null
        if (!parsed.host.equals("reset-password", ignoreCase = true)) return null
        val items = parameters(parsed.rawQuery) + parameters(parsed.rawFragment)
        items.firstOrNull { it.first == "token" && it.second.isNotBlank() }?.let { return Payload.Token(it.second) }
        if (items.any { it.first == "error" && it.second.isNotBlank() }) return Payload.Invalid
        return null
    }

    private fun parameters(raw: String?): List<Pair<String, String>> {
        if (raw.isNullOrEmpty()) return emptyList()
        return raw.split('&').map { part ->
            val name = part.substringBefore('=')
            val value = runCatching { URLDecoder.decode(part.substringAfter('=', ""), "UTF-8") }.getOrNull().orEmpty()
            name to value
        }
    }
}
