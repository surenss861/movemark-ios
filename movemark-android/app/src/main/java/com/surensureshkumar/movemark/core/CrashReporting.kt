package com.surensureshkumar.movemark.core

import android.content.Context
import android.util.Log
import io.sentry.Breadcrumb
import io.sentry.ITransportFactory
import io.sentry.Sentry
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.transport.ITransport
import io.sentry.transport.RateLimiter
import java.io.ByteArrayOutputStream

/**
 * Crash reporting, matching iOS (movemorkApp.swift): Sentry with personal data off, no performance tracing,
 * an environment tag so debug and QA builds never page production, and the release named "1.4.0 (code)".
 * No DSN (local.properties `SENTRY_DSN` empty) means Sentry stays off.
 *
 * Privacy (see [SentryScrubber]): no user (no id, email, name or IP), no request, no screenshots, view hierarchy,
 * session replay, ANR thread dump or other attachments, no UI-interaction breadcrumbs, and every message,
 * exception value, breadcrumb, tag and extra scrubbed of URLs' queries, tokens, headers, emails and ids.
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
        SentryAndroid.init(context) { options -> configure(options, settings) }
    }

    /** The one configuration, used by [start] and by the debug self-test. */
    fun configure(options: SentryAndroidOptions, settings: Settings) {
        options.dsn = settings.dsn
        options.environment = settings.environment
        options.release = settings.release
        options.isSendDefaultPii = settings.sendDefaultPii
        options.tracesSampleRate = settings.tracesSampleRate
        // Screens show evidence photos and addresses: never captured, in any form.
        options.isAttachScreenshot = settings.attachScreenshot
        options.isAttachViewHierarchy = settings.attachViewHierarchy
        options.isAttachAnrThreadDump = false
        options.sessionReplay.sessionSampleRate = 0.0
        options.sessionReplay.onErrorSampleRate = 0.0
        options.isEnableUserInteractionBreadcrumbs = false
        options.isEnableUserInteractionTracing = false
        options.maxRequestBodySize = io.sentry.SentryOptions.RequestSize.NONE
        // Release-health sessions carry Sentry's per-install id ("did") and bypass beforeSend: off.
        options.isEnableAutoSessionTracking = false
        options.isDebug = false
        options.setBeforeBreadcrumb { breadcrumb, _ -> SentryScrubber.scrub(breadcrumb) }
        options.setBeforeSend { event, _ -> SentryScrubber.scrub(event) }
    }

    // ---- Debug-only evidence: what would actually be sent, with nothing sent ----

    private const val SELF_TEST_TAG = "SentrySelfTest"
    private const val PLACEHOLDER_DSN = "https://0123456789abcdef0123456789abcdef@o0.ingest.invalid/0"

    /**
     * Debug builds only (`adb shell am start -n …/.MainActivity --ez movemark.sentry_selftest true`): restarts Sentry
     * with the production [configure] but a transport that writes each envelope, exactly as it would go on the wire,
     * to logcat (tag SentrySelfTest) and sends nothing. Then records breadcrumbs and an exception full of things that
     * must not leave the phone, and a user that must not be sent.
     */
    fun runSelfTest(context: Context, isDebug: Boolean) {
        if (!isDebug) return
        Sentry.close()
        val settings = Settings(dsn = PLACEHOLDER_DSN, environment = "selftest", release = "selftest")
        SentryAndroid.init(context) { options ->
            configure(options, settings)
            options.setTransportFactory(ITransportFactory { opts, _ -> LogcatTransport(opts) })
        }
        Sentry.setUser(io.sentry.protocol.User().apply {
            id = "d9f0531c-f367-4b6d-9440-a293ff211adc"; email = "renter@example.com"; username = "Alex Tester"; ipAddress = "203.0.113.7"
        })
        Sentry.addBreadcrumb(Breadcrumb.http("https://bucket.example-storage.com/u/9bd1bcc6-4398-49de-85b3-c5f7afe68032/photo.jpg?X-Amz-Signature=abc123&X-Amz-Credential=AKIA", "GET", 200))
        Sentry.addBreadcrumb(Breadcrumb().apply {
            category = "selftest"; message = "POST /api/exports Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0.c2lnbmF0dXJl Cookie: __Secure-neon-auth.session_token=s3cr3t"
            setData("authorization", "Bearer abc"); setData("url", "movemark://auth/callback?neon_auth_session_verifier=v123")
            setData("note", "Rental: 1 Test Lane, renter@example.com")
        })
        Sentry.setExtra("report", "https://reports.example.com/r.pdf?token=t0k3n&expires=1")
        Sentry.captureException(
            java.io.IOException(
                "GET https://bucket.example-storage.com/a.jpg?X-Amz-Signature=deadbeef failed; password=hunter2; " +
                    "refresh_token=r3fr3sh; user renter@example.com; JSON input: {\"address_line_1\":\"1 Test Lane\",\"notes\":\"leak\"}",
            ),
        )
        Sentry.flush(5_000)
        Log.i(SELF_TEST_TAG, "done")
    }

    private class LogcatTransport(private val options: io.sentry.SentryOptions) : ITransport {
        override fun send(envelope: io.sentry.SentryEnvelope, hint: io.sentry.Hint) {
            val out = ByteArrayOutputStream()
            options.serializer.serialize(envelope, out)
            val text = out.toString(Charsets.UTF_8.name())
            Log.i(SELF_TEST_TAG, "envelope ${text.length} bytes, items=${envelope.items.count()}: ${envelope.items.joinToString { it.header.type.itemType }}")
            // Newlines (envelope item separators) become "\u23CE" so each logcat line is one whole chunk.
            text.replace("\n", "\u23CE").chunked(3000).forEachIndexed { i, chunk -> Log.i(SELF_TEST_TAG, "part $i: $chunk") }
        }
        override fun flush(timeoutMillis: Long) = Unit
        override fun getRateLimiter(): RateLimiter? = null
        override fun close(isRestarting: Boolean) = Unit
        override fun close() = Unit
    }

}
