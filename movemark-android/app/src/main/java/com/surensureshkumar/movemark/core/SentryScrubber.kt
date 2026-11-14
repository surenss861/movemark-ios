package com.surensureshkumar.movemark.core

import io.sentry.Breadcrumb
import io.sentry.SentryEvent

/**
 * What may leave the phone in a crash report. Everything text-like in an event or breadcrumb passes through
 * [scrub] before Sentry sends it:
 * - URLs keep scheme, host and path; the query and fragment go (presigned photo/report URLs carry their signature
 *   there, and the social return carries its verifier there).
 * - Authorization / Cookie / Set-Cookie / X-Amz-* header values, Bearer tokens, JWTs, and token=, password=,
 *   signature=, verifier= style pairs are replaced.
 * - Email addresses and UUIDs (user, rental, room and photo ids) are replaced, so the account can't be identified.
 * - kotlinx.serialization's "JSON input: …" excerpt is dropped: it can quote a server row (a rental's address,
 *   notes or a document title).
 * The event's user and request are removed outright: no user id (not even hashed), email, name or IP, and no
 * device id (Sentry's per-install id).
 */
object SentryScrubber {
    private const val R = "[redacted]"

    private val urlWithQuery = Regex("""(https?://[^\s?#"'<>]+)[?#][^\s"'<>]*""", RegexOption.IGNORE_CASE)
    private val headerValue = Regex(
        """(?i)\b(authorization|proxy-authorization|cookie|set-cookie|x-amz-[a-z0-9-]+)(["']?\s*[:=]\s*)("[^"]*"|[^\s,;]+(?:\s+[^\s,;]+)?)""",
    )
    private val bearer = Regex("""(?i)\bbearer\s+[A-Za-z0-9._~+/=-]+""")
    private val jwt = Regex("""\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*""")
    private val secretPair = Regex(
        """(?i)\b([a-z_.-]*(?:token|password|passwd|secret|signature|verifier|credential|session|api[_-]?key)[a-z_.-]*)(["']?\s*[=:]\s*["']?)([^&\s"',;}]+)""",
    )
    private val email = Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}""")
    private val uuid = Regex("""\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b""")
    private val jsonInput = Regex("""(?is)(JSON input:).*""")

    fun scrub(text: String?): String? {
        if (text.isNullOrEmpty()) return text
        var s: String = text
        s = jsonInput.replace(s) { "${it.groupValues[1]} $R" }
        s = urlWithQuery.replace(s) { "${it.groupValues[1]}?$R" }
        s = headerValue.replace(s) { "${it.groupValues[1]}${it.groupValues[2]}$R" }
        s = bearer.replace(s, "Bearer $R")
        s = jwt.replace(s, R)
        s = secretPair.replace(s) { "${it.groupValues[1]}${it.groupValues[2]}$R" }
        s = email.replace(s, "[email]")
        s = uuid.replace(s, "[id]")
        return s
    }

    private fun scrubValue(value: Any?): Any? = when (value) {
        null -> null
        is String -> scrub(value)
        is Number, is Boolean -> value
        is Map<*, *> -> value.entries.associate { (k, v) -> k.toString() to scrubValue(v) }
        is Collection<*> -> value.map(::scrubValue)
        else -> scrub(value.toString())
    }

    /**
     * Breadcrumb data keys the SDK itself writes (lifecycle, connectivity, system and HTTP breadcrumbs) that hold
     * only technical values. Anything else is dropped: free text can't be recognised by pattern (a rental's
     * address or notes would pass every rule above), and the app adds no breadcrumbs of its own. `http.query` and
     * `http.fragment` are not here: the query is where presigned URLs carry their signature.
     */
    private val allowedDataKeys = setOf(
        "method", "status_code", "url", "reason", "state", "screen", "action",
        "network_type", "vpn_active", "signal_strength", "download_bandwidth", "upload_bandwidth",
        "level", "charging", "plugged", "orientation", "battery_level",
    )

    /** beforeBreadcrumb: the message scrubbed, data reduced to [allowedDataKeys] and each value scrubbed. */
    fun scrub(breadcrumb: Breadcrumb): Breadcrumb {
        breadcrumb.message = scrub(breadcrumb.message)
        val data = breadcrumb.data
        for (key in data.keys.toList()) {
            if (key !in allowedDataKeys) breadcrumb.removeData(key)
            else breadcrumb.setData(key, scrubValue(data[key]) ?: "")
        }
        return breadcrumb
    }

    /** beforeSend: no user, no request; message, exceptions, breadcrumbs, tags and extras scrubbed. */
    fun scrub(event: SentryEvent): SentryEvent {
        event.user = null
        event.request = null
        event.serverName = null
        // Sentry's random per-install id: dropped, so no device identifier leaves the phone either.
        event.contexts.device?.id = null
        event.message?.let { m ->
            m.message = scrub(m.message)
            m.formatted = scrub(m.formatted)
            m.params = m.params?.map { scrub(it) ?: "" }
        }
        event.exceptions?.forEach { e -> e.value = scrub(e.value) }
        event.breadcrumbs?.forEach { scrub(it) }
        event.tags?.let { tags -> tags.keys.toList().forEach { k -> event.setTag(k, scrub(tags[k]) ?: "") } }
        event.extras?.let { extras -> event.setExtras(extras.mapValues { (_, v) -> scrubValue(v) }) }
        event.transaction = scrub(event.transaction)
        return event
    }
}
