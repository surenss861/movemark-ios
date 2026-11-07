package com.surensureshkumar.movemark.data.subscription

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

class ReportCreditPolicyTest {
    @Test
    fun oneFreeReportThenOnlyWhatTheServerHolds() {
        assertEquals(1, ReportCreditPolicy.remainingMoveInExports(freeUsed = 0, serverBalance = null))
        assertEquals(0, ReportCreditPolicy.remainingMoveInExports(freeUsed = 1, serverBalance = null))
        assertEquals(0, ReportCreditPolicy.remainingMoveInExports(freeUsed = 1, serverBalance = 0))
        assertEquals(2, ReportCreditPolicy.remainingMoveInExports(freeUsed = 1, serverBalance = 2))
        assertEquals(0, ReportCreditPolicy.remainingMoveInExports(freeUsed = 1, serverBalance = -3))
    }

    /** The 10-minute window changes the words on screen and nothing else: it never makes a report available. */
    @Test
    fun theSyncWindowNeverGrantsOrInventsACredit() {
        for (free in 0..2) for (balance in listOf<Int?>(null, 0, 1, 3)) {
            val outside = ReportCreditPolicy.moveInGate(free, balance, syncing = false)
            val inside = ReportCreditPolicy.moveInGate(free, balance, syncing = true)
            // Allowed is identical with or without the window.
            assertEquals("free=$free balance=$balance", outside == MoveInGate.Allowed, inside == MoveInGate.Allowed)
            // The only difference: an empty balance reads "still syncing" instead of opening the paywall.
            if (outside == MoveInGate.Paywall) assertEquals(MoveInGate.StillSyncing, inside)
        }
        assertEquals(MoveInGate.StillSyncing, ReportCreditPolicy.moveInGate(freeUsed = 1, serverBalance = 0, syncing = true))
        assertEquals(MoveInGate.Paywall, ReportCreditPolicy.moveInGate(freeUsed = 1, serverBalance = 0, syncing = false))
        // Unknown balance: the server decides; nothing is assumed either way.
        assertEquals(MoveInGate.Allowed, ReportCreditPolicy.moveInGate(freeUsed = 1, serverBalance = null, syncing = false))
    }

    @Test
    fun syncWindowAndUsableCredit() {
        assertFalse(ReportCreditPolicy.isPurchaseLikelySyncing(null, 1_000))
        assertTrue(ReportCreditPolicy.isPurchaseLikelySyncing(0, ReportCreditPolicy.PURCHASE_SYNC_WINDOW_MS - 1))
        assertFalse(ReportCreditPolicy.isPurchaseLikelySyncing(0, ReportCreditPolicy.PURCHASE_SYNC_WINDOW_MS))
        assertFalse("a clock behind the purchase isn't syncing", ReportCreditPolicy.isPurchaseLikelySyncing(1_000, 0))
        assertTrue(ReportCreditPolicy.hasUsablePackCredit(1))
        assertFalse(ReportCreditPolicy.hasUsablePackCredit(0))
        assertFalse("unknown is not 'restored'", ReportCreditPolicy.hasUsablePackCredit(null))
    }

    @Test
    fun onlyTheExactReportPackIdMatches() {
        assertEquals("report_pack", ReportCreditPolicy.REPORT_PACK_PRODUCT_ID)
        assertTrue(ReportCreditPolicy.isReportPackProduct("report_pack"))
        assertTrue(ReportCreditPolicy.isReportPackProduct(" Report_Pack "))
        assertFalse(ReportCreditPolicy.isReportPackProduct("movemark_report_pack"))
        assertFalse(ReportCreditPolicy.isReportPackProduct("test_report_pack"))
        assertFalse(ReportCreditPolicy.isReportPackProduct("report_pack_2"))
        assertFalse(ReportCreditPolicy.isReportPackProduct("movemark_pro_monthly"))
    }
}

class ReportCreditsManagerTest {
    @get:Rule val tmp = TemporaryFolder()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var server: MockWebServer
    private lateinit var manager: ReportCreditsManager
    private val user = UUID.randomUUID()

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val transport = AuthenticatedTransport(FakeTokens(), OkHttpClient(), AuthenticatedTransport.AuthOrigins("data.invalid", server.hostName))
        val store = ReportCreditsStore(PreferenceDataStoreFactory.create(scope = scope) { File(tmp.root, "c.preferences_pb") })
        manager = ReportCreditsManager(store, ExportApiClient(server.url("/"), transport))
    }

    @After
    fun tearDown() {
        server.shutdown()
        scope.cancel()
    }

    @Test
    fun aPurchaseAddsNothingLocallyTheServerBalanceIsTheOnlySource() = runTest {
        var now = 1_000_000L
        manager.clock = { now }
        assertEquals(MoveInGate.Allowed, manager.moveInGate(user, hasPro = false))
        manager.recordMoveInExport(user)
        server.enqueue(MockResponse().setBody("""{"balance":0}"""))
        manager.refresh(user)
        assertEquals(MoveInGate.Paywall, manager.moveInGate(user, hasPro = false))
        assertEquals("Pro is unlimited", MoveInGate.Allowed, manager.moveInGate(user, hasPro = true))

        // Bought a pack; the webhook hasn't landed (server still says 0). Copy changes, availability doesn't.
        server.enqueue(MockResponse().setBody("""{"balance":0}"""))
        manager.purchaseCompleted(user)
        assertEquals("/api/account/report-credits", server.takeRequest().path)
        assertTrue(manager.isPurchaseLikelySyncing)
        assertEquals(MoveInGate.StillSyncing, manager.moveInGate(user, hasPro = false))
        assertFalse(manager.hasUsablePackCredit(user))

        // The webhook granted one credit server-side: now, and only now, a report is available.
        server.enqueue(MockResponse().setBody("""{"balance":1}"""))
        assertEquals(1, manager.refresh(user))
        assertEquals(MoveInGate.Allowed, manager.moveInGate(user, hasPro = false))

        // Ten minutes on with the balance spent: back to the paywall, never a local credit.
        now += ReportCreditPolicy.PURCHASE_SYNC_WINDOW_MS
        server.enqueue(MockResponse().setBody("""{"balance":0}"""))
        manager.refresh(user)
        assertEquals(MoveInGate.Paywall, manager.moveInGate(user, hasPro = false))
    }

    @Test
    fun signOutForgetsTheServerBalanceAndFailuresKeepTheLastOne() = runTest {
        server.enqueue(MockResponse().setBody("""{"balance":2}"""))
        assertEquals(2, manager.refresh(user))
        server.enqueue(MockResponse().setResponseCode(500))
        assertNull(manager.refresh(user))
        assertEquals(2, manager.balance.value)
        assertTrue(manager.hasUsablePackCredit(user))
        assertNull(manager.refresh(null))
        assertNull(manager.balance.value)
        assertFalse(manager.hasUsablePackCredit(user))
        assertEquals(MoveInGate.Paywall, manager.moveInGate(null, hasPro = false))
    }
}
