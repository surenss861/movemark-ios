package com.surensureshkumar.movemark.data.export

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.coroutines.coroutineContext

/**
 * Watches in-flight exports by polling the MoveMark API: `GET /api/exports/{id}/download` answers 409 while the
 * worker is still building the PDF and 200 once it is ready (or 400 `export_failed`). Only the newest in-flight
 * export is probed per tick, which keeps well inside the API's download rate limit (20/min); [onChange] re-lists
 * the exports so every row's status is refreshed from the server.
 */
class ExportStatusPoller(
    private val isReady: suspend (ExportRow) -> Boolean,
    private val intervalMillis: Long = DEFAULT_INTERVAL_MILLIS,
    /** Re-list anyway every this many ticks, so a stuck or failed job still surfaces. */
    private val relistEveryTicks: Int = 5,
) {
    /** Runs until cancelled. [activeExports] is read each tick; nothing is probed while it is empty. */
    suspend fun run(activeExports: () -> List<ExportRow>, onChange: suspend () -> Unit) {
        var ticks = 0
        while (coroutineContext.isActive) {
            delay(intervalMillis)
            val newest = activeExports().maxByOrNull { it.requestedAt.orEmpty() } ?: continue
            ticks++
            val changed = try {
                isReady(newest)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                true // failed on the server, or an unexpected answer: re-list and let the rows say which
            }
            if (changed || ticks % relistEveryTicks == 0) onChange()
        }
    }

    companion object {
        const val DEFAULT_INTERVAL_MILLIS = 5_000L
    }
}
