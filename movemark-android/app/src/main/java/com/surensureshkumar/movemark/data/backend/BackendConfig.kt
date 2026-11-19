package com.surensureshkumar.movemark.data.backend

import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/**
 * MoveMark backend endpoints (iOS `MoveMarkBackendConfig`). Release builds carry the production values
 * from build.gradle.kts; debug builds read `NEON_AUTH_URL`, `NEON_DATA_API_URL` and `MOVEMARK_API_BASE_URL`
 * from local.properties. The app never holds database or storage credentials: rows go through the Neon
 * Data API under row-level security with the user's own token, files through the MoveMark API.
 */
data class BackendConfig(
    /** Neon Auth base, e.g. `https://ep-….neonauth.<region>.aws.neon.tech/neondb/auth`. */
    val neonAuthUrl: HttpUrl?,
    /** Neon Data API (PostgREST-compatible), e.g. `https://ep-….apirest.<region>.aws.neon.tech/neondb/rest/v1`. */
    val dataApiUrl: HttpUrl?,
    /** MoveMark API (FastAPI on Railway). */
    val apiBaseUrl: HttpUrl?,
) {
    /** False when any endpoint is missing or not a usable HTTP(S) URL; the UI gates on this instead of crashing. */
    val isConfigured: Boolean get() = neonAuthUrl != null && dataApiUrl != null && apiBaseUrl != null

    companion object {
        fun from(neonAuthUrl: String, dataApiUrl: String, apiBaseUrl: String) = BackendConfig(
            neonAuthUrl = parse(neonAuthUrl),
            dataApiUrl = parse(dataApiUrl),
            apiBaseUrl = parse(apiBaseUrl),
        )

        private fun parse(raw: String): HttpUrl? =
            raw.trim().takeIf { it.isNotEmpty() }?.toHttpUrlOrNull()?.takeIf { it.host.isNotEmpty() }
    }
}

/** Appends `/`-separated [path] segments to [this] (which may itself end in a path, e.g. `/neondb/auth`). */
fun HttpUrl.resolvePath(path: String): HttpUrl {
    val builder = newBuilder()
    // A trailing slash leaves an empty last segment; drop it so segments don't double up.
    if (pathSegments.lastOrNull() == "") builder.removePathSegment(pathSegments.size - 1)
    path.split('/').filter { it.isNotEmpty() }.forEach { builder.addPathSegment(it) }
    return builder.build()
}

/** `scheme://host[:port]` — what Neon Auth expects in the Origin header (iOS sends the same). */
internal fun HttpUrl.origin(): String {
    val defaultPort = HttpUrl.defaultPort(scheme)
    return if (port == defaultPort) "$scheme://$host" else "$scheme://$host:$port"
}
