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
    fun oneFreeReportThenOnePerPack() {
        assertEquals(1, ReportCreditPolicy.remainingMoveInExports(freeUsed = 0, localPackCredits = 0, serverBalance = null, syncing = false))
        assertEquals(0, ReportCreditPolicy.remainingMoveInExports(1, 0, null, false))
        assertEquals(1, ReportCreditPolicy.remainingMoveInExports(1, 1, null, false))
        assertEquals(0, ReportCreditPolicy.remainingMoveInExports(2, 1, null, false))
    }

    @Test
    fun theServerBalanceWinsUnlessAPurchaseIsSyncing() {
        // Local thinks a pack is unspent, the server says it was used (another device).
        assertEquals(0, ReportCreditPolicy.remainingMoveInExports(1, 1, serverBalance = 0, syncing = false))
        // Server has a pack this device never saw.
        assertEquals(2, ReportCreditPolicy.remainingMoveInExports(0, 0, serverBalance = 1, syncing = false))
        // Just bought: the webhook may lag, so the local credit counts.
        assertEquals(1, ReportCreditPolicy.remainingMoveInExports(1, 1, serverBalance = 0, syncing = true))
    }

    @Test
    fun syncWindowAndUsableCredit() {
        assertFalse(ReportCreditPolicy.isPurchaseLikelySyncing(null, 1_000))
        assertTrue(ReportCreditPolicy.isPurchaseLikelySyncing(0, ReportCreditPolicy.PURCHASE_SYNC_WINDOW_MS - 1))
        assertFalse(ReportCreditPolicy.isPurchaseLikelySyncing(0, ReportCreditPolicy.PURCHASE_SYNC_WINDOW_MS))
        assertTrue(ReportCreditPolicy.hasUsablePackCredit(freeUsed = 1, localPackCredits = 1, serverBalance = null))
        assertFalse("already spent", ReportCreditPolicy.hasUsablePackCredit(2, 1, null))
        assertFalse(ReportCreditPolicy.hasUsablePackCredit(0, 5, serverBalance = 0))
    }

    @Test
    fun reportPackProductIds() {
        assertTrue(ReportCreditPolicy.isReportPackProduct("report_pack"))
        assertTrue(ReportCreditPolicy.isReportPackProduct("movemark_report_pack"))
        assertTrue(ReportCreditPolicy.isReportPackProduct("MoveMark_Report_Pack_2026"))
        assertFalse(ReportCreditPolicy.isReportPackProduct("movemark_pro_monthly"))
        assertFalse(ReportCreditPolicy.isReportPackProduct("movemark_pro_yearly:annual"))
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
    fun freeReportIsSpentThenAPackBuysOneMore() = runTest {
        var now = 1_000_000L
        manager.clock = { now }
        assertTrue(manager.canExportMoveIn(user, hasPro = false))
        manager.recordMoveInExport(user)
        assertFalse(manager.canExportMoveIn(user, hasPro = false))
        assertTrue("Pro is unlimited", manager.canExportMoveIn(user, hasPro = true))

        // Bought a pack; the server hasn't heard yet (balance 0) but the sync window keeps it usable.
        server.enqueue(MockResponse().setBody("""{"balance":0}"""))
        manager.purchaseCompleted(user, reportPackPurchases = 1)
        assertEquals("/api/account/report-credits", server.takeRequest().path)
        assertTrue(manager.isPurchaseLikelySyncing)
        assertTrue(manager.canExportMoveIn(user, hasPro = false))

        // Ten minutes later the server is the truth.
        now += ReportCreditPolicy.PURCHASE_SYNC_WINDOW_MS
        assertFalse(manager.canExportMoveIn(user, hasPro = false))
        server.enqueue(MockResponse().setBody("""{"balance":1}"""))
        assertEquals(1, manager.refresh(user))
        assertTrue(manager.canExportMoveIn(user, hasPro = false))
    }

    @Test
    fun signOutForgetsTheServerBalanceAndFailuresKeepTheLastOne() = runTest {
        server.enqueue(MockResponse().setBody("""{"balance":2}"""))
        assertEquals(2, manager.refresh(user))
        server.enqueue(MockResponse().setResponseCode(500))
        assertNull(manager.refresh(user))
        assertEquals(2, manager.balance.value)
        assertNull(manager.refresh(null))
        assertNull(manager.balance.value)
        assertFalse(manager.canExportMoveIn(null, hasPro = false))
    }
}
