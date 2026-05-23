package com.surensureshkumar.movemark.core.util

import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.remote.ExportApiException

/**
 * User-visible copy only. Log the original [Throwable] in ViewModels/repos.
 */
object MMUserMessages {
    fun auth(error: Throwable, fallback: String = "Authentication failed. Try again."): String =
        when (error) {
            is AuthException -> error.message?.takeUnless { isTechnical(it) } ?: fallback
            else -> friendly(error, fallback)
        }

    fun createRental(error: Throwable): String =
        friendly(error, "Couldn't create your rental. Try again.")

    fun loadRentals(error: Throwable): String =
        friendly(error, "Couldn't load your rentals. Try again.")

    fun activateRental(error: Throwable): String =
        friendly(error, "Couldn't open this rental. Try again.")

    fun proofSave(error: Throwable): String =
        when {
            error.message?.contains("couldn't upload", ignoreCase = true) == true -> error.message!!
            error.message?.contains("connection", ignoreCase = true) == true ->
                "Photos couldn't upload. Check your connection and try again."
            else -> "Couldn't save proof. Try again."
        }

    fun export(error: Throwable): String = when (error) {
        is ExportApiException -> error.message?.takeUnless { isTechnical(it) }
            ?: "Report couldn't complete. Try again."
        else -> friendly(error, "Report couldn't complete. Try again.")
    }

    fun purchases(error: Throwable): String =
        friendly(error, "Purchases couldn't be restored. Try again.")

    fun plans(error: Throwable): String =
        friendly(error, "Plans didn't load. Try again.")

    fun purchase(error: Throwable): String =
        friendly(error, "Purchase couldn't complete. Try again.")

    fun profile(error: Throwable): String =
        friendly(error, "Couldn't update your profile. Try again.")

    fun passwordReset(error: Throwable): String =
        friendly(error, "Couldn't send reset email. Try again.")

    fun friendly(error: Throwable, fallback: String): String {
        val raw = error.message?.trim().orEmpty()
        if (raw.isEmpty() || isTechnical(raw)) return fallback
        return raw
    }

    fun isTechnical(message: String): Boolean {
        val lower = message.lowercase()
        if (message.length > 120) return true
        val needles = listOf(
            "supabase",
            "ktor",
            "revenuecat",
            "billingclient",
            "json",
            "http",
            "exception",
            "sql",
            "postgres",
            "socket",
            "timeout",
            "unauthorized",
            "401",
            "403",
            "500",
            "serialization",
            "illegalstate",
            "nullpointer",
        )
        return needles.any { lower.contains(it) }
    }
}
