package com.surensureshkumar.movemark.features.auth

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.net.URI
import java.net.URLDecoder

/**
 * A password-reset link (iOS `PasswordResetLink`): `movemark://reset-password?token=…`, the reset page's
 * "Open in the app" button. MainActivity hands each incoming link here; the nav host shows the reset screen.
 */
object PasswordResetLink {
    private val _token = MutableStateFlow<String?>(null)

    /** The token of a reset link waiting to be used, or null. */
    val token: StateFlow<String?> = _token.asStateFlow()

    /** Takes [uri] when it is a reset link. Returns whether it was one. */
    fun offer(uri: String?): Boolean {
        val value = token(uri) ?: return false
        _token.value = value
        return true
    }

    fun consume() {
        _token.value = null
    }

    /** The token from a `movemark://reset-password` link, or null for any other URL. */
    fun token(uri: String?): String? {
        if (uri.isNullOrBlank()) return null
        val parsed = runCatching { URI(uri.trim()) }.getOrNull() ?: return null
        if (!parsed.scheme.equals("movemark", ignoreCase = true)) return null
        if (!parsed.host.equals("reset-password", ignoreCase = true)) return null
        return parsed.rawQuery.orEmpty().split('&')
            .map { it.substringBefore('=') to it.substringAfter('=', "") }
            .firstOrNull { it.first == "token" }
            ?.second
            ?.let { runCatching { URLDecoder.decode(it, "UTF-8") }.getOrNull() }
            ?.takeIf { it.isNotBlank() }
    }
}
