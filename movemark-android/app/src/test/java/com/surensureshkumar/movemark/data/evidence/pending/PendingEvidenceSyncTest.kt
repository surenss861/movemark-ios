package com.surensureshkumar.movemark.data.evidence.pending

import com.surensureshkumar.movemark.data.backend.AbandonResult
import com.surensureshkumar.movemark.data.backend.MoveMarkUpload
import com.surensureshkumar.movemark.data.evidence.EvidenceSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.util.UUID

/** Thrown by the fake to stop a sync dead, the way a process kill would (not an Exception: nothing catches it). */
private class Killed : Error("process killed")

/**
 * The server, modelled: entries by id, `evidence_files` rows by id, upload tickets with their state. Every
 * backend step is a numbered "tick"; [killAtTick] stops the run there.
 */
private class FakeServer {
    enum class TicketState { Issued, Finalized, Abandoned }

    data class Row(val entryId: UUID, val ticketId: String, val sha: String)

    val entries = mutableMapOf<UUID, String>()
    var entryCreates = 0
    val rows = mutableMapOf<UUID, Row>()
    val tickets = mutableMapOf<String, TicketState>()
    private val ticketSha = mutableMapOf<String, String>()
    var ticks = 0
    var killAtTick = -1
    var offline = false
    var failInsertsAfterCommit = 0
    var abandonUnreachable = 0
    var ensureEntryFails = false

    private fun tick() {
        ticks++
        if (ticks == killAtTick) throw Killed()
    }

    private fun network() {
        if (offline) throw IOException("offline")
    }

    val backend = object : PendingEvidenceBackend {
        override suspend fun ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft): Boolean {
            tick(); network()
            if (ensureEntryFails) throw IOException("data api down")
            if (id !in entries) {
                entries[id] = title
                entryCreates++
            }
            tick()
            return false
        }

        override suspend fun entryPhotoIds(entryId: UUID): Set<UUID>? {
            tick(); network()
            if (entryId !in entries) return null
            return rows.filterValues { it.entryId == entryId }.keys
        }

        override suspend fun deleteEntry(id: UUID) {
            tick(); network()
            rows.entries.removeIf { it.value.entryId == id }
            entries.remove(id)
        }

        override suspend fun upload(source: EvidenceSource, key: PendingEvidenceKey, onTicket: suspend (MoveMarkUpload) -> Unit): MoveMarkUpload {
            tick(); network()
            val id = "t${tickets.size + 1}"
            tickets[id] = TicketState.Issued
            ticketSha[id] = source.sha256Hex
            val upload = MoveMarkUpload(id, "inspection-media", "$id.jpg", "$id-thumb.jpg", "$id-src.jpg", source.capturedAt)
            onTicket(upload)
            tick()
            tickets[id] = TicketState.Finalized
            tick()
            return upload
        }

        override suspend fun insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload) {
            tick(); network()
            if (rowId in rows) throw IOException("duplicate key value violates unique constraint")
            require(entryId in entries) { "foreign key" }
            rows[rowId] = Row(entryId, upload.ticketId, ticketSha.getValue(upload.ticketId))
            tick()
            if (failInsertsAfterCommit > 0) {
                failInsertsAfterCommit--
                throw IOException("response lost")
            }
        }

        override suspend fun abandon(upload: MoveMarkUpload): AbandonResult {
            tick()
            if (offline || abandonUnreachable > 0) {
                if (abandonUnreachable > 0) abandonUnreachable--
                return AbandonResult.Failed
            }
            if (rows.values.any { it.ticketId == upload.ticketId }) return AbandonResult.Kept
            tickets[upload.ticketId] = TicketState.Abandoned
            return AbandonResult.Deleted
        }
    }

    /** Uploaded objects no row references and nobody released: orphans. */
    fun orphanTickets(): Set<String> =
        tickets.filter { (id, state) -> state != TicketState.Abandoned && rows.values.none { it.ticketId == id } }.keys
}

class PendingEvidenceSyncTest {
    @get:Rule val tmp = TemporaryFolder()

    private val root get() = File(tmp.root, "pending")

    /** A fresh store per call: every run behaves like a new process over the same files. */
    private fun store() = PendingEvidenceStore(root, Dispatchers.Unconfined)

    private suspend fun admit(vararg tags: Int, key: PendingEvidenceKey = testKey): List<PendingEvidenceInput> {
        val inputs = tags.map { PendingEvidenceInput(UUID.randomUUID(), testSource(it)) }
        store().add(inputs, key, "Kitchen", PendingEvidenceDraft(title = "Counter"))
        return inputs
    }

    @Test
    fun savesEveryPhotoOnceUnderItsClientIdsAndLeavesNothingBehind() = runTest {
        val server = FakeServer()
        val inputs = admit(1, 2, 3)
        val result = PendingEvidenceSync(store(), server.backend).sync(testKey)

        assertTrue(result.isComplete)
        assertEquals(3, result.saved.size)
        assertEquals(3, result.savedTotal)
        assertEquals(inputs.map { it.id }.toSet(), server.rows.keys)
        assertEquals(1, server.entryCreates)
        assertEquals(setOf(result.entryId), server.entries.keys)
        assertTrue(server.orphanTickets().isEmpty())
        assertNull(store().manifest(testKey))
    }

    @Test
    fun offlineKeepsEveryPhotoOnThePhoneAndSendsNothing() = runTest {
        val server = FakeServer().apply { offline = true }
        admit(1, 2)
        val result = PendingEvidenceSync(store(), server.backend).sync(testKey)

        assertTrue(result.failure is PendingEvidenceSyncResult.Failure.Unreachable)
        assertEquals(2, result.pending.size)
        assertTrue(result.nothingLinked)
        assertTrue(server.rows.isEmpty())
        assertEquals(2, store().manifest(testKey)!!.items.size)

        server.offline = false
        val retry = PendingEvidenceSync(store(), server.backend).sync(testKey)
        assertTrue(retry.isComplete)
        assertEquals(2, server.rows.size)
        assertEquals(1, server.entryCreates)
    }

    @Test
    fun anInsertThatCommittedBehindALostResponseIsNotDuplicated() = runTest {
        val server = FakeServer().apply { failInsertsAfterCommit = 1 }
        admit(1, 2)
        val result = PendingEvidenceSync(store(), server.backend).sync(testKey)

        assertTrue(result.isComplete)
        assertEquals(2, server.rows.size)
        assertEquals(1, result.insertFailures)
        assertTrue(server.orphanTickets().isEmpty())
    }

    @Test
    fun anUnknownUploadIsSettledBeforeThePhotoIsSentAgain() = runTest {
        val server = FakeServer().apply {
            failInsertsAfterCommit = 1
            abandonUnreachable = 1
        }
        admit(1)
        val first = PendingEvidenceSync(store(), server.backend).sync(testKey)
        assertEquals(1, first.pending.size)
        assertTrue(first.pending.single().item.unresolved != null)
        assertTrue(!first.nothingLinked)

        val second = PendingEvidenceSync(store(), server.backend).sync(testKey)
        assertTrue(second.isComplete)
        assertEquals(1, server.rows.size)
        assertEquals("never uploaded twice", 1, server.tickets.size)
    }

    @Test
    fun whenTheEntryCannotBeCreatedNothingIsUploaded() = runTest {
        val server = FakeServer().apply { ensureEntryFails = true }
        admit(1, 2)
        val result = PendingEvidenceSync(store(), server.backend).sync(testKey)
        assertTrue(result.failure is PendingEvidenceSyncResult.Failure.Unreachable)
        assertTrue(server.tickets.isEmpty())
        assertEquals(2, store().manifest(testKey)!!.items.size)
    }

    @Test
    fun reconcileRemovesAnEntryLeftEmptyByAKill() = runTest {
        val server = FakeServer()
        admit(1)
        val s = store()
        // A save chose and created the entry, then the renter discarded the photos before any landed.
        val entryId = UUID.fromString(s.beginEntry(testKey) { UUID.randomUUID().toString() })
        server.backend.ensureEntry(entryId, testKey, "Counter", PendingEvidenceDraft())
        s.clearRoom(testKey)
        assertTrue(store().manifest(testKey)!!.needsServerCleanup)

        PendingEvidenceSync(store(), server.backend).reconcile(testKey)
        assertTrue(server.entries.isEmpty())
        assertNull(store().manifest(testKey))
    }

    @Test
    fun addPhotosToADeletedEntryMovesThemToTheNewEntry() = runTest {
        val server = FakeServer()
        val appendKey = testKey.copy(appendTo = UUID.randomUUID().toString())
        admit(5, key = appendKey)
        val result = PendingEvidenceSync(store(), server.backend).sync(appendKey)
        assertEquals(PendingEvidenceSyncResult.Failure.EntryMissing, result.failure)
        assertNull(store().manifest(appendKey))
        assertEquals(1, store().manifest(testKey)!!.items.size)
        assertTrue(server.tickets.isEmpty())
    }

    @Test
    fun addPhotosAppendsToTheExistingEntry() = runTest {
        val server = FakeServer()
        val entryId = UUID.randomUUID()
        server.backend.ensureEntry(entryId, testKey, "Old", PendingEvidenceDraft())
        val appendKey = testKey.copy(appendTo = entryId.toString())
        admit(5, 6, key = appendKey)
        val result = PendingEvidenceSync(store(), server.backend).sync(appendKey)
        assertTrue(result.isComplete)
        assertEquals(1, server.entryCreates)
        assertTrue(server.rows.values.all { it.entryId == entryId })
        assertEquals(2, server.rows.size)
    }

    /**
     * The evidence-integrity property: kill the app at every single backend step of a three-photo save, relaunch
     * and retry until done. Every time: each photo saved exactly once, one entry, no orphaned upload, nothing
     * left on the phone.
     */
    @Test
    fun aKillAtAnyStepLosesNothingAndDuplicatesNothing() = runTest {
        // Count the steps of an uninterrupted run.
        val probe = FakeServer()
        admit(1, 2, 3)
        PendingEvidenceSync(store(), probe.backend).sync(testKey)
        val steps = probe.ticks
        assertTrue(steps > 10)

        for (killAt in 1..steps) {
            root.deleteRecursively()
            val server = FakeServer().apply { killAtTick = killAt }
            val inputs = admit(1, 2, 3)
            try {
                PendingEvidenceSync(store(), server.backend).sync(testKey)
            } catch (_: Killed) {
                // The process died here. Whatever made it to disk is all the next launch has.
            }
            server.killAtTick = -1
            // Next launch: reconcile, then the renter taps Save until it completes.
            PendingEvidenceSync(store(), server.backend).reconcile(testKey)
            var attempts = 0
            while (store().manifest(testKey)?.items?.isNotEmpty() == true) {
                if (++attempts > 3) fail("kill at step $killAt: still pending after retries")
                PendingEvidenceSync(store(), server.backend).sync(testKey)
            }
            PendingEvidenceSync(store(), server.backend).reconcile(testKey)

            val shas = inputs.map { it.source.sha256Hex }.sorted()
            assertEquals("kill at $killAt: each photo exactly once", shas, server.rows.values.map { it.sha }.sorted())
            assertEquals("kill at $killAt: row ids are the client ids", inputs.map { it.id }.toSet(), server.rows.keys)
            assertEquals("kill at $killAt: one entry", 1, server.entries.size)
            assertTrue("kill at $killAt: rows on that entry", server.rows.values.all { it.entryId in server.entries })
            assertEquals("kill at $killAt: no orphaned uploads", emptySet<String>(), server.orphanTickets())
            assertNull("kill at $killAt: phone is clear", store().manifest(testKey))
        }
    }
}
