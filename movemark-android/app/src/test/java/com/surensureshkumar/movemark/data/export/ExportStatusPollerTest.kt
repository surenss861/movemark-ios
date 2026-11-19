package com.surensureshkumar.movemark.data.export

import com.surensureshkumar.movemark.data.remote.ExportJobStatus
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class ExportStatusPollerTest {
    private fun row(requestedAt: String) = ExportRow(
        id = UUID.randomUUID(),
        type = ReportReadinessMapper.MOVE_IN_REPORT_TYPE,
        status = ExportJobStatus.Processing,
        verification = ExportVerificationStatus.Processing,
        requestedAt = requestedAt,
        filePath = null,
    )

    @Test
    fun probesNewestActiveExportUntilReady() = runTest {
        val older = row("2026-10-22T09:00:00Z")
        val newer = row("2026-10-22T10:00:00Z")
        var active = listOf(older, newer)
        val probed = mutableListOf<UUID>()
        var readyAfter = 3
        var relists = 0
        val poller = ExportStatusPoller(
            isReady = { probed += it.id; --readyAfter <= 0 },
            intervalMillis = 1_000,
            relistEveryTicks = 100,
        )
        val job = launch { poller.run({ active }, { relists++; active = emptyList() }) }

        advanceTimeBy(3_500)
        assertEquals(listOf(newer.id, newer.id, newer.id), probed)
        assertEquals(1, relists)

        // Nothing in flight: nothing is probed.
        advanceTimeBy(10_000)
        assertEquals(3, probed.size)
        job.cancel()
    }

    @Test
    fun failedProbeRelists() = runTest {
        var relists = 0
        val poller = ExportStatusPoller(isReady = { throw IllegalStateException("export_failed") }, intervalMillis = 1_000)
        val job = launch { poller.run({ listOf(row("x")) }, { relists++ }) }
        advanceTimeBy(1_500)
        assertEquals(1, relists)
        job.cancel()
    }
}
