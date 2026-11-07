package com.surensureshkumar.movemark.core

import android.content.Context
import io.sentry.android.core.SentryAndroid

/**
 * Crash reporting, matching iOS (movemorkApp.swift): Sentry with personal data off, no performance tracing,
 * an environment tag so debug and QA builds never page production, and the release named "1.4.0 (code)".
 * No DSN (local.properties `SENTRY_DSN` empty) means Sentry stays off.
 */
object CrashReporting {
    data class Settings(
        val dsn: String,
        val environment: String,
        val release: String,
        val sendDefaultPii: Boolean = false,
        val tracesSampleRate: Double = 0.0,
        val attachScreenshot: Boolean = false,
        val attachViewHierarchy: Boolean = false,
    )

    /** Null when crash reporting is disabled (no DSN). */
    fun settings(dsn: String, isDebug: Boolean, versionName: String, versionCode: Int): Settings? {
        val trimmed = dsn.trim()
        if (trimmed.isEmpty() || !trimmed.startsWith("https://")) return null
        return Settings(
            dsn = trimmed,
            environment = if (isDebug) "development" else "production",
            release = "$versionName ($versionCode)",
        )
    }

    fun start(context: Context, settings: Settings?) {
        settings ?: return
        SentryAndroid.init(context) { options ->
            options.dsn = settings.dsn
            options.environment = settings.environment
            options.release = settings.release
            options.isSendDefaultPii = settings.sendDefaultPii
            options.tracesSampleRate = settings.tracesSampleRate
            // Screens show evidence photos and addresses: never captured.
            options.isAttachScreenshot = settings.attachScreenshot
            options.isAttachViewHierarchy = settings.attachViewHierarchy
            options.isDebug = false
        }
    }
}
