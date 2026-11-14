package com.surensureshkumar.movemark.core

import io.sentry.Breadcrumb
import io.sentry.SentryEvent
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.Message
import io.sentry.protocol.SentryException
import io.sentry.protocol.User
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Nothing secret, personal or rental-specific survives into a crash report. */
class SentryScrubberTest {
    private val leaks = listOf(
        "X-Amz-Signature", "deadbeef", "AKIA", "hunter2", "r3fr3sh", "eyJhbGci", "s3cr3t", "v123", "t0k3n",
        "renter@example.com", "1 Test Lane", "9bd1bcc6-4398-49de-85b3-c5f7afe68032", "abc123",
    )

    private fun assertClean(text: String?) {
        val t = text.orEmpty()
        leaks.forEach { assertFalse("leaked '$it' in: $t", t.contains(it, ignoreCase = true)) }
    }

    @Test fun presignedUrlsKeepHostAndPathOnly() {
        val s = SentryScrubber.scrub("GET https://bucket.example.com/u/a.jpg?X-Amz-Signature=deadbeef&X-Amz-Credential=AKIA failed")!!
        assertEquals("GET https://bucket.example.com/u/a.jpg?[redacted] failed", s)
    }

    @Test fun tokensHeadersPasswordsAndVerifiers() {
        listOf(
            "Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0.c2lnbmF0dXJl",
            "Cookie: __Secure-neon-auth.session_token=s3cr3t",
            "password=hunter2&refresh_token=r3fr3sh",
            "movemark://auth/callback?neon_auth_session_verifier=v123",
            "{\"token\":\"t0k3n\"}",
            "token eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0.c2lnbmF0dXJl",
        ).forEach { assertClean(SentryScrubber.scrub(it)) }
    }

    @Test fun emailsIdsAndServerJsonExcerpts() {
        val s = SentryScrubber.scrub(
            "user renter@example.com rental 9bd1bcc6-4398-49de-85b3-c5f7afe68032 " +
                "Unexpected JSON token at offset 3: JSON input: {\"address_line_1\":\"1 Test Lane\"}",
        )
        assertClean(s)
        assertTrue(s!!.contains("[email]") && s.contains("[id]") && s.contains("JSON input: [redacted]"))
    }

    @Test fun ordinaryTextIsUntouched() {
        val s = "Data API request failed (HTTP 400, PGRST116) at https://api.example.com/rest/v1/properties"
        assertEquals(s, SentryScrubber.scrub(s))
    }

    @Test fun eventLosesUserAndRequestAndEverythingIsScrubbed() {
        val event = SentryEvent().apply {
            user = User().apply { id = "u1"; email = "renter@example.com"; username = "Alex"; ipAddress = "203.0.113.7" }
            contexts.setDevice(io.sentry.protocol.Device().apply { id = "install-id"; model = "Pixel" })
            request = io.sentry.protocol.Request().apply { url = "https://x.example.com/?token=t0k3n"; cookies = "s3cr3t" }
            message = Message().apply { message = "password=hunter2"; formatted = "password=hunter2" }
            exceptions = listOf(SentryException().apply { value = "GET https://b.example.com/a.jpg?X-Amz-Signature=deadbeef" })
            breadcrumbs = listOf(Breadcrumb().apply { message = "Bearer abc123"; setData("authorization", "Bearer abc123"); setData("url", "https://r.example.com/r.pdf?token=t0k3n") })
            setTag("where", "renter@example.com")
            setExtra("report", "https://r.example.com/r.pdf?token=t0k3n")
        }
        val out = SentryScrubber.scrub(event)
        assertNull(out.user)
        assertNull(out.request)
        assertNull(out.contexts.device!!.id)
        assertEquals("Pixel", out.contexts.device!!.model)
        assertClean(out.message?.message); assertClean(out.message?.formatted)
        assertClean(out.exceptions!!.single().value)
        val crumb = out.breadcrumbs!!.single()
        assertClean(crumb.message); assertNull(crumb.getData("authorization")); assertClean(crumb.getData("url") as String)
        assertClean(out.getTag("where")); assertClean(out.getExtra("report") as String)
    }

    @Test fun breadcrumbDataKeepsOnlyTechnicalKeys() {
        val crumb = SentryScrubber.scrub(Breadcrumb.http("https://b.example.com/a.jpg?X-Amz-Signature=deadbeef", "GET", 200).apply {
            setData("note", "Rental: 1 Test Lane")
        })
        assertNull(crumb.getData("http.query"))
        assertNull(crumb.getData("note"))
        assertEquals("GET", crumb.getData("method"))
        assertEquals("https://b.example.com/a.jpg", crumb.getData("url"))
    }

    @Test fun configurationTurnsEveryCaptureOff() {
        val settings = CrashReporting.settings("https://key@o1.ingest.us.sentry.io/2", false, "1.4.0", 2026111302)!!
        val options = SentryAndroidOptions()
        CrashReporting.configure(options, settings)
        assertFalse(options.isSendDefaultPii)
        assertFalse(options.isAttachScreenshot)
        assertFalse(options.isAttachViewHierarchy)
        assertFalse(options.isAttachAnrThreadDump)
        assertFalse(options.isEnableUserInteractionBreadcrumbs)
        assertEquals(0.0, options.sessionReplay.sessionSampleRate!!, 0.0)
        assertEquals(0.0, options.sessionReplay.onErrorSampleRate!!, 0.0)
        assertEquals(0.0, options.tracesSampleRate!!, 0.0)
        assertEquals(io.sentry.SentryOptions.RequestSize.NONE, options.maxRequestBodySize)
        assertFalse("sessions carry the per-install id", options.isEnableAutoSessionTracking)
        val crumb = options.beforeBreadcrumb!!.execute(Breadcrumb().apply { message = "Bearer abc123" }, io.sentry.Hint())
        assertClean(crumb?.message)
        val event = options.beforeSend!!.execute(SentryEvent().apply { user = User().apply { email = "renter@example.com" } }, io.sentry.Hint())
        assertNull(event!!.user)
    }
}
