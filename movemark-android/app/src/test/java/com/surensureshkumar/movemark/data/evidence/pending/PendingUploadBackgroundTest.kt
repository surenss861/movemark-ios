package com.surensureshkumar.movemark.data.evidence.pending

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

/** The background pass over the real store and the modelled server: only asked-for saves, each photo exactly once. */
class PendingUploadBackgroundTest {
    @get:Rule val tmp = TemporaryFolder()

    private class RecordingScheduler : PendingUploadScheduler {
        val scheduled = mutableListOf<String>()
        val cancelled = mutableListOf<String>()
        override fun schedule(userId: String) { scheduled += userId }
        override fun cancel(userId: String) { cancelled += userId }
    }

    private val root get() = File(tmp.root, "pending")
    private val user = testKey.userId
    private val scheduler = RecordingScheduler()

    /** A fresh center per call: every call behaves like a new process over the same files. */
    private fun center(server: FakeServer, io: kotlinx.coroutines.CoroutineDispatcher = Dispatchers.Unconfined) =
        PendingEvidenceCenter(
            store = PendingEvidenceStore(root, Dispatchers.Unconfined),
            backend = server.backend,
            appScope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined),
            io = io,
            scheduler = scheduler,
        )

    private suspend fun take(vararg tags: Int, key: PendingEvidenceKey = testKey): List<PendingEvidenceInput> {
        val inputs = tags.map { PendingEvidenceInput(UUID.randomUUID(), testSource(it)) }
        PendingEvidenceStore(root, Dispatchers.Unconfined).add(inputs, key, "Kitchen", PendingEvidenceDraft(title = "Counter"))
        return inputs
    }

    @Test
    fun anOfflineSaveIsScheduledAndFinishesWhenTheNetworkReturns() = runTest {
        val server = FakeServer().apply { offline = true }
        val inputs = take(1, 2)
        val result = center(server).send(testKey)
        assertTrue(result.failure is PendingEvidenceSyncResult.Failure.Unreachable)
        assertEquals(listOf(user), scheduler.scheduled)

        // WorkManager runs the job while still offline (its constraint can be met by a captive network): retry.
        assertEquals(2, center(server).sendAwaiting(user).remaining)

        server.offline = false
        val report = center(server).sendAwaiting(user)
        assertEquals(0, report.remaining)
        assertEquals(2, report.confirmed)
        assertEquals(inputs.map { it.id }.toSet(), server.rows.keys)
        assertEquals(1, server.entryCreates)
        assertNull(PendingEvidenceStore(root, Dispatchers.Unconfined).manifest(testKey))
    }

    @Test
    fun photosOnlyTakenAreLeftForTheRenter() = runTest {
        val server = FakeServer()
        take(1, 2)
        val report = center(server).sendAwaiting(user)
        assertEquals(0, report.attemptedRooms)
        assertTrue(server.rows.isEmpty())
        assertEquals(2, PendingEvidenceStore(root, Dispatchers.Unconfined).manifest(testKey)!!.items.size)
        // Sign-in reconcile doesn't schedule them either.
        center(server).reconcileAll(user)
        assertTrue(scheduler.scheduled.isEmpty())
    }

    @Test
    fun aKillMidUploadIsFinishedInTheBackgroundExactlyOnce() = runTest {
        val probe = FakeServer()
        take(1, 2, 3)
        center(probe).send(testKey)
        val steps = probe.ticks

        for (killAt in 1..steps) {
            root.deleteRecursively()
            val server = FakeServer().apply { killAtTick = killAt }
            val inputs = take(1, 2, 3)
            try {
                center(server).send(testKey)
            } catch (_: Killed) {
                // The process died mid-save; WorkManager starts the job in a new process.
            }
            server.killAtTick = -1
            var passes = 0
            while (center(server).sendAwaiting(user).remaining > 0) {
                assertTrue("kill at $killAt: still pending", ++passes <= 3)
            }
            center(server).reconcileAll(user)
            val shas = inputs.map { it.source.sha256Hex }.sorted()
            val store = PendingEvidenceStore(root, Dispatchers.Unconfined)
            if (store.manifest(testKey)?.items?.isNotEmpty() == true) {
                // Killed before the save was recorded as asked for: those photos wait for the renter, nothing sent twice.
                assertTrue("kill at $killAt: no duplicates", server.rows.values.map { it.sha }.let { it.size == it.toSet().size })
                continue
            }
            assertEquals("kill at $killAt: each photo exactly once", shas, server.rows.values.map { it.sha }.sorted())
            assertEquals("kill at $killAt: one entry", 1, server.entries.size)
            assertTrue("kill at $killAt: no orphans", server.orphanTickets().isEmpty())
        }
    }

    @Test
    fun overlappingPassesAndAScreenRetryNeverDuplicate() = runTest {
        val server = FakeServer().apply { offline = true }
        val inputs = take(1, 2, 3)
        center(server).send(testKey)
        server.offline = false
        val shared = center(server, io = Dispatchers.Default)
        listOf(
            async { shared.sendAwaiting(user) },
            async { shared.sendAwaiting(user) },
            async { shared.send(testKey) },
        ).awaitAll()
        assertEquals(inputs.map { it.id }.toSet(), server.rows.keys)
        assertEquals(1, server.entryCreates)
        assertTrue(server.orphanTickets().isEmpty())
    }

    @Test
    fun photosMovedToANewEntryAreNotSentAutomatically() = runTest {
        val server = FakeServer()
        val entry = UUID.randomUUID()
        val appendKey = testKey.copy(appendTo = entry.toString())
        take(1, key = appendKey)
        // The Add photos target was deleted elsewhere: the send moves the photo to the room's new-entry set.
        val result = center(server).send(appendKey)
        assertEquals(PendingEvidenceSyncResult.Failure.EntryMissing, result.failure)
        val report = center(server).sendAwaiting(user)
        assertEquals(0, report.attemptedRooms)
        assertTrue(server.rows.isEmpty())
    }

    @Test
    fun signOutCancelsTheJob() = runTest {
        val server = FakeServer()
        take(1)
        center(server).clearUser(user)
        assertEquals(listOf(user), scheduler.cancelled)
    }
}
